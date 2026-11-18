import Foundation

/// Apple's public catalog without MusicKit: charts from the Apple marketing RSS feeds and
/// 30-second previews from the iTunes Search API (about 20 requests per minute).
/// Full songs need Apple Music (MusicKit), which comes later.
struct AppleCatalogClient: Sendable {
    var http: any HTTPClient
    var country: String

    static let searchBase = URL(string: "https://itunes.apple.com")!
    static let chartsBase = URL(string: "https://rss.marketingtools.apple.com/api/v2")!

    static var currentCountry: String {
        Locale.current.region?.identifier.lowercased() ?? "us"
    }

    // MARK: Charts

    /// Most-played songs in the store's country, in chart order, with previews.
    func topSongs(limit: Int = 25) async throws -> [TrackInfo] {
        let feedURL = Self.chartsBase.appending(path: "\(country)/music/most-played/\(limit)/songs.json")
        guard let feed = try await http.getJSON(AppleChartFeed.self, from: feedURL) else { return [] }
        let ids = feed.feed.results.map(\.id)
        guard !ids.isEmpty else { return [] }
        let songs = try await lookup(ids: ids)
        let order = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return songs.sorted { (order[$0.id.value] ?? .max) < (order[$1.id.value] ?? .max) }
    }

    // MARK: Search

    func searchSongs(_ text: String, limit: Int = 20) async throws -> [TrackInfo] {
        try await search(text, entity: "song", limit: limit).compactMap(makeTrack)
    }

    func searchArtists(_ text: String, limit: Int = 8) async throws -> [CatalogArtist] {
        try await search(text, entity: "musicArtist", limit: limit).compactMap(makeArtist)
    }

    func searchAlbums(_ text: String, limit: Int = 10) async throws -> [CatalogCollection] {
        try await search(text, entity: "album", limit: limit).compactMap(makeAlbum)
    }

    // MARK: Lookup

    func lookup(ids: [String]) async throws -> [TrackInfo] {
        let url = Self.searchBase.appending(path: "lookup").appendingQuery([
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "country", value: country),
        ])
        return try await items(from: url).compactMap(makeTrack)
    }

    func albumTracks(albumID: String) async throws -> [TrackInfo] {
        let url = Self.searchBase.appending(path: "lookup").appendingQuery([
            URLQueryItem(name: "id", value: albumID),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "country", value: country),
        ])
        return try await items(from: url).compactMap(makeTrack)
    }

    func artistSongs(artistID: String, limit: Int = 20) async throws -> [TrackInfo] {
        let url = Self.searchBase.appending(path: "lookup").appendingQuery([
            URLQueryItem(name: "id", value: artistID),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "country", value: country),
        ])
        return try await items(from: url).compactMap(makeTrack)
    }

    func artistAlbums(artistID: String, limit: Int = 20) async throws -> [CatalogCollection] {
        let url = Self.searchBase.appending(path: "lookup").appendingQuery([
            URLQueryItem(name: "id", value: artistID),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "country", value: country),
        ])
        return try await items(from: url).compactMap(makeAlbum)
    }

    // MARK: Mapping

    func makeTrack(_ item: AppleItem) -> TrackInfo? {
        guard item.wrapperType == "track", item.kind == "song",
              let trackID = item.trackId, let previewURL = item.previewUrl,
              let title = item.trackName, let artist = item.artistName else { return nil }
        return TrackInfo(
            id: CatalogID(.apple, String(trackID)),
            title: title,
            artist: artist,
            artistID: item.artistId.map { CatalogID(.apple, String($0)) },
            album: item.collectionName,
            albumID: item.collectionId.map { CatalogID(.apple, String($0)) },
            duration: Double(item.trackTimeMillis ?? 0) / 1000,
            artworkURL: Self.artwork(item.artworkUrl100, size: 600),
            thumbnailURL: Self.artwork(item.artworkUrl100, size: 200),
            genre: item.primaryGenreName,
            streamURL: previewURL,
            isPreview: true,
            externalURL: item.trackViewUrl,
            playCount: nil
        )
    }

    func makeArtist(_ item: AppleItem) -> CatalogArtist? {
        guard item.wrapperType == "artist", let id = item.artistId, let name = item.artistName else { return nil }
        return CatalogArtist(
            id: CatalogID(.apple, String(id)),
            name: name,
            imageURL: nil,
            followerCount: nil,
            isVerified: false,
            genre: item.primaryGenreName,
            externalURL: item.artistLinkUrl ?? item.artistViewUrl
        )
    }

    func makeAlbum(_ item: AppleItem) -> CatalogCollection? {
        guard item.wrapperType == "collection", let id = item.collectionId, let title = item.collectionName else { return nil }
        return CatalogCollection(
            id: CatalogID(.apple, String(id)),
            kind: .album,
            title: title,
            subtitle: item.artistName ?? "",
            artworkURL: Self.artwork(item.artworkUrl100, size: 600),
            trackCount: item.trackCount,
            ownerID: item.artistId.map { CatalogID(.apple, String($0)) },
            externalURL: item.collectionViewUrl
        )
    }

    /// Apple artwork URLs end in `100x100bb.jpg`; the same image exists at other sizes.
    static func artwork(_ url: URL?, size: Int) -> URL? {
        guard let url else { return nil }
        let text = url.absoluteString
        guard text.contains("100x100bb") else { return url }
        return URL(string: text.replacingOccurrences(of: "100x100bb", with: "\(size)x\(size)bb")) ?? url
    }

    // MARK: Requests

    private func search(_ text: String, entity: String, limit: Int) async throws -> [AppleItem] {
        let url = Self.searchBase.appending(path: "search").appendingQuery([
            URLQueryItem(name: "term", value: text),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: entity),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "country", value: country),
        ])
        return try await items(from: url)
    }

    private func items(from url: URL) async throws -> [AppleItem] {
        try await http.getJSON(AppleSearchResponse.self, from: url)?.results.values ?? []
    }
}

struct AppleSearchResponse: Decodable, Sendable {
    let resultCount: Int?
    let results: LossyArray<AppleItem>
}

/// One result from the iTunes Search API (songs, artists and albums share this shape).
struct AppleItem: Decodable, Sendable {
    let wrapperType: String?
    let kind: String?
    let trackId: Int?
    let collectionId: Int?
    let artistId: Int?
    let trackName: String?
    let collectionName: String?
    let artistName: String?
    let artworkUrl100: URL?
    let previewUrl: URL?
    let trackTimeMillis: Int?
    let primaryGenreName: String?
    let trackViewUrl: URL?
    let collectionViewUrl: URL?
    let artistViewUrl: URL?
    let artistLinkUrl: URL?
    let trackCount: Int?
}

/// The marketing-tools chart feed: `feed.results[]` with string IDs.
struct AppleChartFeed: Decodable, Sendable {
    struct Feed: Decodable, Sendable {
        let results: [Item]
    }

    struct Item: Decodable, Sendable {
        let id: String
        let name: String?
        let artistName: String?
    }

    let feed: Feed
}
