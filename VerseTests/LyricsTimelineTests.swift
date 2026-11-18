import Foundation
import Testing
@testable import Verse

struct LyricsTimelineTests {
    private func kinds(_ items: [LyricsItem]) -> [String] {
        items.map { item in
            switch item.kind {
            case .line(let line): "line:\(line.text)@\(item.start)"
            case .gap(let end): "gap@\(item.start)-\(end)"
            }
        }
    }

    @Test func introAndInstrumentalGaps() {
        let lyrics = LyricsParser.parse("""
        [00:08.00]First
        [00:10.00]Second
        [00:12.00]
        [00:30.00]Third
        [00:33.00]
        [00:35.00]Fourth
        """)
        let items = LyricsLayout.items(for: lyrics)
        #expect(kinds(items) == [
            "gap@0.0-8.0",
            "line:First@8.0",
            "line:Second@10.0",
            "gap@12.0-30.0",
            "line:Third@30.0",
            // 2 s break: too short for a gap.
            "line:Fourth@35.0",
        ])
        #expect(items.map(\.id) == Array(0..<items.count))
    }

    @Test func gapAfterWordTimedLine() {
        let lyrics = LyricsParser.parse("""
        [00:01.00]<00:01.00>Short <00:01.50>line<00:02.00>
        [00:20.00]<00:20.00>Much<00:21.00>
        [00:22.00]<00:22.00>later<00:23.00>
        """)
        let items = LyricsLayout.items(for: lyrics)
        #expect(kinds(items) == [
            "line:Short line@1.0",
            "gap@2.0-20.0",
            "line:Much@20.0",
            "line:later@22.0",
        ])
    }

    @Test func plainLyricsHaveNoGaps() {
        let items = LyricsLayout.items(for: LyricsParser.parse("One\n\nTwo"))
        #expect(items.count == 3)
        #expect(items.allSatisfy { if case .line = $0.kind { true } else { false } })
    }

    @Test func findsTheActiveRow() {
        let lyrics = LyricsParser.parse("""
        [00:01.00]A
        [00:03.00]B
        [00:03.00]B translated
        [00:07.50]C
        """)
        let timeline = LyricsTimeline(items: LyricsLayout.items(for: lyrics))
        #expect(timeline.activeIndex(at: 0) == nil)
        #expect(timeline.activeIndex(at: 0.999) == nil)
        #expect(timeline.activeIndex(at: 1) == 0)
        #expect(timeline.activeIndex(at: 2.99) == 0)
        #expect(timeline.activeIndex(at: 3) == 1)
        #expect(timeline.activeIndex(at: 7.5) == 2)
        #expect(timeline.activeIndex(at: 10_000) == 2)
    }

    @Test func emptyTimeline() {
        #expect(LyricsTimeline(items: []).activeIndex(at: 5) == nil)
    }

    @Test func gapProgress() {
        #expect(LyricsTimeline.progress(from: 10, to: 20, at: 5) == 0)
        #expect(LyricsTimeline.progress(from: 10, to: 20, at: 15) == 0.5)
        #expect(LyricsTimeline.progress(from: 10, to: 20, at: 25) == 1)
        #expect(LyricsTimeline.progress(from: 10, to: 10, at: 10) == 1)
    }

    @Test func karaokeMaskStopsAreOrdered() {
        for progress in stride(from: 0.0, through: 1.0, by: 0.05) {
            let locations = KaraokeWord.maskStops(progress: progress).map(\.location)
            #expect(locations == locations.sorted())
            #expect(locations.allSatisfy { (0...1).contains($0) })
        }
    }
}
