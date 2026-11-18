import Foundation
import SwiftData
import Testing
@testable import Verse

@MainActor
struct UserLibraryTests {
    let container: ModelContainer
    let library: UserLibrary

    init() throws {
        container = try ModelContainer(
            for: Schema(LibrarySchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        library = UserLibrary(context: container.mainContext)
    }

    @Test func likesToggleAndKeepASnapshot() throws {
        let track = makeTracks(1)[0]
        #expect(!library.isLiked(track.id))
        #expect(library.toggleLike(track))
        #expect(library.isLiked(track.id))

        let stored = try container.mainContext.fetch(FetchDescriptor<LikedTrack>())
        #expect(stored.first?.track == track)

        #expect(!library.toggleLike(track))
        #expect(!library.isLiked(track.id))
    }

    @Test func savedCollectionsAndFollowedArtists() {
        let collection = CatalogCollection(id: CatalogID(.apple, "42"), kind: .album, title: "Album", subtitle: "Artist")
        #expect(library.toggleSaved(collection))
        #expect(library.isSaved(collection.id))
        #expect(!library.toggleSaved(collection))

        let artist = CatalogArtist(id: CatalogID(.audius, "u1"), name: "Someone", imageURL: nil)
        #expect(library.toggleFollow(artist))
        #expect(library.isFollowing(artist.id))
        #expect(!library.isFollowing(CatalogID(.apple, "u1")))
    }

    @Test func recentlyPlayedIsNewestFirstWithoutRepeats() {
        let tracks = makeTracks(3)
        let start = Date(timeIntervalSince1970: 1_000)
        library.recordPlay(of: tracks[0], at: start)
        library.recordPlay(of: tracks[1], at: start.addingTimeInterval(10))
        library.recordPlay(of: tracks[0], at: start.addingTimeInterval(20))
        library.recordPlay(of: tracks[2], at: start.addingTimeInterval(30))

        #expect(library.recentlyPlayed().map(\.title) == ["Track 2", "Track 0", "Track 1"])
        #expect(library.recentlyPlayed(limit: 2).count == 2)
    }

    @Test func lyricsOffsetsArePerSong() {
        let tracks = makeTracks(2)
        library.setLyricsOffset(0.3, for: tracks[0].id)
        library.setLyricsOffset(-0.2, for: tracks[0].id)
        #expect(library.lyricsOffset(for: tracks[0].id) == -0.2)
        #expect(library.lyricsOffset(for: tracks[1].id) == 0)
    }

    @Test func catalogIDKeysRoundTrip() {
        let id = CatalogID(.audius, "abc:def")
        #expect(id.key == "audius:abc:def")
        #expect(CatalogID(key: id.key) == id)
        #expect(CatalogID(key: "nope") == nil)
        #expect(CatalogID(key: "spotify:1") == nil)
    }
}
