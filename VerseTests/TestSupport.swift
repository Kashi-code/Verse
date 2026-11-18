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
            source: .local(songID: UUID(), fileName: "track\(index).mp3"),
            title: "Track \(index)",
            artist: "Artist",
            album: "Album",
            duration: 180,
            artworkKey: nil
        )
    }
}

@MainActor
final class FakeAudioBackend: AudioBackend {
    var currentTime: TimeInterval = 0
    var isPlaying = false
    var onFinished: (@MainActor () -> Void)?
    private(set) var loadedURLs: [URL] = []
    var failingFileNames: Set<String> = []
    private var loadedURL: URL?

    var hasLoadedItem: Bool { loadedURL != nil }

    func load(_ url: URL) throws -> TimeInterval {
        if failingFileNames.contains(url.lastPathComponent) {
            loadedURL = nil
            throw CocoaError(.fileNoSuchFile)
        }
        loadedURL = url
        loadedURLs.append(url)
        currentTime = 0
        isPlaying = false
        return 180
    }

    func play() throws { isPlaying = true }
    func pause() { isPlaying = false }
    func stop() {
        isPlaying = false
        loadedURL = nil
    }
    func seek(to time: TimeInterval) { currentTime = time }

    /// Simulates the current file playing to its end.
    func finish() {
        isPlaying = false
        onFinished?()
    }
}
