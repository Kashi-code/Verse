import Foundation
import Testing
@testable import Verse

struct PlaybackQueueTests {
    private func makeQueue(_ count: Int, startAt: Int? = 0, shuffled: Bool = false, seed: UInt64 = 1) -> (PlaybackQueue, SeededGenerator) {
        var rng = SeededGenerator(state: seed)
        var queue = PlaybackQueue()
        queue.replace(with: makeTracks(count), startAt: startAt, source: .songs, shuffled: shuffled, using: &rng)
        return (queue, rng)
    }

    private func titles(_ items: [QueueItem]) -> [String] { items.map(\.track.title) }

    @Test func playsInOrderAndStopsAtTheEnd() {
        var (queue, rng) = makeQueue(3)
        #expect(queue.current?.track.title == "Track 0")
        #expect(queue.advance(userInitiated: false, using: &rng)?.track.title == "Track 1")
        #expect(queue.advance(userInitiated: false, using: &rng)?.track.title == "Track 2")
        #expect(queue.advance(userInitiated: false, using: &rng) == nil)
        #expect(queue.current?.track.title == "Track 2")
    }

    @Test func repeatAllWraps() {
        var (queue, rng) = makeQueue(2, startAt: 1)
        queue.repeatMode = .all
        #expect(queue.advance(userInitiated: false, using: &rng)?.track.title == "Track 0")
    }

    @Test func repeatOneRepeatsUntilTheUserSkips() {
        var (queue, rng) = makeQueue(3)
        queue.repeatMode = .one
        #expect(queue.advance(userInitiated: false, using: &rng)?.track.title == "Track 0")
        #expect(queue.advance(userInitiated: true, using: &rng)?.track.title == "Track 1")
    }

    @Test func goingBack() {
        var (queue, _) = makeQueue(3, startAt: 1)
        #expect(queue.goBack())
        #expect(queue.current?.track.title == "Track 0")
        #expect(!queue.goBack())
        queue.repeatMode = .all
        #expect(queue.goBack())
        #expect(queue.current?.track.title == "Track 2")
    }

    @Test func shuffledStartPlaysTheChosenSongFirstThenEveryOtherSongOnce() {
        let (queue, _) = makeQueue(20, startAt: 7, shuffled: true)
        #expect(queue.isShuffled)
        #expect(queue.current?.track.title == "Track 7")
        #expect(queue.upNext.count == 19)
        #expect(Set(titles(queue.items)).count == 20)
    }

    @Test(arguments: [UInt64(1), 2, 3, 42, 1234])
    func shuffleRepeatAllNeverRepeatsWithinACycle(seed: UInt64) {
        var (queue, rng) = makeQueue(10, startAt: nil, shuffled: true, seed: seed)
        queue.repeatMode = .all
        var played = [queue.current!.track.title]
        for _ in 0..<29 {
            played.append(queue.advance(userInitiated: false, using: &rng)!.track.title)
        }
        for cycle in 0..<3 {
            let slice = played[(cycle * 10)..<((cycle + 1) * 10)]
            #expect(Set(slice).count == 10, "cycle \(cycle) repeated a song")
        }
        // A new cycle never starts with the song that just ended.
        #expect(played[9] != played[10])
        #expect(played[19] != played[20])
    }

    @Test func shufflingMidQueueKeepsHistoryAndUnshuffleRestoresOrder() {
        var (queue, rng) = makeQueue(10, startAt: 3)
        queue.setShuffled(true, using: &rng)
        #expect(queue.current?.track.title == "Track 3")
        #expect(titles(Array(queue.items.prefix(3))) == ["Track 0", "Track 1", "Track 2"])
        #expect(Set(titles(queue.upNext)) == Set((4..<10).map { "Track \($0)" }))

        queue.advance(userInitiated: true, using: &rng)
        let playing = queue.current?.track.title
        queue.setShuffled(false, using: &rng)
        #expect(!queue.isShuffled)
        #expect(titles(queue.items) == (0..<10).map { "Track \($0)" })
        #expect(queue.current?.track.title == playing)
    }

    @Test func insertNextAndAppend() {
        var (queue, _) = makeQueue(3)
        let extra = makeTracks(2).map { track in
            var track = track
            track.title = "Extra \(track.title)"
            return track
        }
        queue.insertNext([extra[0]])
        queue.append([extra[1]])
        #expect(titles(queue.upNext) == ["Extra Track 0", "Track 1", "Track 2", "Extra Track 1"])
    }

    @Test func insertedSongsSurviveUnshuffle() {
        var (queue, rng) = makeQueue(4)
        queue.setShuffled(true, using: &rng)
        var extra = makeTracks(1)[0]
        extra.title = "Inserted"
        queue.insertNext([extra])
        #expect(queue.upNext.first?.track.title == "Inserted")
        queue.setShuffled(false, using: &rng)
        #expect(titles(queue.items) == ["Track 0", "Inserted", "Track 1", "Track 2", "Track 3"])
    }

    @Test func removeMoveAndClearUpNext() {
        var (queue, _) = makeQueue(5)
        queue.removeFromUpNext(queue.upNext[1].id)
        #expect(titles(queue.upNext) == ["Track 1", "Track 3", "Track 4"])

        // The current song can't be removed from Up Next.
        queue.removeFromUpNext(queue.current!.id)
        #expect(queue.current?.track.title == "Track 0")

        queue.moveUpNext(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(titles(queue.upNext) == ["Track 4", "Track 1", "Track 3"])

        queue.moveUpNext(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(titles(queue.upNext) == ["Track 1", "Track 3", "Track 4"])

        queue.clearUpNext()
        #expect(queue.upNext.isEmpty)
        #expect(queue.current?.track.title == "Track 0")
    }

    @Test func jumpAndEmptyQueue() {
        var (queue, rng) = makeQueue(4)
        let target = queue.upNext[2]
        #expect(queue.jump(to: target.id) == target)
        #expect(queue.current == target)

        var empty = PlaybackQueue()
        empty.replace(with: [], startAt: 0, source: nil, shuffled: true, using: &rng)
        #expect(empty.current == nil)
        #expect(empty.advance(userInitiated: true, using: &rng) == nil)
        #expect(!empty.goBack())
    }

    @Test func survivesEncoding() throws {
        var (queue, rng) = makeQueue(5, shuffled: true)
        queue.repeatMode = .one
        queue.advance(userInitiated: true, using: &rng)
        let data = try JSONEncoder().encode(queue)
        #expect(try JSONDecoder().decode(PlaybackQueue.self, from: data) == queue)
    }
}
