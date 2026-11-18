import Foundation
import Observation

/// User preferences, persisted in `UserDefaults`.
@MainActor
@Observable
final class AppSettings {
    static let crossfadeRange: ClosedRange<Double> = 0...12

    @ObservationIgnored private let defaults: UserDefaults

    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }
    var crossfadeSeconds: Double {
        didSet { defaults.set(crossfadeSeconds, forKey: Key.crossfade) }
    }
    var gaplessPlayback: Bool {
        didSet { defaults.set(gaplessPlayback, forKey: Key.gapless) }
    }
    var launchBehavior: LaunchBehavior {
        didSet { defaults.set(launchBehavior.rawValue, forKey: Key.launch) }
    }
    var lyricsTextSize: LyricsTextSize {
        didSet { defaults.set(lyricsTextSize.rawValue, forKey: Key.lyricsTextSize) }
    }
    var showLyricsTranslations: Bool {
        didSet { defaults.set(showLyricsTranslations, forKey: Key.translations) }
    }
    var lrclibEnabled: Bool {
        didSet { defaults.set(lrclibEnabled, forKey: Key.lrclib) }
    }
    var autoplay: Bool {
        didSet { defaults.set(autoplay, forKey: Key.autoplay) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = AppearanceMode(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .dark
        let storedCrossfade = defaults.object(forKey: Key.crossfade) as? Double ?? 0
        crossfadeSeconds = min(max(storedCrossfade, Self.crossfadeRange.lowerBound), Self.crossfadeRange.upperBound)
        gaplessPlayback = defaults.object(forKey: Key.gapless) as? Bool ?? true
        launchBehavior = LaunchBehavior(rawValue: defaults.string(forKey: Key.launch) ?? "") ?? .resume
        lyricsTextSize = LyricsTextSize(rawValue: defaults.string(forKey: Key.lyricsTextSize) ?? "") ?? .medium
        showLyricsTranslations = defaults.object(forKey: Key.translations) as? Bool ?? true
        lrclibEnabled = defaults.object(forKey: Key.lrclib) as? Bool ?? true
        autoplay = defaults.object(forKey: Key.autoplay) as? Bool ?? true
    }

    enum Key {
        static let appearance = "settings.appearance"
        static let crossfade = "settings.crossfadeSeconds"
        static let gapless = "settings.gapless"
        static let launch = "settings.launchBehavior"
        static let lyricsTextSize = "settings.lyricsTextSize"
        static let translations = "settings.showLyricsTranslations"
        static let lrclib = "settings.lrclibEnabled"
        static let autoplay = "settings.autoplay"
    }
}
