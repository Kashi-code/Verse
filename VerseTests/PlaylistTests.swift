import Foundation
import SwiftData
import Testing
@testable import Verse

@MainActor
struct PlaylistTests {
    let container: ModelContainer
    let library: UserLibrary

    init() throws {
        container = try ModelContainer(
            for: Schema(LibrarySchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        library = UserLibrary(context: container.mainContext)
    }

    private func titles(_ playlist: Playlist) -> [String] {
        playlist.tracks.map(\.title)
    }

    @Test func createWithSongsKeepsOrderAndSkipsDuplicates() {
        let tracks = makeTracks(3)
        let playlist = library.createPlaylist(named: "  Road Trip ", with: tracks + [tracks[0]])
        #expect(playlist.name == "Road Trip")
        #expect(titles(playlist) == ["Track 0", "Track 1", "Track 2"])

        let added = library.add([tracks[1]] + makeTracks(5).suffix(2), to: playlist)
        #expect(added == 2)
        #expect(titles(playlist) == ["Track 0", "Track 1", "Track 2", "Track 3", "Track 4"])
        #expect(library.playlists().count == 1)
    }

    @Test func emptyNameGetsADefault() {
        let playlist = library.createPlaylist(named: "   ")
        #expect(!playlist.name.isEmpty)
    }

    @Test func mixedSourcesStayTogether() {
        var apple = makeTracks(1)[0]
        apple.id = CatalogID(.apple, "99")
        apple.title = "Apple Song"
        let playlist = library.createPlaylist(named: "Mixed", with: makeTracks(1) + [apple])
        #expect(playlist.tracks.map(\.source) == [.audius, .apple])
    }

    @Test func removeAndMoveRenumber() {
        let playlist = library.createPlaylist(named: "Edit", with: makeTracks(4))
        library.removeEntries(at: IndexSet(integer: 1), from: playlist)
        #expect(titles(playlist) == ["Track 0", "Track 2", "Track 3"])
        #expect(playlist.orderedEntries.map(\.position) == [0, 1, 2])

        library.moveEntries(fromOffsets: IndexSet(integer: 2), toOffset: 0, in: playlist)
        #expect(titles(playlist) == ["Track 3", "Track 0", "Track 2"])
    }

    @Test func renameAndDelete() throws {
        let playlist = library.createPlaylist(named: "Old", with: makeTracks(2))
        library.rename(playlist, to: "New")
        #expect(playlist.name == "New")
        library.rename(playlist, to: "  ")
        #expect(playlist.name == "New")

        library.delete(playlist)
        #expect(library.playlists().isEmpty)
        // Entries go with the playlist.
        #expect(try container.mainContext.fetch(FetchDescriptor<PlaylistEntry>()).isEmpty)
    }

    @Test func mosaicUsesFourDifferentCovers() {
        var tracks = makeTracks(6)
        for index in tracks.indices {
            tracks[index].artworkURL = URL(string: "https://example.com/\(index % 5).jpg")
        }
        tracks[1].artworkURL = tracks[0].artworkURL
        let urls = Playlist.mosaicURLs(from: tracks)
        #expect(urls.count == 4)
        #expect(Set(urls).count == 4)
    }

    @Test(arguments: [
        (IndexSet(integer: 0), 3, ["b", "c", "a", "d"]),
        (IndexSet(integer: 3), 0, ["d", "a", "b", "c"]),
        (IndexSet([0, 1]), 4, ["c", "d", "a", "b"]),
        (IndexSet(integer: 2), 2, ["a", "b", "c", "d"]),
    ])
    func moveMatchesListOnMove(source: IndexSet, destination: Int, expected: [String]) {
        #expect(UserLibrary.moved(["a", "b", "c", "d"], fromOffsets: source, toOffset: destination) == expected)
    }
}

struct MixBuilderTests {
    private func track(_ id: String, genre: String? = "Electronic") -> TrackInfo {
        var track = makeTracks(1)[0]
        track.id = CatalogID(.audius, id)
        track.title = id
        track.genre = genre
        return track
    }

    @Test func noHistoryMeansNoMixes() {
        #expect(MixBuilder.mixes(from: []).isEmpty)
    }

    @Test func onRepeatOrdersByPlayCount() {
        let a = track("a"), b = track("b"), c = track("c"), d = track("d")
        // Most recent first.
        let history = [a, b, c, b, a, b, c, d]
        let mixes = MixBuilder.mixes(from: history)
        let onRepeat = mixes.first { $0.kind == .onRepeat }
        #expect(onRepeat?.seeds.map(\.title) == ["b", "a", "c"])
    }

    @Test func genreMixesNeedThreePlays() {
        let history = [track("a", genre: "Pop"), track("b", genre: "Pop"), track("c", genre: "Pop"),
                       track("d", genre: "Rock"), track("e", genre: "Rock")]
        let kinds = MixBuilder.mixes(from: history).map(\.kind)
        #expect(kinds.contains(.genre("Pop")))
        #expect(!kinds.contains(.genre("Rock")))
        #expect(kinds.contains(.discover))
        #expect(!kinds.contains(.onRepeat))
    }

    @Test func onRepeatMixPlaysItsSeeds() async {
        let mix = Mix(kind: .onRepeat, seeds: [track("a"), track("b")])
        let tracks = await MixBuilder.tracks(for: mix, catalog: MergedCatalog.sample())
        #expect(tracks.map(\.title) == ["a", "b"])
    }
}
