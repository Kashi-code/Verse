import Foundation
import SwiftData

@Model
final class Album {
    /// Normalised "album artist + title", see `LibraryKey`.
    @Attribute(.unique) var key: String
    var title: String
    var artistName: String
    var year: Int?
    var artworkKey: String?
    var dateAdded: Date

    var artist: Artist?

    @Relationship(deleteRule: .nullify, inverse: \Song.album)
    var songs: [Song] = []

    init(title: String, artistName: String, year: Int? = nil, artworkKey: String? = nil, dateAdded: Date = .now) {
        self.key = LibraryKey.album(title: title, artist: artistName)
        self.title = title
        self.artistName = artistName
        self.year = year
        self.artworkKey = artworkKey
        self.dateAdded = dateAdded
    }
}

extension Album {
    var orderedSongs: [Song] { songs.sorted(by: Song.albumOrder) }

    var totalDuration: TimeInterval { songs.reduce(0) { $0 + $1.duration } }

    static func matching(_ text: String) -> Predicate<Album>? {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        return #Predicate<Album> { album in
            album.title.localizedStandardContains(query) || album.artistName.localizedStandardContains(query)
        }
    }
}
