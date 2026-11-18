import Foundation
import Observation

/// The app's single player: owns the queue, drives the audio backend and keeps the lock screen
/// and the user's library in sync. Works the same for every catalog. Views read it from the environment.
@MainActor
@Observable
final class PlayerController {
    private(set) var queue = PlaybackQueue()
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var duration: TimeInterval = 0
    private(set) var isCurrentLiked = false
    private(set) var errorMessage: String?
    /// Keep playing similar songs when the queue runs out.
    var autoplayEnabled = true

    /// Set by the app once the user's library is available.
    @ObservationIgnored var library: UserLibrary?
    /// Used for autoplay.
    @ObservationIgnored var catalog: (any CatalogService)?
    /// Called when the queue or position should be saved.
    @ObservationIgnored var onStateChange: (() -> Void)?

    @ObservationIgnored private let backend: any AudioBackend
    @ObservationIgnored private let nowPlaying: NowPlayingCenter?
    @ObservationIgnored private let session: AudioSessionController?
    @ObservationIgnored private var resumeAfterInterruption = false
    @ObservationIgnored private var needsRetry = false
    @ObservationIgnored private var lastKnownTime: TimeInterval = 0

    init(backend: any AudioBackend, nowPlaying: NowPlayingCenter? = nil, session: AudioSessionController? = nil) {
        self.backend = backend
        self.nowPlaying = nowPlaying
        self.session = session

        backend.onFinished = { [weak self] in self?.trackDidFinish() }
        backend.onAdvancedToNext = { [weak self] in self?.advancedToPreparedTrack() }
        backend.onFailed = { [weak self] in self?.playbackFailed() }
        backend.onStatusChange = { [weak self] in self?.backendStatusChanged() }
        nowPlaying?.handler = { [weak self] action in self?.handle(action) }
        session?.onInterruptionBegan = { [weak self] in self?.interruptionBegan() }
        session?.onInterruptionEnded = { [weak self] shouldResume in self?.interruptionEnded(shouldResume: shouldResume) }
        session?.onOutputLost = { [weak self] in self?.pause() }
    }

    static func live() -> PlayerController {
        PlayerController(backend: StreamingAudioBackend(), nowPlaying: NowPlayingCenter(), session: AudioSessionController())
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
        let playable = tracks.filter { $0.streamURL != nil }
        guard !playable.isEmpty else { return }
        let adjustedIndex = index.flatMap { tracks.indices.contains($0) ? playable.firstIndex(of: tracks[$0]) : nil }
        queue.replace(with: playable, startAt: adjustedIndex ?? (shuffled ? nil : 0), source: source, shuffled: shuffled)
        loadCurrent(autoplay: true)
    }

    func playNext(_ tracks: [TrackInfo]) {
        guard currentTrack != nil else {
            play(tracks)
            return
        }
        queue.insertNext(tracks)
        queueDidChange()
    }

    func addToQueue(_ tracks: [TrackInfo]) {
        guard currentTrack != nil else {
            play(tracks)
            return
        }
        queue.append(tracks)
        queueDidChange()
    }

    /// Restores a saved queue, paused at the saved position.
    func restore(_ saved: PlaybackQueue, position: TimeInterval) {
        guard saved.current != nil else { return }
        queue = saved
        loadCurrent(autoplay: false, startAt: position)
    }

    // MARK: Transport

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func resume() {
        guard currentTrack != nil else { return }
        guard backend.hasLoadedItem, !needsRetry else {
            loadCurrent(autoplay: true, startAt: lastKnownTime)
            return
        }
        session?.activate()
        backend.play()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        lastKnownTime = backend.currentTime
        backend.pause()
        isPlaying = false
        updateNowPlaying()
        onStateChange?()
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
        lastKnownTime = time
        updateNowPlaying()
    }

    func jump(to item: QueueItem) {
        guard queue.jump(to: item.id) != nil else { return }
        loadCurrent(autoplay: true)
    }

    /// After the network comes back: reload a stream that failed while offline.
    func retryAfterReconnect() {
        guard needsRetry, currentTrack != nil else { return }
        loadCurrent(autoplay: true, startAt: lastKnownTime)
    }

    // MARK: Modes and queue editing

    func cycleRepeatMode() {
        queue.repeatMode = queue.repeatMode.next
        queueDidChange()
    }

    func toggleShuffle() {
        queue.setShuffled(!queue.isShuffled)
        queueDidChange()
    }

    func removeFromUpNext(_ item: QueueItem) {
        queue.removeFromUpNext(item.id)
        queueDidChange()
    }

    func moveUpNext(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        queue.moveUpNext(fromOffsets: offsets, toOffset: destination)
        queueDidChange()
    }

    func clearUpNext() {
        queue.clearUpNext()
        queueDidChange()
    }

    func toggleLike() {
        guard let track = currentTrack, let library else { return }
        isCurrentLiked = library.toggleLike(track)
        updateNowPlaying()
    }

    /// Re-reads the liked state, e.g. after a like from a context menu.
    func refreshLikedState() {
        guard let track = currentTrack else { return }
        isCurrentLiked = library?.isLiked(track.id) ?? false
    }

    // MARK: Internals

    private func loadCurrent(autoplay: Bool, startAt position: TimeInterval = 0) {
        guard let track = currentTrack else { return }
        errorMessage = nil
        needsRetry = false
        lastKnownTime = position
        duration = track.isPreview ? 30 : track.duration

        guard let url = track.streamURL else {
            isPlaying = false
            errorMessage = String(localized: "“\(track.title)” isn't available to stream.")
            updateNowPlaying()
            return
        }

        backend.load(url)
        if position > 0 { backend.seek(to: position) }
        if backend.hasLoadedItem {
            if autoplay {
                session?.activate()
                backend.play()
                library?.recordPlay(of: track)
            }
            isPlaying = autoplay
        } else {
            isPlaying = false
        }
        isCurrentLiked = library?.isLiked(track.id) ?? false
        backend.prepareNext(queue.peekNext()?.track.streamURL)
        updateNowPlaying()
        onStateChange?()
    }

    private func queueDidChange() {
        if currentTrack != nil {
            backend.prepareNext(queue.peekNext()?.track.streamURL)
        }
        onStateChange?()
    }

    /// The prepared song started on its own; move the queue along without reloading audio.
    private func advancedToPreparedTrack() {
        guard queue.advance(userInitiated: false) != nil, let track = currentTrack else { return }
        duration = backend.itemDuration ?? (track.isPreview ? 30 : track.duration)
        errorMessage = nil
        isPlaying = true
        isCurrentLiked = library?.isLiked(track.id) ?? false
        library?.recordPlay(of: track)
        backend.prepareNext(queue.peekNext()?.track.streamURL)
        updateNowPlaying()
        onStateChange?()
    }

    private func trackDidFinish() {
        if queue.advance(userInitiated: false) != nil {
            loadCurrent(autoplay: true)
        } else if autoplayEnabled, let catalog, let last = currentTrack {
            continueWithSimilarSongs(to: last, catalog: catalog)
        } else {
            reachedEndOfQueue()
        }
    }

    private func continueWithSimilarSongs(to track: TrackInfo, catalog: any CatalogService) {
        isBuffering = true
        Task {
            let known = Set(queue.items.map(\.track.id))
            let similar = ((try? await catalog.similarTracks(to: track)) ?? []).filter { !known.contains($0.id) }
            isBuffering = false
            guard !similar.isEmpty else {
                reachedEndOfQueue()
                return
            }
            queue.append(Array(similar.prefix(20)))
            if queue.advance(userInitiated: true) != nil {
                loadCurrent(autoplay: true)
            }
        }
    }

    /// At the end with repeat and autoplay off: stay on the last song, paused at the start.
    private func reachedEndOfQueue() {
        backend.pause()
        backend.seek(to: 0)
        isPlaying = false
        lastKnownTime = 0
        updateNowPlaying()
        onStateChange?()
    }

    private func playbackFailed() {
        guard let track = currentTrack else { return }
        lastKnownTime = backend.currentTime
        needsRetry = true
        isPlaying = false
        errorMessage = String(localized: "Couldn't play “\(track.title)”.")
        updateNowPlaying()
    }

    private func backendStatusChanged() {
        isBuffering = backend.isBuffering
        if let itemDuration = backend.itemDuration, abs(itemDuration - duration) > 0.5 {
            duration = itemDuration
            updateNowPlaying()
        }
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
