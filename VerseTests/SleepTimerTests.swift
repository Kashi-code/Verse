import Foundation
import Testing
@testable import Verse

@MainActor
struct SleepTimerTests {
    let backend = FakeAudioBackend()
    let player: PlayerController

    init() {
        player = PlayerController(backend: backend)
        player.autoplayEnabled = false
    }

    @Test func endOfSongStopsAfterTheCurrentSong() {
        player.play(makeTracks(3))
        player.setSleepTimer(.endOfSong)
        // Nothing is lined up, so the song really ends.
        #expect(backend.preparedURL == nil)

        backend.finish()
        #expect(!player.isPlaying)
        #expect(player.sleepTimer == nil)
        // Ready on the next song, paused.
        #expect(player.currentTrack?.title == "Track 1")
        #expect(backend.preparedURL?.lastPathComponent == "track2.mp3")
    }

    @Test func timedTimerPausesWhenItFires() {
        player.play(makeTracks(2))
        player.setSleepTimer(.minutes(15))
        let remaining = player.sleepTimerEndDate.map { $0.timeIntervalSinceNow } ?? 0
        #expect(remaining > 14 * 60 && remaining <= 15 * 60)
        #expect(backend.preparedURL != nil)

        player.sleepTimerFired()
        #expect(!player.isPlaying)
        #expect(player.sleepTimer == nil)
        #expect(player.sleepTimerEndDate == nil)
    }

    @Test func turningOffRestoresThePreparedSong() {
        player.play(makeTracks(2))
        player.setSleepTimer(.endOfSong)
        player.setSleepTimer(nil)
        #expect(player.sleepTimer == nil)
        #expect(backend.preparedURL?.lastPathComponent == "track1.mp3")
    }

    @Test func playSimilarKeepsTheSongAndReplacesUpNext() async {
        player.catalog = MergedCatalog.sample()
        player.play(makeTracks(3))
        let found = await player.playSimilarSongs()
        #expect(found)
        #expect(player.currentTrack?.title == "Track 0")
        #expect(!player.upNext.isEmpty)
        #expect(!player.upNext.contains { $0.track.title == "Track 1" })
    }
}
