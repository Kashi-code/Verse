import Network
import Observation

/// Tracks whether the device is online, for the offline banner and stream retries.
@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true
    @ObservationIgnored var onReconnect: (() -> Void)?
    @ObservationIgnored private let monitor = NWPathMonitor()

    func start() {
        monitor.pathUpdateHandler = Self.makeHandler(for: self)
        monitor.start(queue: DispatchQueue(label: "Verse.NetworkMonitor"))
    }

    fileprivate func update(isOnline: Bool) {
        let wasOffline = !self.isOnline
        self.isOnline = isOnline
        if isOnline && wasOffline {
            onReconnect?()
        }
    }

    /// Runs on the monitor's queue, so it is built outside the main actor.
    nonisolated private static func makeHandler(for monitor: NetworkMonitor) -> @Sendable (NWPath) -> Void {
        { [weak monitor] path in
            let online = path.status == .satisfied
            guard let monitor else { return }
            Task { @MainActor in monitor.update(isOnline: online) }
        }
    }
}
