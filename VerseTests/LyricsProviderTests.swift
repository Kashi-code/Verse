import Foundation
import Testing
@testable import Verse

struct LyricsProviderTests {
    let cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "VerseLyrics-\(UUID().uuidString)", directoryHint: .isDirectory)

    private func provider(_ http: FakeHTTPClient, now: Date = .now) -> LyricsProvider {
        LyricsProvider(
            lrclib: LRCLIBClient(http: http, userAgent: "Verse/test"),
            cache: LyricsCache(directory: cacheDirectory),
            now: { now }
        )
    }

    private func request(embedded: String? = nil, sidecar: URL? = nil) -> LyricsRequest {
        LyricsRequest(title: "Test Song", artist: "Test Artist", album: "Test Album", duration: 233, embedded: embedded, sidecarURL: sidecar)
    }

    private let lrclibFound = FakeHTTPClient { _ in (200, sampleRecordJSON) }

    @Test func embeddedSyncedLyricsWinWithoutNetwork() async {
        let result = await provider(lrclibFound).lyrics(for: request(embedded: "[00:01.00]Embedded"), useLRCLIB: true)
        guard case .found(let lyrics, let source) = result else {
            Issue.record("Expected lyrics, got \(result)")
            return
        }
        #expect(source == .embedded)
        #expect(lyrics.lines.first?.text == "Embedded")
        #expect(lrclibFound.requestCount == 0)
    }

    @Test func sidecarFileIsRead() async throws {
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let file = cacheDirectory.appending(path: "song.lrc")
        try "[00:02.00]From file".write(to: file, atomically: true, encoding: .utf8)

        let http = FakeHTTPClient { _ in (404, "") }
        let result = await provider(http).lyrics(for: request(embedded: "Plain embedded", sidecar: file), useLRCLIB: false)
        guard case .found(let lyrics, let source) = result else {
            Issue.record("Expected lyrics, got \(result)")
            return
        }
        #expect(source == .file)
        #expect(lyrics.timing == .line)
    }

    @Test func plainEmbeddedLyricsAreUpgradedFromLRCLIB() async {
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let result = await provider(lrclibFound).lyrics(for: request(embedded: "Just text"), useLRCLIB: true)
        guard case .found(let lyrics, let source) = result else {
            Issue.record("Expected lyrics, got \(result)")
            return
        }
        #expect(source == .lrclib)
        #expect(lyrics.timing == .line)
    }

    @Test func withLRCLIBOffPlainLyricsAreUsed() async {
        let result = await provider(lrclibFound).lyrics(for: request(embedded: "Just text"), useLRCLIB: false)
        guard case .found(let lyrics, let source) = result else {
            Issue.record("Expected lyrics, got \(result)")
            return
        }
        #expect(source == .embedded)
        #expect(lyrics.timing == .none)
        #expect(lrclibFound.requestCount == 0)
    }

    @Test func resultsAreCachedOnDisk() async {
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let provider = provider(lrclibFound)
        _ = await provider.lyrics(for: request(), useLRCLIB: true)
        let afterFirst = lrclibFound.requestCount
        let second = await provider.lyrics(for: request(), useLRCLIB: true)
        #expect(lrclibFound.requestCount == afterFirst)
        if case .found(_, let source) = second {
            #expect(source == .lrclib)
        } else {
            Issue.record("Expected cached lyrics, got \(second)")
        }
    }

    @Test func notFoundIsRememberedForAWhile() async {
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let http = FakeHTTPClient { _ in (404, "") }
        let start = Date(timeIntervalSince1970: 1_000_000)

        #expect(await provider(http, now: start).lyrics(for: request(), useLRCLIB: true) == .notFound)
        let afterFirst = http.requestCount
        #expect(await provider(http, now: start.addingTimeInterval(3600)).lyrics(for: request(), useLRCLIB: true) == .notFound)
        #expect(http.requestCount == afterFirst)

        // After the negative-cache lifetime it asks again.
        _ = await provider(http, now: start.addingTimeInterval(4 * 24 * 3600)).lyrics(for: request(), useLRCLIB: true)
        #expect(http.requestCount > afterFirst)
    }

    @Test func networkErrorsAreNotCached() async {
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let failing = FakeHTTPClient { _ in (503, "") }
        #expect(await provider(failing).lyrics(for: request(), useLRCLIB: true) == .notFound)
        let result = await provider(lrclibFound).lyrics(for: request(), useLRCLIB: true)
        if case .found = result {} else { Issue.record("Expected lyrics after recovery, got \(result)") }
    }

    @Test func instrumentalTracks() async {
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let http = FakeHTTPClient { _ in (200, #"{"id": 9, "duration": 233, "instrumental": true}"#) }
        #expect(await provider(http).lyrics(for: request(), useLRCLIB: true) == .instrumental)
    }

    @Test func cacheKeyIgnoresCaseAndAccents() {
        #expect(LyricsCache.key(title: "Café", artist: "Zoë", album: "X", duration: 200.4)
                == LyricsCache.key(title: "cafe", artist: "zoe ", album: "x", duration: 199.6))
    }
}
