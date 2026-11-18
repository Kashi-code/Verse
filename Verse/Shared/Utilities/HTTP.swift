import Foundation

protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
    var session: URLSession = .shared

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

enum HTTPError: Error, Equatable {
    case badStatus(Int)
}

extension HTTPClient {
    /// GETs `url` and decodes the JSON body. Returns nil for 404.
    func getJSON<T: Decodable>(_ type: T.Type, from url: URL, headers: [String: String] = [:]) async throws -> T? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        let (data, response) = try await data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300:
            return try JSONDecoder.catalog.decode(T.self, from: data)
        case 404:
            return nil
        default:
            throw HTTPError.badStatus(status)
        }
    }
}

extension JSONDecoder {
    static var catalog: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

/// Decodes an array, skipping elements that fail instead of failing the whole response.
struct LossyArray<Element: Decodable & Sendable>: Decodable, Sendable {
    let values: [Element]

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [Element] = []
        while !container.isAtEnd {
            if let value = try? container.decode(Element.self) {
                values.append(value)
            } else {
                _ = try? container.decode(Skip.self)
            }
        }
        self.values = values
    }

    private struct Skip: Decodable {
        init(from decoder: any Decoder) throws {}
    }
}

extension URL {
    /// Adds query items, encoding "+" so servers don't read it as a space.
    func appendingQuery(_ items: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.queryItems = (components.queryItems ?? []) + items
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url ?? self
    }
}
