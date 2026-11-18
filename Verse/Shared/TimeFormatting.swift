import Foundation

enum TimeFormatting {
    /// "3:05" or "1:02:03".
    static func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(max(seconds, 0).rounded(.down))
        let duration = Duration.seconds(whole)
        return whole >= 3600
            ? duration.formatted(.time(pattern: .hourMinuteSecond))
            : duration.formatted(.time(pattern: .minuteSecond))
    }

    /// "42 minutes" or "1 hour, 5 minutes".
    static func total(_ seconds: TimeInterval) -> String {
        let minutes = Int((max(seconds, 0) / 60).rounded())
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }
}
