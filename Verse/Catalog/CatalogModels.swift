import Foundation

enum CatalogSource: String, Codable, Sendable, Hashable, CaseIterable {
    case audius
    case apple

    var displayName: String {
        switch self {
        case .audius: "Audius"
        case .apple: "Apple Music"
        }
    }
}

/// A source plus that source's ID, e.g. `audius:Ma0blKV` or `apple:1844932150`.
struct CatalogID: Codable, Sendable, Hashable {
    var source: CatalogSource
    var value: String

    init(_ source: CatalogSource, _ value: String) {
        self.source = source
        self.value = value
    }

    init?(key: String) {
        let parts = key.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let source = CatalogSource(rawValue: String(parts[0])) else { return nil }
        self.init(source, String(parts[1]))
    }

    var key: String { "\(source.rawValue):\(value)" }
}

/// A playable song from any catalog. Also what the queue stores, so it is Codable and self-contained.
struct TrackInfo: Codable, Sendable, Hashable, Identifiable {
    var id: CatalogID
    var title: String
    var artist: String
    var artistID: CatalogID?
    var album: String?
    var albumID: CatalogID?
    /// Full length of the song, in seconds.
    var duration: TimeInterval
    var artworkURL: URL?
    var thumbnailURL: URL?
    var genre: String?
    var streamURL: URL?
    /// A 30-second preview rather than the full song (Apple catalog without Apple Music).
    var isPreview: Bool = false
    /// Where to open the song in its own app or site.
    var externalURL: URL?
    var playCount: Int?

    var source: CatalogSource { id.source }
}

struct CatalogArtist: Codable, Sendable, Hashable, Identifiable {
    var id: CatalogID
    var name: String
    var imageURL: URL?
    var followerCount: Int?
    var isVerified: Bool = false
    var genre: String?
    var externalURL: URL?
}

struct CatalogCollection: Codable, Sendable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable {
        case album, playlist
    }

    var id: CatalogID
    var kind: Kind
    var title: String
    /// Artist or playlist owner.
    var subtitle: String
    var artworkURL: URL?
    var trackCount: Int?
    var ownerID: CatalogID?
    var externalURL: URL?
}

struct GenreShelf: Sendable, Identifiable, Equatable {
    var genre: String
    var tracks: [TrackInfo]
    var id: String { genre }
}

struct HomeFeed: Sendable, Equatable {
    var trending: [TrackInfo] = []
    var topSongs: [TrackInfo] = []
    var genres: [GenreShelf] = []
    var topArtists: [CatalogArtist] = []
    var playlists: [CatalogCollection] = []

    var isEmpty: Bool {
        trending.isEmpty && topSongs.isEmpty && genres.isEmpty && topArtists.isEmpty && playlists.isEmpty
    }
}

enum SearchTopResult: Sendable, Equatable {
    case track(TrackInfo)
    case artist(CatalogArtist)
    case collection(CatalogCollection)
}

struct SearchResults: Sendable, Equatable {
    var top: SearchTopResult?
    var songs: [TrackInfo] = []
    var artists: [CatalogArtist] = []
    var collections: [CatalogCollection] = []

    var isEmpty: Bool { top == nil && songs.isEmpty && artists.isEmpty && collections.isEmpty }
}

struct ArtistPage: Sendable, Equatable {
    var artist: CatalogArtist
    var popular: [TrackInfo] = []
    var releases: [CatalogCollection] = []
    var playlists: [CatalogCollection] = []
}

/// Everything the app can ask a music catalog. Implemented by `MergedCatalog`; tests and previews
/// use the same type backed by bundled sample responses.
protocol CatalogService: Sendable {
    func homeFeed() async throws -> HomeFeed
    func search(_ query: String) async throws -> SearchResults
    func trending(genre: String) async throws -> [TrackInfo]
    func tracks(in collection: CatalogCollection) async throws -> [TrackInfo]
    func artistPage(for artist: CatalogArtist) async throws -> ArtistPage
    /// Songs to keep playing after the queue ends.
    func similarTracks(to track: TrackInfo) async throws -> [TrackInfo]
}
