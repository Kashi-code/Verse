import Foundation

/// Answers catalog requests with real responses saved in `Resources/SampleData`. Used by tests,
/// previews and the screenshot run, so they exercise the same decoding as the live app.
struct SampleHTTPClient: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url!
        guard let name = Self.sampleName(for: url),
              let file = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: file) else {
            return (Data(), HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        }
        return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    static func sampleName(for url: URL) -> String? {
        let path = url.path()
        let query = url.query() ?? ""
        switch url.host() ?? "" {
        case "api.audius.co":
            if path.hasSuffix("/tracks/trending") || path.hasSuffix("/tracks") { return "audius-trending" }
            if path.hasSuffix("/tracks/search") { return "audius-search-tracks" }
            if path.hasSuffix("/users/search") || path.hasSuffix("/users/top") { return "audius-search-users" }
            if path.hasSuffix("/playlists/search") || path.hasSuffix("/playlists/trending")
                || path.hasSuffix("/playlists") || path.hasSuffix("/albums") { return "audius-search-playlists" }
            return nil
        case "rss.marketingtools.apple.com":
            return "apple-chart"
        case "itunes.apple.com":
            if path.hasSuffix("/lookup") { return query.contains("entity=album") ? "apple-search-album" : "apple-lookup" }
            if query.contains("entity=musicArtist") { return "apple-search-artist" }
            if query.contains("entity=album") { return "apple-search-album" }
            return "apple-search-song"
        default:
            return nil
        }
    }
}

extension MergedCatalog {
    static func sample() -> MergedCatalog {
        let http = SampleHTTPClient()
        return MergedCatalog(
            audius: AudiusClient(http: http, apiKey: nil),
            apple: AppleCatalogClient(http: http, country: "us")
        )
    }
}
