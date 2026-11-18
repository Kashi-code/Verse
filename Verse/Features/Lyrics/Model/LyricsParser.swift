import Foundation

/// Parses plain text, LRC (`[mm:ss.xx]` line times) and enhanced LRC (`<mm:ss.xx>` word times).
///
/// Handles several timestamps per line, `[offset:]`, metadata tags, empty instrumental lines and
/// translations given as a second line with the same timestamp. Never fails: anything it can't
/// read is treated as text or skipped.
enum LyricsParser {
    private struct TimedEntry {
        let start: TimeInterval
        let body: String
        let order: Int
    }

    static func parse(_ text: String) -> Lyrics {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var offset: TimeInterval = 0
        var timed: [TimedEntry] = []
        var untimed: [String] = []

        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            var rest = Substring(line)
            var stamps: [TimeInterval] = []
            var isMetadata = false

            while rest.first == "[", let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                if let time = timestamp(from: tag) {
                    stamps.append(time)
                } else if let metadata = metadataTag(tag) {
                    isMetadata = true
                    if metadata.key == "offset",
                       let milliseconds = Double(metadata.value.trimmingCharacters(in: .whitespaces)) {
                        offset = milliseconds / 1000
                    }
                } else {
                    break // Not a tag, e.g. "[Chorus]": keep it as text.
                }
                rest = rest[rest.index(after: close)...]
            }

            if !stamps.isEmpty {
                for stamp in stamps {
                    timed.append(TimedEntry(start: stamp, body: String(rest), order: timed.count))
                }
            } else if !isMetadata {
                untimed.append(line)
            }
        }

        return timed.isEmpty ? plain(untimed) : synced(timed, offset: offset)
    }

    // MARK: Plain

    private static func plain(_ lines: [String]) -> Lyrics {
        var kept: [String] = []
        for line in lines {
            // Collapse runs of blank lines and drop leading ones.
            if line.isEmpty && (kept.last?.isEmpty ?? true) { continue }
            kept.append(line)
        }
        while kept.last?.isEmpty == true { kept.removeLast() }
        let result = kept.enumerated().map { LyricsLine(id: $0.offset, text: $0.element, start: 0, end: 0) }
        return Lyrics(lines: result, timing: .none)
    }

    // MARK: Synced

    private static func synced(_ entries: [TimedEntry], offset: TimeInterval) -> Lyrics {
        let sorted = entries.sorted { ($0.start, $0.order) < ($1.start, $1.order) }
        var lines: [LyricsLine] = []

        for entry in sorted {
            let start = max(entry.start - offset, 0)
            var lineWords = words(in: entry.body, lineStart: entry.start)?.map { word in
                var word = word
                word.start = max(word.start - offset, 0)
                if word.end >= 0 { word.end = max(word.end - offset, 0) }
                return word
            }
            if lineWords?.isEmpty == true { lineWords = nil }
            let text = lineWords.map(joined) ?? entry.body.trimmingCharacters(in: .whitespaces)

            if let last = lines.last {
                // Same timestamp twice: the second line is a translation of the first.
                if abs(last.start - start) < 0.001, !last.isInstrumental, !text.isEmpty, last.translation == nil {
                    lines[lines.count - 1].translation = text
                    continue
                }
                // Collapse runs of instrumental lines.
                if text.isEmpty && last.isInstrumental { continue }
            }
            lines.append(LyricsLine(id: 0, text: text, start: start, end: start, words: lineWords))
        }

        while lines.last?.isInstrumental == true { lines.removeLast() }

        for index in lines.indices {
            lines[index].id = index
            let nextStart = index + 1 < lines.count ? lines[index + 1].start : nil
            if var words = lines[index].words, let last = words.indices.last, words[last].end < 0 {
                // No closing timestamp: give the last word up to 3 s, never past the next line.
                let fallback = words[last].start + 3
                words[last].end = max(min(nextStart ?? fallback, fallback), words[last].start)
                lines[index].words = words
            }
            let wordsEnd = lines[index].words?.last?.end
            lines[index].end = nextStart ?? max(wordsEnd ?? lines[index].start + 5, lines[index].start)
        }

        let timing: Lyrics.Timing = lines.contains { $0.words != nil } ? .word : .line
        return Lyrics(lines: lines, timing: timing)
    }

    /// Splits `<mm:ss.xx>` tagged text into words. Returns nil when the body has no word tags.
    /// Words without a following tag get `end == -1`, filled in by the caller.
    private static func words(in body: String, lineStart: TimeInterval) -> [LyricsWord]? {
        var segments: [(time: TimeInterval?, text: String)] = []
        var currentTime: TimeInterval?
        var currentText = ""
        var sawTag = false
        var index = body.startIndex

        while index < body.endIndex {
            if body[index] == "<",
               let close = body[index...].firstIndex(of: ">"),
               let time = timestamp(from: body[body.index(after: index)..<close]) {
                segments.append((currentTime, currentText))
                currentTime = time
                currentText = ""
                sawTag = true
                index = body.index(after: close)
            } else {
                currentText.append(body[index])
                index = body.index(after: index)
            }
        }
        segments.append((currentTime, currentText))
        guard sawTag else { return nil }

        var words: [LyricsWord] = []
        for (position, segment) in segments.enumerated() {
            let trimmed = segment.text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let following = segments[(position + 1)...]
            let end = following.lazy.compactMap { $0.time }.first ?? -1
            let nextText = following.first { !$0.text.isEmpty }?.text
            let trailingSpace = segment.text.last?.isWhitespace == true || nextText?.first?.isWhitespace == true
            words.append(LyricsWord(
                text: trimmed,
                start: segment.time ?? lineStart,
                end: end,
                hasTrailingSpace: trailingSpace
            ))
        }
        return words
    }

    private static func joined(_ words: [LyricsWord]) -> String {
        words
            .map { $0.text + ($0.hasTrailingSpace ? " " : "") }
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: Tags

    /// `mm:ss`, `mm:ss.x`, `mm:ss.xx`, `mm:ss.xxx` or `mm:ss:xx`.
    static func timestamp(from tag: Substring) -> TimeInterval? {
        let parts = tag.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3, isDigits(parts[0]), let minutes = Int(parts[0]) else {
            return nil
        }
        var secondsText = parts[1]
        var fractionText: Substring = ""
        if parts.count == 3 {
            fractionText = parts[2]
        } else if let dot = secondsText.firstIndex(of: ".") {
            fractionText = secondsText[secondsText.index(after: dot)...]
            secondsText = secondsText[..<dot]
        }
        guard secondsText.count <= 2, isDigits(secondsText), let seconds = Int(secondsText), seconds < 60 else {
            return nil
        }
        var fraction = 0.0
        if !fractionText.isEmpty {
            guard fractionText.count <= 3, isDigits(fractionText), let value = Double("0." + fractionText) else {
                return nil
            }
            fraction = value
        }
        return Double(minutes * 60 + seconds) + fraction
    }

    /// `[ar:Artist]`, `[offset:+250]` and similar: a lowercase-letter key, a colon and a value.
    private static func metadataTag(_ tag: Substring) -> (key: String, value: String)? {
        guard let colon = tag.firstIndex(of: ":") else { return nil }
        let key = tag[..<colon].lowercased()
        guard !key.isEmpty, key.count <= 10, key.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        return (key, String(tag[tag.index(after: colon)...]))
    }

    private static func isDigits(_ text: Substring) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
