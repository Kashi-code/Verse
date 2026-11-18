import Foundation
import Testing
@testable import Verse

/// Decoding tests run against real API responses saved in `Resources/SampleData`.
struct AudiusDecodingTests {
    let client = AudiusClient(http: SampleHTTPClient(), apiKey: "test-key")

    @Test func decodesTrendingTracks() async throws {
        let tracks = try await client.trendingTracks()
        #expect(!tracks.isEmpty)
        let first = try #require(tracks.first)
        #expect(first.id.source == .audius)
        #expect(!first.title.isEmpty)
        #expect(!first.artist.isEmpty)
        #expect(first.duration > 0)
        #expect(first.artworkURL?.absoluteString.contains("1000x1000") == true)
        #expect(first.thumbnailURL?.absoluteString.contains("150x150") == true)
        #expect(first.isPreview == false)
    }

    @Test func streamURLUsesTheAPIKeyButNoSecret() throws {
        let url = client.streamURL(trackID: "abc")
        let text = url.absoluteString
        #expect(text.hasPrefix("https://api.audius.co/v1/tracks/abc/stream?"))
        #expect(text.contains("app_name=Verse"))
        #expect(text.contains("api_key=test-key"))
    }

    @Test func decodesUsersAndPlaylists() async throws {
        let users = try await client.searchUsers("lofi")
        #expect(!users.isEmpty)
        #expect(users.allSatisfy { $0.id.source == .audius && !$0.name.isEmpty })
        let playlists = try await client.searchPlaylists("lofi")
        #expect(!playlists.isEmpty)
        #expect(playlists.allSatisfy { !$0.title.isEmpty && !$0.subtitle.isEmpty })
    }

    private func track(_ json: String) throws -> AudiusTrackDTO {
        try JSONDecoder.catalog.decode(AudiusTrackDTO.self, from: Data(json.utf8))
    }

    private let base = #""id":"t1","title":"Song","duration":200,"user":{"id":"u1","name":"Someone"}"#

    @Test func skipsTracksThatWontPlay() throws {
        #expect(client.isPlayable(try track("{\(base)}")))
        #expect(!client.isPlayable(try track(#"{\#(base),"is_streamable":false}"#)))
        #expect(!client.isPlayable(try track(#"{\#(base),"is_stream_gated":true}"#)))
        #expect(!client.isPlayable(try track(#"{\#(base),"is_delete":true}"#)))
        #expect(!client.isPlayable(try track(#"{\#(base),"is_available":false}"#)))
        #expect(!client.isPlayable(try track(#"{\#(base),"access":{"stream":false}}"#)))
        #expect(!client.isPlayable(try track(#"{\#(base),"allowed_api_keys":["someone-else"]}"#)))
        #expect(client.isPlayable(try track(#"{\#(base),"allowed_api_keys":["test-key"]}"#)))
    }

    @Test func oneBrokenTrackDoesNotBreakTheList() throws {
        let json = #"{"data":[{\#(base)},{"id":5},{"id":"t2","title":"Two","user":{"id":"u","name":"N"}}]}"#
        let decoded = try JSONDecoder.catalog.decode(AudiusEnvelope<LossyArray<AudiusTrackDTO>>.self, from: Data(json.utf8))
        #expect(decoded.data.values.map(\.id) == ["t1", "t2"])
    }
}

struct AppleCatalogTests {
    let client = AppleCatalogClient(http: SampleHTTPClient(), country: "us")

    @Test func chartSongsHavePreviewsInChartOrder() async throws {
        let songs = try await client.topSongs(limit: 25)
        #expect(!songs.isEmpty)
        #expect(songs.allSatisfy { $0.isPreview && $0.streamURL != nil && $0.id.source == .apple })
        #expect(songs.first?.title == "Choosin' Texas")
    }

    @Test func searchesSongsArtistsAndAlbums() async throws {
        #expect(try await !client.searchSongs("taylor swift").isEmpty)
        #expect(try await !client.searchArtists("taylor swift").isEmpty)
        let albums = try await client.searchAlbums("taylor swift")
        #expect(!albums.isEmpty)
        #expect(albums.allSatisfy { $0.kind == .album && $0.artworkURL?.absoluteString.contains("600x600bb") == true })
    }

    @Test func artworkSizes() {
        let url = URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music/x/y.jpg/100x100bb.jpg")
        #expect(AppleCatalogClient.artwork(url, size: 600)?.absoluteString.hasSuffix("/600x600bb.jpg") == true)
        #expect(AppleCatalogClient.artwork(URL(string: "https://example.com/a.jpg"), size: 600)?.absoluteString == "https://example.com/a.jpg")
        #expect(AppleCatalogClient.artwork(nil, size: 600) == nil)
    }
}

struct MergedCatalogTests {
    let catalog = MergedCatalog.sample()

    @Test func homeFeedMixesPopularAndAudius() async throws {
        let feed = try await catalog.homeFeed()
        #expect(!feed.topSongs.isEmpty)
        #expect(!feed.genres.isEmpty)
        #expect(!feed.topArtists.isEmpty)
        #expect(Set(feed.trending.map(\.source)) == [.apple, .audius])
        // Hero alternates: popular first.
        #expect(feed.trending.first?.source == .apple)
    }

    @Test func searchMergesBothSources() async throws {
        let results = try await catalog.search("lofi")
        #expect(results.top != nil)
        #expect(Set(results.songs.map(\.source)).count == 2)
        #expect(!results.artists.isEmpty)
        #expect(!results.collections.isEmpty)
    }

    @Test func emptyQueryReturnsNothing() async throws {
        #expect(try await catalog.search("   ").isEmpty)
    }

    @Test func genreMapping() {
        #expect(MergedCatalog.audiusGenre(for: "Dance") == "Electronic")
        #expect(MergedCatalog.audiusGenre(for: "Deep House, Electro Tech") == "Deep House")
        #expect(MergedCatalog.audiusGenre(for: nil) == nil)
    }
}

struct SearchRankingTests {
    private func track(_ title: String, _ artist: String, _ source: CatalogSource = .audius) -> TrackInfo {
        TrackInfo(id: CatalogID(source, title + artist), title: title, artist: artist, duration: 100)
    }

    @Test func matchScores() {
        #expect(SearchRanking.matchScore("Blinding Lights", query: "blinding lights") == 3)
        #expect(SearchRanking.matchScore("Blinding Lights", query: "blind") == 2)
        #expect(SearchRanking.matchScore("Blinding Lights", query: "lights") == 1)
        #expect(SearchRanking.matchScore("Café del Mar", query: "cafe") == 2)
        #expect(SearchRanking.matchScore("Something", query: "xyz") == 0)
        #expect(SearchRanking.matchScore("Something", query: "  ") == 0)
    }

    @Test func mergeInterleavesThenRanksByMatch() {
        let apple = [track("Other Song", "A", .apple), track("Midnight", "B", .apple)]
        let audius = [track("Midnight Drive", "C"), track("Random", "D")]
        let merged = SearchRanking.mergeTracks([apple, audius], query: "midnight")
        #expect(merged.map(\.title) == ["Midnight", "Midnight Drive", "Other Song", "Random"])
    }

    @Test func mergeRemovesDuplicates() {
        let merged = SearchRanking.mergeTracks([[track("Song", "Artist", .apple)], [track("song ", "ARTIST")]], query: "song")
        #expect(merged.count == 1)
        #expect(merged.first?.source == .apple)
    }

    @Test func topResultPrefersExactArtist() {
        let artist = CatalogArtist(id: CatalogID(.apple, "1"), name: "Daft Punk", imageURL: nil)
        let songs = [track("Daft Punk Is Playing", "X")]
        #expect(SearchRanking.topResult(songs: songs, artists: [artist], collections: [], query: "daft punk") == .artist(artist))
        #expect(SearchRanking.topResult(songs: songs, artists: [], collections: [], query: "daft punk") == .track(songs[0]))
        #expect(SearchRanking.topResult(songs: [], artists: [], collections: [], query: "x") == nil)
    }

    @Test func interleave() {
        #expect(SearchRanking.interleave([[1, 2, 3], [10], [20, 21]]) == [1, 10, 20, 2, 21, 3])
    }
}
