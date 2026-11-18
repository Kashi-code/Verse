import Foundation
import SwiftData

/// Reads and writes the user's own data: likes, history and per-song settings.
@MainActor
struct UserLibrary {
    let context: ModelContext

    // MARK: Likes

    func isLiked(_ id: CatalogID) -> Bool {
        likedTrack(id) != nil
    }

    /// Returns the new liked state.
    @discardableResult
    func toggleLike(_ track: TrackInfo) -> Bool {
        if let existing = likedTrack(track.id) {
            context.delete(existing)
            try? context.save()
            return false
        }
        context.insert(LikedTrack(track: track))
        try? context.save()
        return true
    }

    private func likedTrack(_ id: CatalogID) -> LikedTrack? {
        let key = id.key
        var descriptor = FetchDescriptor<LikedTrack>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: Saved albums and playlists

    func isSaved(_ id: CatalogID) -> Bool {
        savedCollection(id) != nil
    }

    @discardableResult
    func toggleSaved(_ collection: CatalogCollection) -> Bool {
        if let existing = savedCollection(collection.id) {
            context.delete(existing)
            try? context.save()
            return false
        }
        context.insert(SavedCollection(collection: collection))
        try? context.save()
        return true
    }

    private func savedCollection(_ id: CatalogID) -> SavedCollection? {
        let key = id.key
        var descriptor = FetchDescriptor<SavedCollection>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: Followed artists

    func isFollowing(_ id: CatalogID) -> Bool {
        followedArtist(id) != nil
    }

    @discardableResult
    func toggleFollow(_ artist: CatalogArtist) -> Bool {
        if let existing = followedArtist(artist.id) {
            context.delete(existing)
            try? context.save()
            return false
        }
        context.insert(FollowedArtist(artist: artist))
        try? context.save()
        return true
    }

    private func followedArtist(_ id: CatalogID) -> FollowedArtist? {
        let key = id.key
        var descriptor = FetchDescriptor<FollowedArtist>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: History

    func recordPlay(of track: TrackInfo, at date: Date = .now) {
        context.insert(PlayHistory(track: track, playedAt: date))
        try? context.save()
    }

    /// Most recent first, one entry per song.
    func recentlyPlayed(limit: Int = 20) -> [TrackInfo] {
        var descriptor = FetchDescriptor<PlayHistory>(sortBy: [SortDescriptor(\.playedAt, order: .reverse)])
        descriptor.fetchLimit = limit * 4
        let history = (try? context.fetch(descriptor)) ?? []
        var seen = Set<String>()
        return history
            .filter { seen.insert($0.trackKey).inserted }
            .compactMap(\.track)
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Per-song settings

    func lyricsOffset(for id: CatalogID) -> Double {
        settings(for: id)?.lyricsOffset ?? 0
    }

    func setLyricsOffset(_ offset: Double, for id: CatalogID) {
        if let existing = settings(for: id) {
            existing.lyricsOffset = offset
        } else {
            context.insert(TrackSettings(key: id.key, lyricsOffset: offset))
        }
        try? context.save()
    }

    private func settings(for id: CatalogID) -> TrackSettings? {
        let key = id.key
        var descriptor = FetchDescriptor<TrackSettings>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
