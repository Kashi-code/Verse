import Foundation
import Testing
@testable import Verse

@MainActor
struct PlayerControllerTests {
    let backend = FakeAudioBackend()
    let player: PlayerController

    init() {
        player = PlayerController(
            backend: backend,
            music: ManagedFileStore(directory: URL(filePath: "/tmp/VerseTestsMusic", directoryHint: .isDirectory))
        )
    }

    @Test func playingStartsTheChosenSong() {
        player.play(makeTracks(3), startingAt: 1)
        #expect(player.isPlaying)
        #expect(player.currentTrack?.title == "Track 1")
        #expect(backend.loadedURLs.last?.lastPathComponent == "track1.mp3")
        #expect(player.duration == 180)
    }

    @Test func finishingASongPlaysTheNextOne() {
        player.play(makeTracks(2))
        backend.finish()
        #expect(player.currentTrack?.title == "Track 1")
        #expect(player.isPlaying)
    }

    @Test func stopsAtTheEndOfTheQueue() {
        player.play(makeTracks(2), startingAt: 1)
        backend.finish()
        #expect(!player.isPlaying)
        #expect(player.currentTrack?.title == "Track 1")
        #expect(backend.currentTime == 0)
    }

    @Test func repeatOneReplaysTheSameSong() {
        player.play(makeTracks(2))
        player.cycleRepeatMode() // all
        player.cycleRepeatMode() // one
        #expect(player.repeatMode == .one)
        backend.finish()
        #expect(player.currentTrack?.title == "Track 0")
        #expect(backend.loadedURLs.count == 2)
    }

    @Test func previousRestartsAfterThreeSeconds() {
        player.play(makeTracks(3), startingAt: 1)
        backend.currentTime = 42
        player.skipToPrevious()
        #expect(player.currentTrack?.title == "Track 1")
        #expect(backend.currentTime == 0)

        player.skipToPrevious()
        #expect(player.currentTrack?.title == "Track 0")
    }

    @Test func pauseAndResume() {
        player.play(makeTracks(1))
        player.togglePlayPause()
        #expect(!player.isPlaying)
        #expect(!backend.isPlaying)
        player.togglePlayPause()
        #expect(player.isPlaying)
        #expect(backend.isPlaying)
    }

    @Test func skippingWhilePausedStaysPaused() {
        player.play(makeTracks(3))
        player.pause()
        player.skipToNext()
        #expect(player.currentTrack?.title == "Track 1")
        #expect(!player.isPlaying)
    }

    @Test func aFileThatFailsToLoadShowsAnError() {
        backend.failingFileNames = ["track0.mp3"]
        player.play(makeTracks(2))
        #expect(!player.isPlaying)
        #expect(player.errorMessage != nil)

        player.skipToNext()
        #expect(player.errorMessage == nil)
    }

    @Test func playNextWithEmptyQueueStartsPlaying() {
        player.playNext(makeTracks(1))
        #expect(player.isPlaying)
        #expect(player.currentTrack?.title == "Track 0")
    }
}
