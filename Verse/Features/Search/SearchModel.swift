import Foundation
import Observation

@MainActor
@Observable
final class SearchModel {
    var query = ""
    private(set) var results: SearchResults?
    private(set) var isSearching = false
    private(set) var failed = false
    private(set) var recentSearches: [String]

    @ObservationIgnored private let defaults: UserDefaults
    private static let recentKey = "search.recent"
    static let maxRecent = 10

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recentSearches = defaults.stringArray(forKey: Self.recentKey) ?? []
    }

    /// Debounced: waits a moment so typing doesn't fire a request per letter.
    func search(using catalog: any CatalogService) async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            results = nil
            isSearching = false
            return
        }
        isSearching = true
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        do {
            let found = try await catalog.search(text)
            guard !Task.isCancelled else { return }
            results = found
            failed = false
        } catch {
            guard !Task.isCancelled else { return }
            failed = true
        }
        isSearching = false
    }

    func rememberQuery() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(text) == .orderedSame }
        recentSearches.insert(text, at: 0)
        recentSearches = Array(recentSearches.prefix(Self.maxRecent))
        defaults.set(recentSearches, forKey: Self.recentKey)
    }

    func clearRecentSearches() {
        recentSearches = []
        defaults.removeObject(forKey: Self.recentKey)
    }
}

/// Genres offered as tiles on the empty search screen (Audius genre names).
enum BrowseGenre {
    static let all = ["Electronic", "Hip-Hop/Rap", "Pop", "Rock", "Lo-Fi", "R&B/Soul", "House", "Alternative",
                      "Ambient", "Techno", "Drum & Bass", "Jazz", "Latin", "Folk", "Classical", "Metal"]

    /// Two calm colours per genre, derived from its name so they stay stable.
    static func colors(for genre: String) -> (RGBColor, RGBColor) {
        let hash = genre.unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        let hue = Double(hash % 360) / 360
        return (RGBColor(hue: hue, saturation: 0.6, brightness: 0.62),
                RGBColor(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.38))
    }
}
