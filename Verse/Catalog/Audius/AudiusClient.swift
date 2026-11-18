import Foundation

/// Client for the open Audius catalog. Only the public API key is used (it is meant for client
/// apps); no secret or bearer token ever ships in the app.
struct AudiusClient: Sendable {
    var http: any HTTPClient
    var apiKey: String?
    var baseURL = URL(string: "https://api.audius.co/v1")!
    var appName = "Verse"

    static let website = URL(string: "https://audius.co")!

    // MARK: Tracks

    func trendingTracks(genre: String? = nil, time: String = "week", limit: Int = 20) async throws -> [TrackInfo] {
        var query = [URLQueryItem(name: "time", value: time), URLQueryItem(name: "limit", value: String(limit))]
        if let genre { query.append(URLQueryItem(name: "genre", value: genre)) }
        return try await tracks(at: "tracks/trending", query: query)
    }

    func searchTracks(_ text: String, limit: Int = 20) async throws -> [TrackInfo] {
        try await tracks(at: "tracks/search", query: [
            URLQueryItem(name: "query", value: text),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    func playlistTracks(id: String) async throws -> [TrackInfo] {
        try await tracks(at: "playlists/\(id)/tracks", query: [])
    }

    func userTracks(id: String, limit: Int = 20) async throws -> [TrackInfo] {
        try await tracks(at: "users/\(id)/tracks", query: [
            URLQueryItem(name: "sort_method", value: "plays"),
            URLQueryItem(name: "sort_direction", value: "desc"),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    /// Playback URL. The endpoint redirects to a content node and supports range requests.
    func streamURL(trackID: String) -> URL {
        baseURL.appending(path: "tracks/\(trackID)/stream").appendingQuery(commonQuery)
    }

    // MARK: Users

    func searchUsers(_ text: String, limit: Int = 10) async throws -> [CatalogArtist] {
        try await users(at: "users/search", query: [
            URLQueryItem(name: "query", value: text),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    func topUsers(limit: Int = 12) async throws -> [CatalogArtist] {
        try await users(at: "users/top", query: [URLQueryItem(name: "limit", value: String(limit))])
    }

    // MARK: Playlists

    func searchPlaylists(_ text: String, limit: Int = 10) async throws -> [CatalogCollection] {
        try await playlists(at: "playlists/search", query: [
            URLQueryItem(name: "query", value: text),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    func trendingPlaylists(limit: Int = 12) async throws -> [CatalogCollection] {
        try await playlists(at: "playlists/trending", query: [URLQueryItem(name: "limit", value: String(limit))])
    }

    func userPlaylists(id: String) async throws -> [CatalogCollection] {
        try await playlists(at: "users/\(id)/playlists", query: [URLQueryItem(name: "limit", value: "20")])
    }

    func userAlbums(id: String) async throws -> [CatalogCollection] {
        try await playlists(at: "users/\(id)/albums", query: [URLQueryItem(name: "limit", value: "20")])
    }

    // MARK: Mapping

    /// Tracks that would not play for us are dropped instead of shown as broken rows.
    func isPlayable(_ track: AudiusTrackDTO) -> Bool {
        if track.isDelete == true || track.isAvailable == false || track.isStreamable == false { return false }
        if track.isStreamGated == true || track.access?.stream == false { return false }
        if let allowed = track.allowedApiKeys, !allowed.isEmpty {
            guard let apiKey, allowed.contains(apiKey) else { return false }
        }
        return true
    }

    func makeTrack(_ dto: AudiusTrackDTO) -> TrackInfo? {
        guard isPlayable(dto) else { return nil }
        return TrackInfo(
            id: CatalogID(.audius, dto.id),
            title: dto.title,
            artist: dto.user.name,
            artistID: CatalogID(.audius, dto.user.id),
            album: nil,
            albumID: nil,
            duration: dto.duration ?? 0,
            artworkURL: dto.artwork?.large ?? dto.artwork?.medium ?? dto.artwork?.small,
            thumbnailURL: dto.artwork?.small ?? dto.artwork?.medium,
            genre: dto.genre,
            streamURL: streamURL(trackID: dto.id),
            isPreview: false,
            externalURL: dto.permalink.map { Self.website.appending(path: $0) },
            playCount: dto.playCount
        )
    }

    func makeArtist(_ dto: AudiusUserDTO) -> CatalogArtist {
        CatalogArtist(
            id: CatalogID(.audius, dto.id),
            name: dto.name,
            imageURL: dto.profilePicture?.medium ?? dto.profilePicture?.large ?? dto.profilePicture?.small,
            followerCount: dto.followerCount,
            isVerified: dto.isVerified ?? false,
            genre: nil,
            externalURL: dto.handle.map { Self.website.appending(path: $0) }
        )
    }

    func makeCollection(_ dto: AudiusPlaylistDTO) -> CatalogCollection {
        CatalogCollection(
            id: CatalogID(.audius, dto.id),
            kind: dto.isAlbum == true ? .album : .playlist,
            title: dto.playlistName,
            subtitle: dto.user.name,
            artworkURL: dto.artwork?.large ?? dto.artwork?.medium ?? dto.artwork?.small,
            trackCount: dto.trackCount,
            ownerID: CatalogID(.audius, dto.user.id),
            externalURL: dto.permalink.map { Self.website.appending(path: $0) }
        )
    }

    // MARK: Requests

    private var commonQuery: [URLQueryItem] {
        var items = [URLQueryItem(name: "app_name", value: appName)]
        if let apiKey, !apiKey.isEmpty {
            items.append(URLQueryItem(name: "api_key", value: apiKey))
        }
        return items
    }

    func url(path: String, query: [URLQueryItem]) -> URL {
        baseURL.appending(path: path).appendingQuery(query + commonQuery)
    }

    private func tracks(at path: String, query: [URLQueryItem]) async throws -> [TrackInfo] {
        let response = try await http.getJSON(AudiusEnvelope<LossyArray<AudiusTrackDTO>>.self, from: url(path: path, query: query))
        return response?.data.values.compactMap(makeTrack) ?? []
    }

    private func users(at path: String, query: [URLQueryItem]) async throws -> [CatalogArtist] {
        let response = try await http.getJSON(AudiusEnvelope<LossyArray<AudiusUserDTO>>.self, from: url(path: path, query: query))
        return response?.data.values.map(makeArtist) ?? []
    }

    private func playlists(at path: String, query: [URLQueryItem]) async throws -> [CatalogCollection] {
        let response = try await http.getJSON(AudiusEnvelope<LossyArray<AudiusPlaylistDTO>>.self, from: url(path: path, query: query))
        return response?.data.values.map(makeCollection) ?? []
    }
}
