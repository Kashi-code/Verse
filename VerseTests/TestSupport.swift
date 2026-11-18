import Foundation
@testable import Verse

/// Deterministic generator (SplitMix64) so shuffle tests are repeatable.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

func makeTracks(_ count: Int) -> [TrackInfo] {
    (0..<count).map { index in
        TrackInfo(
            id: CatalogID(.audius, "track\(index)"),
            title: "Track \(index)",
            artist: "Artist",
            artistID: CatalogID(.audius, "artist"),
            album: "Album",
            albumID: nil,
            duration: 180,
            artworkURL: nil,
            thumbnailURL: nil,
            genre: "Electronic",
            streamURL: URL(string: "https://example.com/track\(index).mp3")
        )
    }
}

@MainActor
final class FakeAudioBackend: AudioBackend {
    var currentTime: TimeInterval = 0
    var itemDuration: TimeInterval?
    var isPlaying = false
    var isBuffering = false
    var onFinished: (@MainActor () -> Void)?
    var onAdvancedToNext: (@MainActor () -> Void)?
    var onFailed: (@MainActor () -> Void)?
    var onStatusChange: (@MainActor () -> Void)?

    private(set) var loadedURLs: [URL] = []
    private(set) var preparedURL: URL?
    var failingFileNames: Set<String> = []
    private var loadedURL: URL?

    var hasLoadedItem: Bool { loadedURL != nil }

    func load(_ url: URL) {
        loadedURLs.append(url)
        currentTime = 0
        isPlaying = false
        if failingFileNames.contains(url.lastPathComponent) {
            loadedURL = nil
            onFailed?()
        } else {
            loadedURL = url
        }
    }

    func prepareNext(_ url: URL?) { preparedURL = url }
    func play() { isPlaying = true }
    func pause() { isPlaying = false }
    func stop() {
        isPlaying = false
        loadedURL = nil
    }
    func seek(to time: TimeInterval) { currentTime = time }

    /// Simulates the current stream ending with nothing prepared.
    func finish() {
        isPlaying = false
        loadedURL = nil
        onFinished?()
    }

    /// Simulates the current stream ending and the prepared one taking over.
    func finishIntoPrepared() {
        guard let preparedURL else { return finish() }
        loadedURL = preparedURL
        self.preparedURL = nil
        currentTime = 0
        onAdvancedToNext?()
    }
}
