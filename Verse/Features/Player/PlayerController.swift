import Foundation
import Observation

/// The app's single player: owns the queue, drives the audio backend and keeps the
/// lock screen and library in sync. Views read it from the environment.
@MainActor
@Observable
final class PlayerController {
    private(set) var queue = PlaybackQueue()
    private(set) var isPlaying = false
    private(set) var duration: TimeInterval = 0
    private(set) var isCurrentLiked = false
    private(set) var errorMessage: String?

    /// Set by the app once the library is available.
    @ObservationIgnored var library: PlaybackLibraryBridge?

    @ObservationIgnored private let backend: any AudioBackend
    @ObservationIgnored private let music: ManagedFileStore
    @ObservationIgnored private let nowPlaying: NowPlayingCenter?
    @ObservationIgnored private let session: AudioSessionController?
    @ObservationIgnored private var resumeAfterInterruption = false

    init(
        backend: any AudioBackend,
        music: ManagedFileStore = .music,
        nowPlaying: NowPlayingCenter? = nil,
        session: AudioSessionController? = nil
    ) {
        self.backend = backend
        self.music = music
        self.nowPlaying = nowPlaying
        self.session = session

        backend.onFinished = { [weak self] in self?.trackDidFinish() }
        nowPlaying?.handler = { [weak self] action in self?.handle(action) }
        session?.onInterruptionBegan = { [weak self] in self?.interruptionBegan() }
        session?.onInterruptionEnded = { [weak self] shouldResume in self?.interruptionEnded(shouldResume: shouldResume) }
        session?.onOutputLost = { [weak self] in self?.pause() }
    }

    static func live() -> PlayerController {
        PlayerController(backend: LocalAudioEngine(), nowPlaying: NowPlayingCenter(), session: AudioSessionController())
    }

    // MARK: State

    var currentTrack: TrackInfo? { queue.current?.track }
    /// Not observed: read it inside a `TimelineView` for smooth updates.
    var currentTime: TimeInterval { backend.currentTime }
    var repeatMode: RepeatMode { queue.repeatMode }
    var isShuffled: Bool { queue.isShuffled }
    var upNext: [QueueItem] { queue.upNext }

    // MARK: Starting playback

    /// Replaces the queue and starts playing. With `shuffled` and no index, a random song plays first.
    func play(_ tracks: [TrackInfo], startingAt index: Int? = nil, from source: QueueSource? = nil, shuffled: Bool = false) {
        guard !tracks.isEmpty else { return }
        queue.replace(with: tracks, startAt: index, source: source, shuffled: shuffled)
        loadCurrent(autoplay: true)
    }

    func playNext(_ tracks: [TrackInfo]) {
        guard currentTrack != nil else {
            play(tracks)
            return
        }
        queue.insertNext(tracks)
    }

    func addToQueue(_ tracks: [TrackInfo]) {
        guard currentTrack != nil else {
            play(tracks)
            return
        }
        queue.append(tracks)
    }

    // MARK: Transport

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func resume() {
        guard currentTrack != nil else { return }
        guard backend.hasLoadedItem else {
            loadCurrent(autoplay: true)
            return
        }
        session?.activate()
        do {
            try backend.play()
            isPlaying = true
        } catch {
            isPlaying = false
            errorMessage = String(localized: "Playback couldn't start.")
        }
        updateNowPlaying()
    }

    func pause() {
        backend.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func skipToNext() {
        guard queue.advance(userInitiated: true) != nil else {
            reachedEndOfQueue()
            return
        }
        loadCurrent(autoplay: isPlaying)
    }

    /// Restarts the song if more than 3 seconds have played, otherwise goes to the previous song.
    func skipToPrevious() {
        if currentTime > 3 || !queue.goBack() {
            seek(to: 0)
        } else {
            loadCurrent(autoplay: isPlaying)
        }
    }

    func seek(to time: TimeInterval) {
        backend.seek(to: time)
        updateNowPlaying()
    }

    func jump(to item: QueueItem) {
        guard queue.jump(to: item.id) != nil else { return }
        loadCurrent(autoplay: true)
    }

    // MARK: Modes and queue editing

    func cycleRepeatMode() {
        queue.repeatMode = queue.repeatMode.next
    }

    func toggleShuffle() {
        queue.setShuffled(!queue.isShuffled)
    }

    func removeFromUpNext(_ item: QueueItem) {
        queue.removeFromUpNext(item.id)
    }

    func moveUpNext(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        queue.moveUpNext(fromOffsets: offsets, toOffset: destination)
    }

    func clearUpNext() {
        queue.clearUpNext()
    }

    func toggleLike() {
        guard let songID = currentTrack?.source.localSongID,
              let liked = library?.toggleLike(songID) else { return }
        isCurrentLiked = liked
        updateNowPlaying()
    }

    // MARK: Internals

    private func loadCurrent(autoplay: Bool) {
        guard let track = currentTrack else { return }
        errorMessage = nil

        switch track.source {
        case .local(let songID, let fileName):
            do {
                duration = try backend.load(music.url(for: fileName))
                if autoplay {
                    session?.activate()
                    try backend.play()
                    library?.recordPlay(of: songID)
                }
                isPlaying = autoplay
            } catch {
                isPlaying = false
                duration = track.duration
                errorMessage = String(localized: "Couldn't play “\(track.title)”.")
            }
            isCurrentLiked = library?.isLiked(songID) ?? false
        case .appleMusic:
            backend.stop()
            isPlaying = false
            duration = track.duration
            isCurrentLiked = false
            errorMessage = String(localized: "Apple Music playback isn't available yet.")
        }
        updateNowPlaying()
    }

    private func trackDidFinish() {
        guard queue.advance(userInitiated: false) != nil else {
            reachedEndOfQueue()
            return
        }
        loadCurrent(autoplay: true)
    }

    /// At the end with repeat off: stay on the last song, paused at the start.
    private func reachedEndOfQueue() {
        backend.pause()
        backend.seek(to: 0)
        isPlaying = false
        updateNowPlaying()
    }

    private func handle(_ action: RemoteAction) {
        switch action {
        case .play: resume()
        case .pause: pause()
        case .togglePlayPause: togglePlayPause()
        case .next: skipToNext()
        case .previous: skipToPrevious()
        case .toggleLike: toggleLike()
        case .seek(let time): seek(to: time)
        }
    }

    private func interruptionBegan() {
        guard isPlaying else { return }
        resumeAfterInterruption = true
        pause()
    }

    private func interruptionEnded(shouldResume: Bool) {
        if shouldResume && resumeAfterInterruption {
            resume()
        }
        resumeAfterInterruption = false
    }

    private func updateNowPlaying() {
        nowPlaying?.update(
            track: currentTrack,
            isPlaying: isPlaying,
            elapsed: backend.currentTime,
            duration: duration,
            isLiked: isCurrentLiked
        )
    }
}
