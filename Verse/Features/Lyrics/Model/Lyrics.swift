import Foundation

struct LyricsWord: Sendable, Equatable {
    var text: String
    var start: TimeInterval
    var end: TimeInterval
    /// Whether a space follows this word when the line is written out.
    var hasTrailingSpace: Bool

    /// How far the word has been sung at `time`, from 0 to 1.
    func progress(at time: TimeInterval) -> Double {
        guard end > start else { return time >= start ? 1 : 0 }
        return min(max((time - start) / (end - start), 0), 1)
    }
}

struct LyricsLine: Sendable, Equatable, Identifiable {
    var id: Int
    var text: String
    var start: TimeInterval
    var end: TimeInterval
    /// Present only when the source has real word timing.
    var words: [LyricsWord]? = nil
    var translation: String? = nil

    /// An empty timed line marks an instrumental break.
    var isInstrumental: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }
}

struct Lyrics: Sendable, Equatable {
    enum Timing: Sendable, Equatable {
        case none, line, word
    }

    var lines: [LyricsLine]
    var timing: Timing

    var isEmpty: Bool { lines.allSatisfy(\.isInstrumental) }
}
