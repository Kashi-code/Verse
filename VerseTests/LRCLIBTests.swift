import Foundation
import Synchronization
import Testing
@testable import Verse

/// Answers requests from a closure and records them.
final class FakeHTTPClient: HTTPClient {
    let requests = Mutex<[URLRequest]>([])
    let respond: @Sendable (URLRequest) -> (status: Int, body: String)

    init(respond: @escaping @Sendable (URLRequest) -> (status: Int, body: String)) {
        self.respond = respond
    }

    var requestCount: Int { requests.withLock { $0.count } }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.withLock { $0.append(request) }
        let (status, body) = respond(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

let sampleRecordJSON = """
{
  "id": 3396226,
  "trackName": "Test Song",
  "artistName": "Test Artist",
  "albumName": "Test Album",
  "duration": 233,
  "instrumental": false,
  "plainLyrics": "Line one\\nLine two",
  "syncedLyrics": "[00:17.12] Line one\\n[00:20.50] Line two"
}
"""

struct LRCLIBTests {
    @Test func decodesARecord() throws {
        let record = try JSONDecoder().decode(LRCLIBRecord.self, from: Data(sampleRecordJSON.utf8))
        #expect(record.id == 3396226)
        #expect(record.trackName == "Test Song")
        #expect(record.duration == 233)
        #expect(record.instrumental == false)
        #expect(record.syncedLyrics?.hasPrefix("[00:17.12]") == true)
    }

    @Test func decodesNullsAndMissingFields() throws {
        let json = #"[{"id": 1, "instrumental": true, "plainLyrics": null, "syncedLyrics": null}]"#
        let records = try JSONDecoder().decode([LRCLIBRecord].self, from: Data(json.utf8))
        #expect(records.count == 1)
        #expect(records[0].instrumental == true)
        #expect(records[0].trackName == nil)
    }

    @Test func buildsRequestsWithUserAgentAndEncodedQuery() throws {
        let client = LRCLIBClient(http: FakeHTTPClient { _ in (404, "") }, userAgent: "Verse/1.0")
        let request = client.makeRequest(path: "get", query: [
            URLQueryItem(name: "track_name", value: "Rock & Roll + More"),
            URLQueryItem(name: "artist_name", value: "Zoë"),
        ])
        let url = try #require(request.url?.absoluteString)
        #expect(url.hasPrefix("https://lrclib.net/api/get?"))
        #expect(url.contains("track_name=Rock%20%26%20Roll%20%2B%20More"))
        #expect(url.contains("artist_name=Zo%C3%AB"))
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "Verse/1.0")
    }

    @Test func notFoundFallsBackToSearch() async throws {
        let http = FakeHTTPClient { request in
            if request.url!.path().hasSuffix("/get") { return (404, #"{"code":404}"#) }
            return (200, "[\(sampleRecordJSON)]")
        }
        let client = LRCLIBClient(http: http, userAgent: "Verse/1.0")
        let record = try await client.bestMatch(title: "Test Song", artist: "Test Artist", album: "Test Album", duration: 234)
        #expect(record?.id == 3396226)
        #expect(http.requestCount == 2)
    }

    @Test func serverErrorsThrow() async {
        let client = LRCLIBClient(http: FakeHTTPClient { _ in (500, "") }, userAgent: "Verse/1.0")
        await #expect(throws: LRCLIBError.badStatus(500)) {
            _ = try await client.get(title: "a", artist: "b", album: "c", duration: 100)
        }
    }

    private func record(_ id: Int, duration: Double?, synced: Bool, plain: Bool = true) -> LRCLIBRecord {
        LRCLIBRecord(
            id: id, trackName: nil, artistName: nil, albumName: nil, duration: duration, instrumental: false,
            plainLyrics: plain ? "text" : nil, syncedLyrics: synced ? "[00:01.00]text" : nil
        )
    }

    @Test func picksSyncedLyricsWithAMatchingLength() {
        let records = [
            record(1, duration: 200, synced: false),
            record(2, duration: 202, synced: true),
            record(3, duration: 260, synced: true),
            record(4, duration: 200.5, synced: true),
        ]
        #expect(LRCLIBClient.pickBest(records, duration: 200)?.id == 4)
        #expect(LRCLIBClient.pickBest(records, duration: 300) == nil)
        #expect(LRCLIBClient.pickBest([record(5, duration: 200, synced: false, plain: false)], duration: 200) == nil)
        #expect(LRCLIBClient.pickBest([record(6, duration: nil, synced: false)], duration: 200)?.id == 6)
    }
}
