import Foundation
import Testing
@testable import Verse

struct MetadataParsingTests {
    @Test(arguments: [
        ("3/12", 3), ("3", 3), (" 7 / 10 ", 7), ("0/12", nil), ("abc", nil), ("", nil),
    ] as [(String, Int?)])
    func position(_ input: String, expected: Int?) {
        #expect(MetadataParsing.position(from: input) == expected)
    }

    @Test func iTunesPosition() {
        #expect(MetadataParsing.iTunesPosition(from: Data([0, 0, 0, 5, 0, 12, 0, 0])) == 5)
        #expect(MetadataParsing.iTunesPosition(from: Data([0, 0, 1, 2, 0, 0])) == 258)
        #expect(MetadataParsing.iTunesPosition(from: Data([0, 0, 0, 0])) == nil)
        #expect(MetadataParsing.iTunesPosition(from: Data([0, 1])) == nil)
    }

    @Test(arguments: [
        ("2019", 2019), ("2019-05-01", 2019), ("1999-12-31T23:00:00Z", 1999), ("19", nil), ("May 2019", nil),
    ] as [(String, Int?)])
    func year(_ input: String, expected: Int?) {
        #expect(MetadataParsing.year(from: input) == expected)
    }

    @Test func cleaned() {
        #expect(MetadataParsing.cleaned("  Song \n") == "Song")
        #expect(MetadataParsing.cleaned("   ") == nil)
        #expect(MetadataParsing.cleaned(nil) == nil)
    }

    @Test func fallbackTitleUsesFileName() {
        let url = URL(filePath: "/tmp/01_My_Song.mp3")
        #expect(MetadataParsing.fallbackTitle(for: url) == "01 My Song")
    }
}

struct ImportPlannerTests {
    @Test func pairsLyricsWithAudioByName() {
        let urls = [
            URL(filePath: "/a/Song One.mp3"),
            URL(filePath: "/a/song one.LRC"),
            URL(filePath: "/a/Song Two.flac"),
            URL(filePath: "/a/notes.txt"),
            URL(filePath: "/a/Orphan.lrc"),
        ]
        let plan = ImportPlanner.plan(urls)
        #expect(plan == [
            ImportPlanner.Item(audio: urls[0], lyrics: urls[1]),
            ImportPlanner.Item(audio: urls[2], lyrics: nil),
        ])
    }

    @Test func emptySelection() {
        #expect(ImportPlanner.plan([]).isEmpty)
    }
}
