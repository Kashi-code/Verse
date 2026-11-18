import Foundation

/// Plays one file at a time. `PlayerController` drives it; tests use a fake.
@MainActor
protocol AudioBackend: AnyObject {
    var currentTime: TimeInterval { get }
    var isPlaying: Bool { get }
    var hasLoadedItem: Bool { get }
    /// Called when the loaded file has played to the end.
    var onFinished: (@MainActor () -> Void)? { get set }

    /// Loads a file, paused at 0. Returns its duration.
    func load(_ url: URL) throws -> TimeInterval
    func play() throws
    func pause()
    func stop()
    func seek(to time: TimeInterval)
}
