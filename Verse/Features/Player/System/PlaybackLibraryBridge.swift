import Foundation
import SwiftData

/// Lets the player update the library: play counts, history and likes.
@MainActor
struct PlaybackLibraryBridge {
    let context: ModelContext

    func song(id: UUID) -> Song? {
        var descriptor = FetchDescriptor<Song>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func recordPlay(of id: UUID, at date: Date = .now) {
        guard let song = song(id: id) else { return }
        song.playCount += 1
        song.lastPlayedAt = date
        let entry = PlayHistory(playedAt: date)
        context.insert(entry)
        entry.song = song
        try? context.save()
    }

    func isLiked(_ id: UUID) -> Bool {
        song(id: id)?.isLiked ?? false
    }

    func setLyricsOffset(_ offset: Double, for id: UUID) {
        guard let song = song(id: id) else { return }
        song.lyricsOffset = offset
        try? context.save()
    }

    /// Returns the new liked state, or nil if the song no longer exists.
    func toggleLike(_ id: UUID) -> Bool? {
        guard let song = song(id: id) else { return nil }
        song.isLiked.toggle()
        try? context.save()
        return song.isLiked
    }
}
