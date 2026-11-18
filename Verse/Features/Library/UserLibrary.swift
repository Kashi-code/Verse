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

    // MARK: Your playlists

    func playlists() -> [Playlist] {
        let descriptor = FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\.dateModified, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func createPlaylist(named name: String, with tracks: [TrackInfo] = []) -> Playlist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let playlist = Playlist(name: trimmed.isEmpty ? String(localized: "New Playlist") : trimmed)
        context.insert(playlist)
        add(tracks, to: playlist)
        try? context.save()
        return playlist
    }

    func rename(_ playlist: Playlist, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        playlist.name = trimmed
        playlist.dateModified = .now
        try? context.save()
    }

    func delete(_ playlist: Playlist) {
        context.delete(playlist)
        try? context.save()
    }

    /// Adds songs to the end, skipping ones already in the playlist. Returns how many were added.
    @discardableResult
    func add(_ tracks: [TrackInfo], to playlist: Playlist) -> Int {
        var keys = Set(playlist.entries.map(\.trackKey))
        var position = (playlist.entries.map(\.position).max() ?? -1) + 1
        var added = 0
        for track in tracks where keys.insert(track.id.key).inserted {
            let entry = PlaylistEntry(track: track, position: position)
            context.insert(entry)
            playlist.entries.append(entry)
            position += 1
            added += 1
        }
        if added > 0 {
            playlist.dateModified = .now
            try? context.save()
        }
        return added
    }

    /// `offsets` index into `playlist.orderedEntries`.
    func removeEntries(at offsets: IndexSet, from playlist: Playlist) {
        let ordered = playlist.orderedEntries
        let removed = offsets.filter { ordered.indices.contains($0) }.map { ordered[$0] }
        let removedIDs = Set(removed.map(\.persistentModelID))
        playlist.entries.removeAll { removedIDs.contains($0.persistentModelID) }
        removed.forEach { context.delete($0) }
        renumber(ordered.filter { !removedIDs.contains($0.persistentModelID) }, in: playlist)
    }

    /// Same meaning as `List.onMove`, on `playlist.orderedEntries`.
    func moveEntries(fromOffsets source: IndexSet, toOffset destination: Int, in playlist: Playlist) {
        renumber(Self.moved(playlist.orderedEntries, fromOffsets: source, toOffset: destination), in: playlist)
    }

    private func renumber(_ entries: [PlaylistEntry], in playlist: Playlist) {
        for (index, entry) in entries.enumerated() {
            entry.position = index
        }
        playlist.dateModified = .now
        try? context.save()
    }

    nonisolated static func moved<Element>(_ items: [Element], fromOffsets source: IndexSet, toOffset destination: Int) -> [Element] {
        let moving = source.filter { items.indices.contains($0) }.map { items[$0] }
        var remaining = items.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = destination - source.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: min(max(insertAt, 0), remaining.count))
        return remaining
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
