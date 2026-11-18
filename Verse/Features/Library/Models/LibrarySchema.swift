import Foundation
import SwiftData

/// The user's own data. Catalog content is never stored here, only enough of it (a JSON snapshot)
/// to show a liked or played song offline.
enum LibrarySchema {
    static var models: [any PersistentModel.Type] {
        [LikedTrack.self, Playlist.self, PlaylistEntry.self, SavedCollection.self, FollowedArtist.self,
         PlayHistory.self, TrackSettings.self]
    }
}

@Model
final class LikedTrack {
    /// `CatalogID.key`, e.g. `audius:Ma0blKV`.
    @Attribute(.unique) var key: String
    var title: String
    var artist: String
    var trackData: Data
    var likedAt: Date

    init(track: TrackInfo, likedAt: Date = .now) {
        key = track.id.key
        title = track.title
        artist = track.artist
        trackData = TrackSnapshot.encode(track)
        self.likedAt = likedAt
    }

    var track: TrackInfo? { TrackSnapshot.decode(trackData) }
}

@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateCreated: Date
    var dateModified: Date

    @Relationship(deleteRule: .cascade, inverse: \PlaylistEntry.playlist)
    var entries: [PlaylistEntry] = []

    init(id: UUID = UUID(), name: String, dateCreated: Date = .now) {
        self.id = id
        self.name = name
        self.dateCreated = dateCreated
        self.dateModified = dateCreated
    }
}

/// One song in a playlist. Songs from different catalogs can be mixed.
@Model
final class PlaylistEntry {
    var position: Int
    var trackKey: String
    var trackData: Data
    var dateAdded: Date
    var playlist: Playlist?

    init(track: TrackInfo, position: Int, dateAdded: Date = .now) {
        self.position = position
        trackKey = track.id.key
        trackData = TrackSnapshot.encode(track)
        self.dateAdded = dateAdded
    }

    var track: TrackInfo? { TrackSnapshot.decode(trackData) }
}

/// An album or playlist from a catalog that the user saved.
@Model
final class SavedCollection {
    @Attribute(.unique) var key: String
    var title: String
    var collectionData: Data
    var savedAt: Date

    init(collection: CatalogCollection, savedAt: Date = .now) {
        key = collection.id.key
        title = collection.title
        collectionData = (try? JSONEncoder().encode(collection)) ?? Data()
        self.savedAt = savedAt
    }

    var collection: CatalogCollection? { try? JSONDecoder().decode(CatalogCollection.self, from: collectionData) }
}

@Model
final class FollowedArtist {
    @Attribute(.unique) var key: String
    var name: String
    var artistData: Data
    var followedAt: Date

    init(artist: CatalogArtist, followedAt: Date = .now) {
        key = artist.id.key
        name = artist.name
        artistData = (try? JSONEncoder().encode(artist)) ?? Data()
        self.followedAt = followedAt
    }

    var artist: CatalogArtist? { try? JSONDecoder().decode(CatalogArtist.self, from: artistData) }
}

@Model
final class PlayHistory {
    var trackKey: String
    var trackData: Data
    var genre: String?
    var artistKey: String?
    var playedAt: Date

    init(track: TrackInfo, playedAt: Date = .now) {
        trackKey = track.id.key
        trackData = TrackSnapshot.encode(track)
        genre = track.genre
        artistKey = track.artistID?.key
        self.playedAt = playedAt
    }

    var track: TrackInfo? { TrackSnapshot.decode(trackData) }
}

/// Per-song preferences, such as the lyrics timing offset.
@Model
final class TrackSettings {
    @Attribute(.unique) var key: String
    var lyricsOffset: Double

    init(key: String, lyricsOffset: Double = 0) {
        self.key = key
        self.lyricsOffset = lyricsOffset
    }
}

enum TrackSnapshot {
    static func encode(_ track: TrackInfo) -> Data {
        (try? JSONEncoder().encode(track)) ?? Data()
    }

    static func decode(_ data: Data) -> TrackInfo? {
        try? JSONDecoder().decode(TrackInfo.self, from: data)
    }
}

/// Normalised keys so "Café" and "cafe " compare equal.
enum LibraryKey {
    static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
