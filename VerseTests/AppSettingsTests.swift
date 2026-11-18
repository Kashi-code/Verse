import Foundation
import Testing
@testable import Verse

@MainActor
struct AppSettingsTests {
    private func makeDefaults() throws -> UserDefaults {
        let suite = "VerseTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func usesSensibleDefaults() throws {
        let settings = AppSettings(defaults: try makeDefaults())
        #expect(settings.appearance == .system)
        #expect(settings.crossfadeSeconds == 0)
        #expect(settings.gaplessPlayback)
        #expect(settings.launchBehavior == .resume)
        #expect(settings.lyricsTextSize == .medium)
        #expect(settings.lrclibEnabled)
    }

    @Test func persistsChanges() throws {
        let defaults = try makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.appearance = .dark
        settings.crossfadeSeconds = 6
        settings.lrclibEnabled = false
        settings.lyricsTextSize = .large

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.appearance == .dark)
        #expect(reloaded.crossfadeSeconds == 6)
        #expect(!reloaded.lrclibEnabled)
        #expect(reloaded.lyricsTextSize == .large)
    }

    @Test func clampsStoredCrossfade() throws {
        let defaults = try makeDefaults()
        defaults.set(40.0, forKey: AppSettings.Key.crossfade)
        #expect(AppSettings(defaults: defaults).crossfadeSeconds == 12)
    }
}
