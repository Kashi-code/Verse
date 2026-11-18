import Foundation
import Observation

/// Loads lyrics for the playing song and holds its timing offset. Results are kept for the session.
@MainActor
@Observable
final class LyricsController {
    enum State: Equatable {
        case idle
        case loading
        case loaded(Lyrics, LyricsSource)
        case instrumental
        case notFound
    }

    static let offsetStep = 0.1
    static let offsetRange: ClosedRange<Double> = -10...10

    private(set) var state: State = .idle
    /// Seconds added to playback time before matching lyrics: positive shows lyrics earlier.
    private(set) var offset: Double = 0

    @ObservationIgnored var library: PlaybackLibraryBridge?
    @ObservationIgnored private let provider: LyricsProvider
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let importedLyrics: ManagedFileStore
    @ObservationIgnored private var currentSource: TrackSource?
    @ObservationIgnored private var results: [TrackSource: State] = [:]

    init(provider: LyricsProvider, settings: AppSettings, importedLyrics: ManagedFileStore = .importedLyrics) {
        self.provider = provider
        self.settings = settings
        self.importedLyrics = importedLyrics
    }

    func load(for track: TrackInfo?) async {
        guard let track else {
            currentSource = nil
            state = .idle
            return
        }
        if track.source == currentSource, state != .idle, state != .loading { return }
        currentSource = track.source

        let song = track.source.localSongID.flatMap { library?.song(id: $0) }
        offset = song?.lyricsOffset ?? 0

        if let known = results[track.source] {
            state = known
            return
        }
        state = .loading

        let request = LyricsRequest(
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration,
            embedded: song?.embeddedLyrics,
            sidecarURL: song?.lyricsFileName.map(importedLyrics.url(for:))
        )
        let result = await provider.lyrics(for: request, useLRCLIB: settings.lrclibEnabled)
        let newState: State = switch result {
        case .found(let lyrics, let source): .loaded(lyrics, source)
        case .instrumental: .instrumental
        case .notFound: .notFound
        }
        results[track.source] = newState
        // The song may have changed while we were loading.
        if currentSource == track.source {
            state = newState
        }
    }

    func adjustOffset(by delta: Double) {
        setOffset(offset + delta)
    }

    func resetOffset() {
        setOffset(0)
    }

    /// Forgets loaded lyrics, e.g. after clearing the cache or changing the LRCLIB setting.
    func forgetLoadedLyrics() {
        results.removeAll()
        if currentSource != nil { state = .idle }
        currentSource = nil
    }

    private func setOffset(_ value: Double) {
        let stepped = (value / Self.offsetStep).rounded() * Self.offsetStep
        offset = min(max(stepped, Self.offsetRange.lowerBound), Self.offsetRange.upperBound)
        if let songID = currentSource?.localSongID {
            library?.setLyricsOffset(offset, for: songID)
        }
    }
}
