import Foundation
import SwiftData

enum LibrarySchema {
    static var models: [any PersistentModel.Type] {
        [Song.self, Album.self, Artist.self, Playlist.self, PlaylistEntry.self, PlayHistory.self]
    }
}

/// Normalised keys so "Café" and "cafe " end up in the same album or artist.
enum LibraryKey {
    static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func artist(_ name: String) -> String {
        normalized(name)
    }

    static func album(title: String, artist: String) -> String {
        normalized(artist) + "\u{1F}" + normalized(title)
    }
}
