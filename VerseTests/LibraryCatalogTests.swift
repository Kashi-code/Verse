import Foundation
import SwiftData
import Testing
@testable import Verse

@MainActor
struct LibraryCatalogTests {
    let container: ModelContainer
    let catalog: LibraryCatalog
    let root: URL

    init() throws {
        container = try ModelContainer(
            for: Schema(LibrarySchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        root = FileManager.default.temporaryDirectory.appending(path: "VerseTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        catalog = LibraryCatalog(
            context: container.mainContext,
            music: ManagedFileStore(directory: root.appending(path: "Music", directoryHint: .isDirectory)),
            lyrics: ManagedFileStore(directory: root.appending(path: "Lyrics", directoryHint: .isDirectory))
        )
    }

    private func track(
        _ title: String,
        album: String = "Album",
        artist: String = "Artist",
        albumArtist: String? = nil,
        duration: TimeInterval = 200
    ) -> ImportedTrack {
        ImportedTrack(
            title: title,
            artistName: artist,
            albumTitle: album,
            albumArtistName: albumArtist ?? artist,
            trackNumber: nil,
            discNumber: nil,
            year: 2020,
            duration: duration,
            embeddedLyrics: nil,
            audioFile: StoredFile(name: "\(UUID().uuidString).mp3", size: 100),
            lyricsFileName: nil,
            artworkKey: "art-\(album)"
        )
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try catalog.context.fetchCount(FetchDescriptor<T>())
    }

    @Test func groupsSongsIntoAlbumsAndArtists() throws {
        try catalog.insert(track("One"))
        try catalog.insert(track("Two"))
        try catalog.insert(track("Three", album: "B-Sides"))
        try catalog.context.save()

        #expect(try count(Song.self) == 3)
        #expect(try count(Album.self) == 2)
        #expect(try count(Artist.self) == 1)

        let album = try #require(try catalog.context.fetch(FetchDescriptor<Album>(
            predicate: #Predicate { $0.title == "Album" }
        )).first)
        #expect(album.songs.count == 2)
        #expect(album.artworkKey == "art-Album")
        #expect(album.year == 2020)
        #expect(album.artist?.name == "Artist")
    }

    @Test func albumMatchingIgnoresCaseAndAccents() throws {
        try catalog.insert(track("One", album: "Café", artist: "Zoë"))
        try catalog.insert(track("Two", album: "cafe ", artist: "zoe"))
        try catalog.context.save()

        #expect(try count(Album.self) == 1)
        #expect(try count(Artist.self) == 1)
    }

    @Test func compilationSongsShareTheAlbumArtistsAlbum() throws {
        try catalog.insert(track("One", album: "Hits", artist: "A", albumArtist: "Various Artists"))
        try catalog.insert(track("Two", album: "Hits", artist: "B", albumArtist: "Various Artists"))
        try catalog.context.save()

        #expect(try count(Album.self) == 1)
        // A, B and the album artist.
        #expect(try count(Artist.self) == 3)
    }

    @Test func detectsDuplicates() throws {
        try catalog.insert(track("One", duration: 200))
        try catalog.context.save()

        #expect(try catalog.isDuplicate(track("One", duration: 200.8)))
        #expect(try !catalog.isDuplicate(track("One", duration: 230)))
        #expect(try !catalog.isDuplicate(track("One", album: "Live", duration: 200)))
    }

    @Test func deletingLastSongRemovesItsAlbumAndArtist() throws {
        let kept = try catalog.insert(track("Kept", album: "Keep", artist: "Stays"))
        let removed = try catalog.insert(track("Gone", album: "Remove", artist: "Leaves"))
        try catalog.context.save()

        try catalog.delete([removed])

        #expect(try count(Song.self) == 1)
        #expect(try count(Album.self) == 1)
        #expect(try count(Artist.self) == 1)
        #expect(kept.album?.title == "Keep")
    }

    @Test func deletingRemovesImportedFiles() throws {
        let source = root.appending(path: "source.mp3")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: root) }

        var imported = track("File")
        imported.audioFile = try catalog.music.copyIn(source)
        let song = try catalog.insert(imported)
        try catalog.context.save()
        #expect(catalog.music.contains(imported.audioFile.name))

        try catalog.delete([song])
        #expect(!catalog.music.contains(imported.audioFile.name))
    }
}
