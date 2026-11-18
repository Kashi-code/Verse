import CryptoKit
import Foundation

/// What LRCLIB returned for a song, including "nothing", so we don't ask again right away.
struct CachedLyrics: Codable, Sendable, Equatable {
    var synced: String?
    var plain: String?
    var instrumental: Bool
    var fetchedAt: Date

    var hasLyrics: Bool { synced?.isEmpty == false || plain?.isEmpty == false || instrumental }
}

/// Downloaded lyrics on disk in Caches (they can always be fetched again).
struct LyricsCache: Sendable {
    let directory: URL

    static let shared = LyricsCache(
        directory: .cachesDirectory.appending(path: "Lyrics", directoryHint: .isDirectory)
    )

    static func key(title: String, artist: String, album: String, duration: TimeInterval) -> String {
        let identity = [title, artist, album].map(LibraryKey.normalized).joined(separator: "|") + "|\(Int(duration.rounded()))"
        return SHA256.hash(data: Data(identity.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    func load(key: String) -> CachedLyrics? {
        guard let data = try? Data(contentsOf: url(for: key)) else { return nil }
        return try? JSONDecoder().decode(CachedLyrics.self, from: data)
    }

    func save(_ lyrics: CachedLyrics, key: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(lyrics).write(to: url(for: key), options: .atomic)
        } catch {
            // A failed cache write only means we fetch again next time.
        }
    }

    func removeAll() throws {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    func totalSize() -> Int64 {
        ManagedFileStore(directory: directory).totalSize()
    }

    private func url(for key: String) -> URL {
        directory.appending(path: "\(key).json", directoryHint: .notDirectory)
    }
}
