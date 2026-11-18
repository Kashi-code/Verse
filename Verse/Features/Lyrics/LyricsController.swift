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
        /// Previews start somewhere in the middle of the song, so lyrics can't be synced.
        case previewOnly
    }

    static let offsetStep = 0.1
    static let offsetRange: ClosedRange<Double> = -10...10

    private(set) var state: State = .idle
    /// Seconds added to playback time before matching lyrics: positive shows lyrics earlier.
    private(set) var offset: Double = 0

    @ObservationIgnored var library: UserLibrary?
    @ObservationIgnored private let provider: LyricsProvider
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var currentID: CatalogID?
    @ObservationIgnored private var results: [CatalogID: State] = [:]

    init(provider: LyricsProvider, settings: AppSettings) {
        self.provider = provider
        self.settings = settings
    }

    func load(for track: TrackInfo?) async {
        guard let track else {
            currentID = nil
            state = .idle
            return
        }
        if track.id == currentID, state != .idle, state != .loading { return }
        currentID = track.id
        offset = library?.lyricsOffset(for: track.id) ?? 0

        if track.isPreview {
            state = .previewOnly
            return
        }
        if let known = results[track.id] {
            state = known
            return
        }
        state = .loading

        let request = LyricsRequest(
            title: track.title,
            artist: track.artist,
            album: track.album ?? "",
            duration: track.duration
        )
        let result = await provider.lyrics(for: request, useLRCLIB: settings.lrclibEnabled)
        let newState: State = switch result {
        case .found(let lyrics, let source): .loaded(lyrics, source)
        case .instrumental: .instrumental
        case .notFound: .notFound
        }
        results[track.id] = newState
        // The song may have changed while we were loading.
        if currentID == track.id {
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
        if currentID != nil { state = .idle }
        currentID = nil
    }

    private func setOffset(_ value: Double) {
        let stepped = (value / Self.offsetStep).rounded() * Self.offsetStep
        offset = min(max(stepped, Self.offsetRange.lowerBound), Self.offsetRange.upperBound)
        if let currentID {
            library?.setLyricsOffset(offset, for: currentID)
        }
    }
}
