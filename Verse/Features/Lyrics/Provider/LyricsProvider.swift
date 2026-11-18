import Foundation

enum LyricsSource: String, Sendable, Equatable {
    case embedded, file, lrclib
}

enum LyricsResult: Sendable, Equatable {
    case found(Lyrics, LyricsSource)
    case instrumental
    case notFound
}

struct LyricsRequest: Sendable, Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var embedded: String? = nil
    var sidecarURL: URL? = nil
}

/// Finds lyrics for a song: embedded tags, then an imported `.lrc` file, then LRCLIB.
/// Synced lyrics win over plain ones from an earlier source.
struct LyricsProvider: Sendable {
    var lrclib: LRCLIBClient
    var cache: LyricsCache
    /// How long "LRCLIB had nothing" is remembered.
    var negativeCacheLifetime: TimeInterval = 3 * 24 * 3600
    var now: @Sendable () -> Date = { .now }

    static func live() -> LyricsProvider {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return LyricsProvider(
            lrclib: LRCLIBClient(http: URLSessionHTTPClient(), userAgent: "Verse/\(version)"),
            cache: .shared
        )
    }

    @concurrent
    func lyrics(for request: LyricsRequest, useLRCLIB: Bool) async -> LyricsResult {
        var plainFallback: (Lyrics, LyricsSource)?

        let localSources: [(String?, LyricsSource)] = [
            (request.embedded, .embedded),
            (request.sidecarURL.flatMap(Self.readText), .file),
        ]
        for (text, source) in localSources {
            guard let text else { continue }
            let parsed = LyricsParser.parse(text)
            guard !parsed.isEmpty else { continue }
            if parsed.timing != .none { return .found(parsed, source) }
            if plainFallback == nil { plainFallback = (parsed, source) }
        }

        if useLRCLIB, let remote = await remoteLyrics(for: request) {
            if let synced = remote.synced.map(LyricsParser.parse), !synced.isEmpty, synced.timing != .none {
                return .found(synced, .lrclib)
            }
            if plainFallback == nil {
                if remote.instrumental { return .instrumental }
                if let plain = remote.plain.map(LyricsParser.parse), !plain.isEmpty {
                    plainFallback = (plain, .lrclib)
                }
            }
        }

        return plainFallback.map { .found($0.0, $0.1) } ?? .notFound
    }

    private func remoteLyrics(for request: LyricsRequest) async -> CachedLyrics? {
        let key = LyricsCache.key(title: request.title, artist: request.artist, album: request.album, duration: request.duration)
        if let cached = cache.load(key: key),
           cached.hasLyrics || now().timeIntervalSince(cached.fetchedAt) < negativeCacheLifetime {
            return cached
        }
        do {
            let record = try await lrclib.bestMatch(
                title: request.title, artist: request.artist, album: request.album, duration: request.duration
            )
            let result = CachedLyrics(
                synced: record?.syncedLyrics,
                plain: record?.plainLyrics,
                instrumental: record?.instrumental ?? false,
                fetchedAt: now()
            )
            cache.save(result, key: key)
            return result
        } catch {
            // Offline or server trouble: don't cache, try again next time.
            return nil
        }
    }

    private static func readText(_ url: URL) -> String? {
        if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        return try? String(contentsOf: url, encoding: .isoLatin1)
    }
}
