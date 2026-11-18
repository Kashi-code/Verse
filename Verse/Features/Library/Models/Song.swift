import Foundation
import SwiftData

/// An imported local audio file.
@Model
final class Song {
    @Attribute(.unique) var id: UUID
    var title: String
    var artistName: String
    var albumTitle: String
    var trackNumber: Int?
    var discNumber: Int?
    var year: Int?
    var duration: TimeInterval
    /// File name inside `ManagedFileStore.music`.
    var fileName: String
    var fileSize: Int64
    /// Key into `ArtworkStore`.
    var artworkKey: String?
    var embeddedLyrics: String?
    /// File name inside `ManagedFileStore.importedLyrics` of an imported `.lrc` sidecar.
    var lyricsFileName: String?
    /// Per-song lyrics timing offset in seconds.
    var lyricsOffset: Double = 0
    var isLiked: Bool = false
    var dateAdded: Date
    var lastPlayedAt: Date?
    var playCount: Int = 0

    var album: Album?
    var artist: Artist?

    @Relationship(deleteRule: .cascade, inverse: \PlaylistEntry.song)
    var playlistEntries: [PlaylistEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \PlayHistory.song)
    var history: [PlayHistory] = []

    init(
        id: UUID = UUID(),
        title: String,
        artistName: String,
        albumTitle: String,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        year: Int? = nil,
        duration: TimeInterval,
        fileName: String,
        fileSize: Int64,
        artworkKey: String? = nil,
        embeddedLyrics: String? = nil,
        lyricsFileName: String? = nil,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.year = year
        self.duration = duration
        self.fileName = fileName
        self.fileSize = fileSize
        self.artworkKey = artworkKey
        self.embeddedLyrics = embeddedLyrics
        self.lyricsFileName = lyricsFileName
        self.dateAdded = dateAdded
    }
}

extension Song {
    var subtitle: String { "\(artistName) · \(albumTitle)" }

    var displayArtworkKey: String? { artworkKey ?? album?.artworkKey }

    /// Disc, then track number, then title.
    static func albumOrder(_ a: Song, _ b: Song) -> Bool {
        let lhs = (a.discNumber ?? 1, a.trackNumber ?? Int.max)
        let rhs = (b.discNumber ?? 1, b.trackNumber ?? Int.max)
        if lhs != rhs { return lhs < rhs }
        return a.title.localizedStandardCompare(b.title) == .orderedAscending
    }

    static func matching(_ text: String) -> Predicate<Song>? {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        return #Predicate<Song> { song in
            song.title.localizedStandardContains(query)
                || song.artistName.localizedStandardContains(query)
                || song.albumTitle.localizedStandardContains(query)
        }
    }
}
