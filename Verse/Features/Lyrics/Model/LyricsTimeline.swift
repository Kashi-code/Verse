import Foundation

/// One row of the synced lyrics view: a line, or an instrumental gap shown as three dots.
struct LyricsItem: Identifiable, Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case line(LyricsLine)
        case gap(end: TimeInterval)
    }

    let id: Int
    let start: TimeInterval
    let kind: Kind
}

/// Turns lyrics into rows once per song, so nothing has to be worked out per frame.
enum LyricsLayout {
    /// Breaks shorter than this aren't shown as a gap.
    static let minimumGap: TimeInterval = 5

    static func items(for lyrics: Lyrics) -> [LyricsItem] {
        guard lyrics.timing != .none else {
            return lyrics.lines.enumerated().map { LyricsItem(id: $0.offset, start: 0, kind: .line($0.element)) }
        }

        var rows: [(start: TimeInterval, kind: LyricsItem.Kind)] = []
        let lines = lyrics.lines

        // Intro before the first sung line.
        if let first = lines.first, !first.isInstrumental, first.start >= minimumGap {
            rows.append((0, .gap(end: first.start)))
        }

        for (index, line) in lines.enumerated() {
            let next = index + 1 < lines.count ? lines[index + 1] : nil
            if line.isInstrumental {
                if let next, next.start - line.start >= minimumGap {
                    rows.append((line.start, .gap(end: next.start)))
                }
                continue
            }
            rows.append((line.start, .line(line)))

            // With word timing we know when singing stops, so a long silence before the next line is a gap.
            if let next, !next.isInstrumental, let sungUntil = line.words?.last?.end, next.start - sungUntil >= minimumGap {
                rows.append((sungUntil, .gap(end: next.start)))
            }
        }

        return rows.enumerated().map { LyricsItem(id: $0.offset, start: $0.element.start, kind: $0.element.kind) }
    }
}

/// Finds the active row for a playback time with a binary search.
struct LyricsTimeline: Sendable {
    private let starts: [TimeInterval]

    init(items: [LyricsItem]) {
        starts = items.map(\.start)
    }

    /// The last row that has started at `time`, or nil before the first row.
    func activeIndex(at time: TimeInterval) -> Int? {
        var low = 0
        var high = starts.count - 1
        var result: Int?
        while low <= high {
            let middle = (low + high) / 2
            if starts[middle] <= time {
                result = middle
                low = middle + 1
            } else {
                high = middle - 1
            }
        }
        return result
    }

    static func progress(from start: TimeInterval, to end: TimeInterval, at time: TimeInterval) -> Double {
        guard end > start else { return 1 }
        return min(max((time - start) / (end - start), 0), 1)
    }
}
