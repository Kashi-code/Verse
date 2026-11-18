import Foundation

/// Plays one stream at a time and can prepare the next one so it starts without a gap.
/// `PlayerController` drives it; tests use a fake.
@MainActor
protocol AudioBackend: AnyObject {
    var currentTime: TimeInterval { get }
    /// Known once the stream has loaded (e.g. ~30 s for a preview).
    var itemDuration: TimeInterval? { get }
    var isPlaying: Bool { get }
    var isBuffering: Bool { get }
    var hasLoadedItem: Bool { get }

    /// The current stream ended and nothing was prepared.
    var onFinished: (@MainActor () -> Void)? { get set }
    /// The current stream ended and the prepared one took over.
    var onAdvancedToNext: (@MainActor () -> Void)? { get set }
    var onFailed: (@MainActor () -> Void)? { get set }
    /// Buffering, duration or play state changed.
    var onStatusChange: (@MainActor () -> Void)? { get set }

    /// Starts loading a stream, paused at 0.
    func load(_ url: URL)
    /// Queues the stream to play after the current one (nil clears it).
    func prepareNext(_ url: URL?)
    func play()
    func pause()
    func stop()
    func seek(to time: TimeInterval)
}
