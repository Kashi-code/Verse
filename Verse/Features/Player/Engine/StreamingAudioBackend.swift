import AVFoundation

/// Streams with `AVQueuePlayer`: playback starts while buffering, and the next song is queued
/// behind the current one so AVFoundation fetches its first seconds ahead of time.
@MainActor
final class StreamingAudioBackend: AudioBackend {
    private let player = AVQueuePlayer()
    private var currentItem: AVPlayerItem?
    private var nextItem: AVPlayerItem?
    private var wantsToPlay = false
    private var pendingSeek: TimeInterval?

    private var statusObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var notificationTokens: [any NSObjectProtocol] = []

    var onFinished: (@MainActor () -> Void)?
    var onAdvancedToNext: (@MainActor () -> Void)?
    var onFailed: (@MainActor () -> Void)?
    var onStatusChange: (@MainActor () -> Void)?

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
        player.actionAtItemEnd = .advance
        statusObservation = Self.observeTimeControl(of: player, notify: self)

        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let item = notification.object as? AVPlayerItem
            MainActor.assumeIsolated { self?.itemDidEnd(item) }
        })
        notificationTokens.append(center.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let item = notification.object as? AVPlayerItem
            MainActor.assumeIsolated { self?.itemDidFail(item) }
        })
    }

    // MARK: State

    var currentTime: TimeInterval {
        if let pendingSeek { return pendingSeek }
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? max(seconds, 0) : 0
    }

    var itemDuration: TimeInterval? {
        guard let seconds = currentItem?.duration.seconds, seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }

    var isPlaying: Bool { wantsToPlay && currentItem != nil }
    var isBuffering: Bool { wantsToPlay && player.timeControlStatus == .waitingToPlayAtSpecifiedRate }
    var hasLoadedItem: Bool { currentItem != nil }

    // MARK: Control

    func load(_ url: URL) {
        player.removeAllItems()
        let item = AVPlayerItem(url: url)
        player.insert(item, after: nil)
        setCurrent(item)
        nextItem = nil
        pendingSeek = nil
        wantsToPlay = false
        player.pause()
    }

    func prepareNext(_ url: URL?) {
        if let nextItem {
            player.remove(nextItem)
            self.nextItem = nil
        }
        guard let url, let currentItem else { return }
        let item = AVPlayerItem(url: url)
        if player.canInsert(item, after: currentItem) {
            player.insert(item, after: currentItem)
            nextItem = item
        }
    }

    func play() {
        guard currentItem != nil else { return }
        wantsToPlay = true
        player.play()
        onStatusChange?()
    }

    func pause() {
        wantsToPlay = false
        player.pause()
        onStatusChange?()
    }

    func stop() {
        wantsToPlay = false
        player.pause()
        player.removeAllItems()
        currentItem = nil
        nextItem = nil
        itemObservation = nil
        onStatusChange?()
    }

    func seek(to time: TimeInterval) {
        guard let currentItem else { return }
        let target = max(time, 0)
        if currentItem.status == .readyToPlay {
            pendingSeek = nil
            player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            // Applied once the stream is ready (e.g. when restoring the last position).
            pendingSeek = target
        }
    }

    // MARK: Events

    private func setCurrent(_ item: AVPlayerItem) {
        currentItem = item
        itemObservation = Self.observeStatus(of: item, notify: self)
    }

    private func itemDidEnd(_ item: AVPlayerItem?) {
        guard let item, item === currentItem else { return }
        if let next = nextItem {
            // AVQueuePlayer has already moved on to the prepared item.
            nextItem = nil
            setCurrent(next)
            pendingSeek = nil
            onAdvancedToNext?()
        } else {
            // The queue player drops finished items, so forget it; playing again reloads it.
            wantsToPlay = false
            currentItem = nil
            itemObservation = nil
            onFinished?()
        }
    }

    private func itemDidFail(_ item: AVPlayerItem?) {
        guard let item, item === currentItem else { return }
        wantsToPlay = false
        onFailed?()
    }

    fileprivate func itemStatusChanged() {
        guard let currentItem else { return }
        switch currentItem.status {
        case .readyToPlay:
            if let pendingSeek {
                self.pendingSeek = nil
                player.seek(to: CMTime(seconds: pendingSeek, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
            }
        case .failed:
            wantsToPlay = false
            onFailed?()
        default:
            break
        }
        onStatusChange?()
    }

    fileprivate func timeControlChanged() {
        onStatusChange?()
    }

    // KVO handlers run on arbitrary threads, so they are built outside the main actor and hop back.

    nonisolated private static func observeTimeControl(of player: AVQueuePlayer, notify backend: StreamingAudioBackend) -> NSKeyValueObservation {
        player.observe(\.timeControlStatus) { [weak backend] _, _ in
            guard let backend else { return }
            Task { @MainActor in backend.timeControlChanged() }
        }
    }

    nonisolated private static func observeStatus(of item: AVPlayerItem, notify backend: StreamingAudioBackend) -> NSKeyValueObservation {
        item.observe(\.status) { [weak backend] _, _ in
            guard let backend else { return }
            Task { @MainActor in backend.itemStatusChanged() }
        }
    }
}
