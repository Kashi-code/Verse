import Foundation

/// A record from LRCLIB's `/api/get` and `/api/search`.
struct LRCLIBRecord: Decodable, Sendable, Equatable {
    let id: Int
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?
}

enum LRCLIBError: Error, Equatable {
    case badStatus(Int)
}

/// Minimal client for https://lrclib.net. Only the song's title, artist, album and length are sent.
struct LRCLIBClient: Sendable {
    var http: any HTTPClient
    var userAgent: String
    var baseURL = URL(string: "https://lrclib.net/api")!

    /// Exact lookup, then a search fallback. Returns nil when nothing matches.
    func bestMatch(title: String, artist: String, album: String, duration: TimeInterval) async throws -> LRCLIBRecord? {
        if let exact = try await get(title: title, artist: artist, album: album, duration: duration) {
            return exact
        }
        let results = try await search(title: title, artist: artist)
        return Self.pickBest(results, duration: duration)
    }

    func get(title: String, artist: String, album: String, duration: TimeInterval) async throws -> LRCLIBRecord? {
        var items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name", value: album),
        ]
        if duration > 0 {
            items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        guard let data = try await send(path: "get", query: items) else { return nil }
        return try JSONDecoder().decode(LRCLIBRecord.self, from: data)
    }

    func search(title: String, artist: String) async throws -> [LRCLIBRecord] {
        let items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        guard let data = try await send(path: "search", query: items) else { return [] }
        return try JSONDecoder().decode([LRCLIBRecord].self, from: data)
    }

    /// Prefers results within 2 s of the song's length, then synced lyrics, then the closest length.
    static func pickBest(_ records: [LRCLIBRecord], duration: TimeInterval) -> LRCLIBRecord? {
        let usable = records.filter { record in
            record.syncedLyrics?.isEmpty == false || record.plainLyrics?.isEmpty == false || record.instrumental == true
        }
        let candidates = usable.filter { record in
            guard duration > 0, let recordDuration = record.duration else { return true }
            return abs(recordDuration - duration) <= 2
        }
        return candidates.min { a, b in
            let aSynced = a.syncedLyrics?.isEmpty == false
            let bSynced = b.syncedLyrics?.isEmpty == false
            if aSynced != bSynced { return aSynced }
            return distance(a, duration) < distance(b, duration)
        }
    }

    func makeRequest(path: String, query: [URLQueryItem]) -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        // URLComponents leaves "+" alone, but servers read it as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        return request
    }

    private func send(path: String, query: [URLQueryItem]) async throws -> Data? {
        let (data, response) = try await http.data(for: makeRequest(path: path, query: query))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300: return data
        case 404: return nil
        default: throw LRCLIBError.badStatus(status)
        }
    }

    private static func distance(_ record: LRCLIBRecord, _ duration: TimeInterval) -> Double {
        guard duration > 0, let recordDuration = record.duration else { return .greatestFiniteMagnitude }
        return abs(recordDuration - duration)
    }
}
