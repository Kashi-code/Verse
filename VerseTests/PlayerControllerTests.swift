import Foundation
import Testing
@testable import Verse

@MainActor
struct PlayerControllerTests {
    let backend = FakeAudioBackend()
    let player: PlayerController

    init() {
        player = PlayerController(backend: backend)
        player.autoplayEnabled = false
    }

    @Test func playingStartsTheChosenSong() {
        player.play(makeTracks(3), startingAt: 1)
        #expect(player.isPlaying)
        #expect(player.currentTrack?.title == "Track 1")
        #expect(backend.loadedURLs.last?.lastPathComponent == "track1.mp3")
        #expect(player.duration == 180)
        // The next song is queued up so it starts without a gap.
        #expect(backend.preparedURL?.lastPathComponent == "track2.mp3")
    }

    @Test func preparedSongTakesOverWithoutReloading() {
        player.play(makeTracks(3))
        backend.finishIntoPrepared()
        #expect(player.currentTrack?.title == "Track 1")
        #expect(player.isPlaying)
        #expect(backend.loadedURLs.count == 1)
        #expect(backend.preparedURL?.lastPathComponent == "track2.mp3")
    }

    @Test func queueEditsUpdateThePreparedSong() {
        player.play(makeTracks(3))
        var extra = makeTracks(1)[0]
        extra.id = CatalogID(.apple, "extra")
        extra.streamURL = URL(string: "https://example.com/extra.m4a")
        player.playNext([extra])
        #expect(backend.preparedURL?.lastPathComponent == "extra.m4a")
        player.cycleRepeatMode() // all
        player.cycleRepeatMode() // one
        #expect(backend.preparedURL?.lastPathComponent == "track0.mp3")
    }

    @Test func songsWithoutAStreamAreSkipped() {
        var tracks = makeTracks(3)
        tracks[1].streamURL = nil
        player.play(tracks, startingAt: 2)
        #expect(player.currentTrack?.title == "Track 2")
        #expect(player.queue.items.count == 2)
    }

    @Test func resumesASavedQueuePaused() {
        var queue = PlaybackQueue()
        queue.replace(with: makeTracks(3), startAt: 1, source: .songs, shuffled: false)
        player.restore(queue, position: 42)
        #expect(player.currentTrack?.title == "Track 1")
        #expect(!player.isPlaying)
        #expect(backend.currentTime == 42)
    }

    @Test func failedStreamIsRetriedAfterReconnect() {
        backend.failingFileNames = ["track0.mp3"]
        player.play(makeTracks(2))
        #expect(player.errorMessage != nil)
        backend.failingFileNames = []
        player.retryAfterReconnect()
        #expect(player.errorMessage == nil)
        #expect(player.isPlaying)
        #expect(player.currentTrack?.title == "Track 0")
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
