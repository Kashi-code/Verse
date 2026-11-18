import Foundation

/// Merges results from several catalogs into one ranked list.
enum SearchRanking {
    /// 3 = exact match, 2 = starts with the query, 1 = a word starts with it or contains it, 0 = no match.
    static func matchScore(_ text: String, query: String) -> Int {
        let text = normalized(text)
        let query = normalized(query)
        guard !query.isEmpty, !text.isEmpty else { return 0 }
        if text == query { return 3 }
        if text.hasPrefix(query) { return 2 }
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if words.contains(where: { $0.hasPrefix(query) }) || text.contains(query) { return 1 }
        return 0
    }

    /// Interleaves lists (first list wins ties), then sorts by match score, keeping that order
    /// among equal scores. Duplicates (same title and artist) keep their first appearance.
    static func mergeTracks(_ lists: [[TrackInfo]], query: String, limit: Int = 30) -> [TrackInfo] {
        let interleaved = interleave(lists)
        var seen = Set<String>()
        let unique = interleaved.filter { track in
            seen.insert(normalized(track.title) + "|" + normalized(track.artist)).inserted
        }
        let scored = unique.enumerated().map { (index: $0.offset, track: $0.element, score: trackScore($0.element, query: query)) }
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
            .prefix(limit)
            .map(\.track)
    }

    static func mergeArtists(_ lists: [[CatalogArtist]], query: String, limit: Int = 12) -> [CatalogArtist] {
        let scored = interleave(lists).enumerated().map { (index: $0.offset, artist: $0.element, score: matchScore($0.element.name, query: query)) }
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
            .prefix(limit)
            .map(\.artist)
    }

    static func mergeCollections(_ lists: [[CatalogCollection]], query: String, limit: Int = 12) -> [CatalogCollection] {
        let scored = interleave(lists).enumerated().map { (index: $0.offset, collection: $0.element, score: matchScore($0.element.title, query: query)) }
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
            .prefix(limit)
            .map(\.collection)
    }

    /// An artist whose name matches exactly beats everything; then the best song.
    static func topResult(songs: [TrackInfo], artists: [CatalogArtist], collections: [CatalogCollection], query: String) -> SearchTopResult? {
        if let artist = artists.first(where: { matchScore($0.name, query: query) == 3 }) {
            return .artist(artist)
        }
        if let song = songs.first, trackScore(song, query: query) >= 2 {
            return .track(song)
        }
        if let collection = collections.first(where: { matchScore($0.title, query: query) == 3 }) {
            return .collection(collection)
        }
        if let song = songs.first { return .track(song) }
        if let artist = artists.first { return .artist(artist) }
        return collections.first.map { .collection($0) }
    }

    /// Title match counts most; a matching artist name helps a little.
    static func trackScore(_ track: TrackInfo, query: String) -> Int {
        max(matchScore(track.title, query: query), matchScore(track.artist, query: query) > 0 ? 1 : 0)
    }

    static func interleave<T>(_ lists: [[T]]) -> [T] {
        var result: [T] = []
        let longest = lists.map(\.count).max() ?? 0
        for index in 0..<longest {
            for list in lists where index < list.count {
                result.append(list[index])
            }
        }
        return result
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
