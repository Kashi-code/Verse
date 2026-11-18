import Foundation
import Testing
@testable import Verse

struct LyricsParserTests {
    private func approx(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.0001 }

    @Test func plainText() {
        let lyrics = LyricsParser.parse("\n\nFirst line\nSecond line\n\n\n\nAfter a break\n\n")
        #expect(lyrics.timing == .none)
        #expect(lyrics.lines.map(\.text) == ["First line", "Second line", "", "After a break"])
    }

    @Test func standardLRC() {
        let lyrics = LyricsParser.parse("""
        [ar:Someone]
        [ti:A Song]
        [length: 03:20]
        [00:12.00]Hello there
        [00:15.50]General greeting
        [01:02.345]Later on
        """)
        #expect(lyrics.timing == .line)
        #expect(lyrics.lines.map(\.text) == ["Hello there", "General greeting", "Later on"])
        #expect(approx(lyrics.lines[0].start, 12))
        #expect(approx(lyrics.lines[1].start, 15.5))
        #expect(approx(lyrics.lines[2].start, 62.345))
        #expect(approx(lyrics.lines[0].end, 15.5))
        #expect(lyrics.lines.map(\.id) == [0, 1, 2])
    }

    @Test func multipleTimestampsPerLineAreSorted() {
        let lyrics = LyricsParser.parse("""
        [00:10.00][00:40.00]Chorus line
        [00:20.00]Verse line
        """)
        #expect(lyrics.lines.map(\.text) == ["Chorus line", "Verse line", "Chorus line"])
        #expect(lyrics.lines.map(\.start) == [10, 20, 40])
    }

    @Test func offsetShiftsEverything() {
        let lyrics = LyricsParser.parse("""
        [offset:+500]
        [00:10.00]<00:10.00>Hi <00:11.00>there<00:12.00>
        [00:00.20]Intro
        """)
        #expect(approx(lyrics.lines[0].start, 0))
        #expect(approx(lyrics.lines[1].start, 9.5))
        let words = lyrics.lines[1].words ?? []
        #expect(approx(words[0].start, 9.5))
        #expect(approx(words[1].end, 11.5))
    }

    @Test func negativeOffset() {
        let lyrics = LyricsParser.parse("[offset:-1000]\n[00:05.00]Line")
        #expect(approx(lyrics.lines[0].start, 6))
    }

    @Test func enhancedWordTiming() throws {
        let lyrics = LyricsParser.parse("""
        [00:01.00]<00:01.00>Never <00:01.50>gonna <00:02.20>stop<00:03.00>
        [00:04.00]<00:04.00>Next<00:04.80>
        """)
        #expect(lyrics.timing == .word)
        let line = lyrics.lines[0]
        #expect(line.text == "Never gonna stop")
        let words = try #require(line.words)
        #expect(words.map(\.text) == ["Never", "gonna", "stop"])
        #expect(zip(words.map(\.start), [1, 1.5, 2.2]).allSatisfy { approx($0, $1) })
        #expect(zip(words.map(\.end), [1.5, 2.2, 3]).allSatisfy { approx($0, $1) })
        #expect(words.map(\.hasTrailingSpace) == [true, true, false])
    }

    @Test func wordsWithoutSpacesStayJoined() throws {
        let lyrics = LyricsParser.parse("[00:01.00]<00:01.00>夜<00:01.40>空<00:01.80>")
        let words = try #require(lyrics.lines.first?.words)
        #expect(words.map(\.hasTrailingSpace) == [false, false])
        #expect(lyrics.lines.first?.text == "夜空")
    }

    @Test func lastWordWithoutClosingTagGetsAnEnd() throws {
        let lyrics = LyricsParser.parse("""
        [00:01.00]<00:01.00>One <00:02.00>two
        [00:10.00]Next
        """)
        let words = try #require(lyrics.lines.first?.words)
        #expect(words[1].end == 5) // capped at 3 s
        #expect(lyrics.lines[0].end == 10)
    }

    @Test func instrumentalLinesAreKeptAndCollapsed() {
        let lyrics = LyricsParser.parse("""
        [00:01.00]Sing
        [00:05.00]
        [00:06.00]
        [00:30.00]Sing again
        [00:40.00]
        """)
        #expect(lyrics.lines.map(\.text) == ["Sing", "", "Sing again"])
        #expect(lyrics.lines[1].isInstrumental)
        #expect(lyrics.lines[1].end == 30)
    }

    @Test func translationsShareTheTimestamp() {
        let lyrics = LyricsParser.parse("""
        [00:01.00]Bonjour
        [00:01.00]Hello
        [00:03.00]Merci
        """)
        #expect(lyrics.lines.count == 2)
        #expect(lyrics.lines[0].translation == "Hello")
        #expect(lyrics.lines[1].translation == nil)
    }

    @Test(arguments: [
        ("1:02", 62.0), ("01:02.5", 62.5), ("01:02.50", 62.5), ("01:02.345", 62.345), ("01:02:34", 62.34), ("120:00", 7200.0),
    ])
    func timestampFormats(_ tag: String, expected: Double) {
        let value = LyricsParser.timestamp(from: Substring(tag))
        #expect(value.map { approx($0, expected) } == true)
    }

    @Test(arguments: ["", "ab:cd", "01:60", "01:2x", "-1:00", "01:02.3456", "1", "1:2:3:4", "01:+5"])
    func invalidTimestamps(_ tag: String) {
        #expect(LyricsParser.timestamp(from: Substring(tag)) == nil)
    }

    @Test(arguments: [
        "", "[", "[]", "[abc", "[99:99.99]x", "<>", "[00:01.00]<", "[00:01.00]<bad>word", "[00:01.00]<00:02.00",
        "]]]]", "[00:01.00][00:02.00]", "🎵🎶", String(repeating: "[", count: 500), "\u{0}",
    ])
    func badInputDoesNotCrash(_ input: String) {
        _ = LyricsParser.parse(input)
    }

    @Test func bracketedTextThatIsNotATagIsKept() {
        let lyrics = LyricsParser.parse("[Chorus]\nLa la la")
        #expect(lyrics.timing == .none)
        #expect(lyrics.lines.map(\.text) == ["[Chorus]", "La la la"])
    }

    @Test func untimedLinesInAnLRCFileAreIgnored() {
        let lyrics = LyricsParser.parse("Some header\n[00:01.00]Real line")
        #expect(lyrics.lines.map(\.text) == ["Real line"])
    }

    @Test func windowsLineEndings() {
        let lyrics = LyricsParser.parse("[00:01.00]One\r\n[00:02.00]Two\r\n")
        #expect(lyrics.lines.map(\.text) == ["One", "Two"])
    }

    @Test func wordProgress() {
        let word = LyricsWord(text: "a", start: 10, end: 12, hasTrailingSpace: false)
        #expect(word.progress(at: 9) == 0)
        #expect(word.progress(at: 11) == 0.5)
        #expect(word.progress(at: 13) == 1)
        let instant = LyricsWord(text: "b", start: 5, end: 5, hasTrailingSpace: false)
        #expect(instant.progress(at: 4.9) == 0)
        #expect(instant.progress(at: 5) == 1)
    }
}
