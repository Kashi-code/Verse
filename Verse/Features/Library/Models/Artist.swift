import Foundation
import SwiftData

@Model
final class Artist {
    /// Normalised name, see `LibraryKey`.
    @Attribute(.unique) var key: String
    var name: String

    @Relationship(deleteRule: .nullify, inverse: \Song.artist)
    var songs: [Song] = []

    @Relationship(deleteRule: .nullify, inverse: \Album.artist)
    var albums: [Album] = []

    init(name: String) {
        self.key = LibraryKey.artist(name)
        self.name = name
    }
}

extension Artist {
    var artworkKey: String? {
        albums.lazy.compactMap(\.artworkKey).first ?? songs.lazy.compactMap(\.displayArtworkKey).first
    }

    var orderedAlbums: [Album] {
        albums.sorted { ($0.year ?? 0, $0.title) < ($1.year ?? 0, $1.title) }
    }

    var orderedSongs: [Song] {
        songs.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    static func matching(_ text: String) -> Predicate<Artist>? {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        return #Predicate<Artist> { $0.name.localizedStandardContains(query) }
    }
}
