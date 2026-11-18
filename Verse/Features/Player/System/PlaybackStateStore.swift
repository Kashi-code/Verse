import Foundation

/// Saves the queue and position so the app can resume where it left off.
struct PlaybackStateStore: Sendable {
    struct Saved: Codable, Sendable, Equatable {
        var queue: PlaybackQueue
        var position: TimeInterval
    }

    let fileURL: URL

    static let shared = PlaybackStateStore(
        fileURL: .applicationSupportDirectory.appending(path: "playback-state.json", directoryHint: .notDirectory)
    )

    func load() -> Saved? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Saved.self, from: data)
    }

    func save(_ saved: Saved) {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(saved).write(to: fileURL, options: .atomic)
        } catch {
            // Not being able to resume is not worth interrupting the user for.
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

extension PlayerController {
    var savedState: PlaybackStateStore.Saved? {
        guard queue.current != nil else { return nil }
        return PlaybackStateStore.Saved(queue: queue, position: currentTime)
    }
}
