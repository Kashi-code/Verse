import Foundation
import SwiftData

/// Adds and removes songs in SwiftData, keeping albums and artists in sync.
@MainActor
struct LibraryCatalog {
    let context: ModelContext
    var music: ManagedFileStore = .music
    var lyrics: ManagedFileStore = .importedLyrics

    /// Same title, artist and album, and a duration within 1.5 s.
    func isDuplicate(_ track: ImportedTrack) throws -> Bool {
        let title = track.title
        let artist = track.artistName
        let album = track.albumTitle
        let descriptor = FetchDescriptor<Song>(predicate: #Predicate { song in
            song.title == title && song.artistName == artist && song.albumTitle == album
        })
        return try context.fetch(descriptor).contains { abs($0.duration - track.duration) < 1.5 }
    }

    @discardableResult
    func insert(_ track: ImportedTrack, addedAt date: Date = .now) throws -> Song {
        let songArtist = try findOrCreateArtist(named: track.artistName)
        let albumArtist = try findOrCreateArtist(named: track.albumArtistName)
        let album = try findOrCreateAlbum(title: track.albumTitle, artist: albumArtist, addedAt: date)

        let song = Song(
            title: track.title,
            artistName: track.artistName,
            albumTitle: track.albumTitle,
            trackNumber: track.trackNumber,
            discNumber: track.discNumber,
            year: track.year,
            duration: track.duration,
            fileName: track.audioFile.name,
            fileSize: track.audioFile.size,
            artworkKey: track.artworkKey,
            embeddedLyrics: track.embeddedLyrics,
            lyricsFileName: track.lyricsFileName,
            dateAdded: date
        )
        context.insert(song)
        song.artist = songArtist
        song.album = album

        if album.artworkKey == nil { album.artworkKey = track.artworkKey }
        if album.year == nil { album.year = track.year }
        return song
    }

    /// Removes the files a processed track copied in, e.g. when it turned out to be a duplicate.
    func discardFiles(of track: ImportedTrack) {
        music.remove(track.audioFile.name)
        if let lyricsFileName = track.lyricsFileName { lyrics.remove(lyricsFileName) }
    }

    /// Deletes songs and their imported files, then removes albums and artists left without songs.
    func delete(_ songs: [Song]) throws {
        var albums: [Album] = []
        var artists: [Artist] = []
        var filesToRemove: [(ManagedFileStore, String)] = []

        for song in songs {
            if let album = song.album, !albums.contains(album) { albums.append(album) }
            if let artist = song.artist, !artists.contains(artist) { artists.append(artist) }
            filesToRemove.append((music, song.fileName))
            if let lyricsFileName = song.lyricsFileName { filesToRemove.append((lyrics, lyricsFileName)) }
            context.delete(song)
        }
        try context.save()

        for album in albums where album.songs.isEmpty {
            if let artist = album.artist, !artists.contains(artist) { artists.append(artist) }
            context.delete(album)
        }
        try context.save()

        for artist in artists where artist.songs.isEmpty && artist.albums.isEmpty {
            context.delete(artist)
        }
        try context.save()

        for (store, fileName) in filesToRemove {
            store.remove(fileName)
        }
    }

    private func findOrCreateArtist(named name: String) throws -> Artist {
        let key = LibraryKey.artist(name)
        var descriptor = FetchDescriptor<Artist>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }
        let artist = Artist(name: name)
        context.insert(artist)
        return artist
    }

    private func findOrCreateAlbum(title: String, artist: Artist, addedAt date: Date) throws -> Album {
        let key = LibraryKey.album(title: title, artist: artist.name)
        var descriptor = FetchDescriptor<Album>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }
        let album = Album(title: title, artistName: artist.name, dateAdded: date)
        context.insert(album)
        album.artist = artist
        return album
    }
}
