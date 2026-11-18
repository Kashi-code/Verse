import Foundation

/// Everything the catalog needs to create a `Song`, after the files have been copied in.
struct ImportedTrack: Sendable, Equatable {
    var title: String
    var artistName: String
    var albumTitle: String
    var albumArtistName: String
    var trackNumber: Int?
    var discNumber: Int?
    var year: Int?
    var duration: TimeInterval
    var embeddedLyrics: String?
    var audioFile: StoredFile
    var lyricsFileName: String?
    var artworkKey: String?
}

/// Copies one picked file (and its `.lrc` sidecar) into the app and reads its tags. Runs off the main actor.
struct ImportFileProcessor: Sendable {
    var music: ManagedFileStore = .music
    var lyrics: ManagedFileStore = .importedLyrics
    var artwork: ArtworkStore = .shared

    @concurrent
    func process(_ item: ImportPlanner.Item) async throws -> ImportedTrack {
        let hasAudioAccess = item.audio.startAccessingSecurityScopedResource()
        defer {
            if hasAudioAccess { item.audio.stopAccessingSecurityScopedResource() }
        }

        let metadata = try await MetadataReader.read(from: item.audio)
        let audioFile = try music.copyIn(item.audio)

        var lyricsFileName: String?
        if let lyricsURL = item.lyrics {
            let hasLyricsAccess = lyricsURL.startAccessingSecurityScopedResource()
            defer {
                if hasLyricsAccess { lyricsURL.stopAccessingSecurityScopedResource() }
            }
            lyricsFileName = try? lyrics.copyIn(lyricsURL).name
        }

        let artworkKey = metadata.artworkData.flatMap { try? artwork.store($0) }
        let artistName = metadata.artist ?? String(localized: "Unknown Artist")

        return ImportedTrack(
            title: metadata.title ?? MetadataParsing.fallbackTitle(for: item.audio),
            artistName: artistName,
            albumTitle: metadata.albumTitle ?? String(localized: "Unknown Album"),
            albumArtistName: metadata.albumArtist ?? artistName,
            trackNumber: metadata.trackNumber,
            discNumber: metadata.discNumber,
            year: metadata.year,
            duration: metadata.duration,
            embeddedLyrics: metadata.lyrics,
            audioFile: audioFile,
            lyricsFileName: lyricsFileName,
            artworkKey: artworkKey
        )
    }
}
