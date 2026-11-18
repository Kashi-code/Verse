import Foundation

/// The one catalog the app sees: Audius (full songs) and Apple's public catalog (previews),
/// merged. A failing source only removes its own results.
struct MergedCatalog: CatalogService {
    var audius: AudiusClient
    var apple: AppleCatalogClient

    static let homeGenres = ["Electronic", "Hip-Hop/Rap", "Lo-Fi", "Pop", "Rock"]

    static func live() -> MergedCatalog {
        let http = URLSessionHTTPClient()
        let key = Bundle.main.object(forInfoDictionaryKey: "AudiusAPIKey") as? String
        return MergedCatalog(
            audius: AudiusClient(http: http, apiKey: key?.isEmpty == false ? key : nil),
            apple: AppleCatalogClient(http: http, country: AppleCatalogClient.currentCountry)
        )
    }

    func homeFeed() async throws -> HomeFeed {
        async let trending = audius.trendingTracks(limit: 20)
        async let charts = apple.topSongs(limit: 25)
        async let artists = audius.topUsers(limit: 12)
        async let playlists = audius.trendingPlaylists(limit: 12)
        async let shelves = genreShelves()

        let trendingTracks = (try? await trending) ?? []
        let topSongs = (try? await charts) ?? []

        var feed = HomeFeed()
        // Hero: popular songs and Audius trending, alternating.
        feed.trending = Array(SearchRanking.interleave([Array(topSongs.prefix(6)), Array(trendingTracks.prefix(6))]))
        feed.topSongs = topSongs
        feed.genres = await shelves
        feed.topArtists = (try? await artists) ?? []
        feed.playlists = (try? await playlists) ?? []
        if feed.isEmpty { throw CatalogError.unavailable }
        return feed
    }

    func search(_ query: String) async throws -> SearchResults {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return SearchResults() }

        async let appleSongs = apple.searchSongs(text)
        async let appleArtists = apple.searchArtists(text)
        async let appleAlbums = apple.searchAlbums(text)
        async let audiusSongs = audius.searchTracks(text)
        async let audiusArtists = audius.searchUsers(text)
        async let audiusPlaylists = audius.searchPlaylists(text)

        let songs = SearchRanking.mergeTracks([(try? await appleSongs) ?? [], (try? await audiusSongs) ?? []], query: text)
        let artists = SearchRanking.mergeArtists([(try? await appleArtists) ?? [], (try? await audiusArtists) ?? []], query: text)
        let collections = SearchRanking.mergeCollections([(try? await appleAlbums) ?? [], (try? await audiusPlaylists) ?? []], query: text)

        var results = SearchResults(songs: songs, artists: artists, collections: collections)
        results.top = SearchRanking.topResult(songs: songs, artists: artists, collections: collections, query: text)
        return results
    }

    func trending(genre: String) async throws -> [TrackInfo] {
        try await audius.trendingTracks(genre: genre, time: "month", limit: 40)
    }

    func tracks(in collection: CatalogCollection) async throws -> [TrackInfo] {
        switch collection.id.source {
        case .audius: try await audius.playlistTracks(id: collection.id.value)
        case .apple: try await apple.albumTracks(albumID: collection.id.value)
        }
    }

    func artistPage(for artist: CatalogArtist) async throws -> ArtistPage {
        switch artist.id.source {
        case .audius:
            async let tracks = audius.userTracks(id: artist.id.value)
            async let albums = audius.userAlbums(id: artist.id.value)
            async let playlists = audius.userPlaylists(id: artist.id.value)
            return ArtistPage(
                artist: artist,
                popular: try await tracks,
                releases: (try? await albums) ?? [],
                playlists: (try? await playlists) ?? []
            )
        case .apple:
            async let songs = apple.artistSongs(artistID: artist.id.value)
            async let albums = apple.artistAlbums(artistID: artist.id.value)
            return ArtistPage(artist: artist, popular: try await songs, releases: (try? await albums) ?? [])
        }
    }

    /// Same genre on Audius (full songs), skipping the song itself.
    func similarTracks(to track: TrackInfo) async throws -> [TrackInfo] {
        let genre = Self.audiusGenre(for: track.genre)
        let tracks = try await audius.trendingTracks(genre: genre, time: "month", limit: 30)
        return tracks.filter { $0.id != track.id }
    }

    private func genreShelves() async -> [GenreShelf] {
        await withTaskGroup(of: (Int, GenreShelf?).self) { group in
            for (index, genre) in Self.homeGenres.enumerated() {
                group.addTask {
                    let tracks = (try? await audius.trendingTracks(genre: genre, limit: 12)) ?? []
                    return (index, tracks.isEmpty ? nil : GenreShelf(genre: genre, tracks: tracks))
                }
            }
            var shelves: [(Int, GenreShelf)] = []
            for await (index, shelf) in group {
                if let shelf { shelves.append((index, shelf)) }
            }
            return shelves.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// Maps Apple genre names onto Audius genres where they differ.
    static func audiusGenre(for genre: String?) -> String? {
        guard let genre else { return nil }
        let map = ["Hip-Hop/Rap": "Hip-Hop/Rap", "Hip-Hop": "Hip-Hop/Rap", "Rap": "Hip-Hop/Rap", "R&B/Soul": "R&B/Soul",
                   "Dance": "Electronic", "Electronic": "Electronic", "Alternative": "Alternative", "Pop": "Pop",
                   "Rock": "Rock", "Country": "Folk", "Singer/Songwriter": "Folk", "Latin": "Latin", "Jazz": "Jazz",
                   "Classical": "Classical", "Metal": "Metal", "Soundtrack": "Soundtrack"]
        return map[genre] ?? genre.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces)
    }
}

enum CatalogError: Error {
    case unavailable
}
