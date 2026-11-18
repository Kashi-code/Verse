import Foundation

/// A "Made for You" playlist built on the device from what the user played. Nothing is sent anywhere
/// except the catalog requests that fill it.
struct Mix: Hashable, Identifiable, Sendable {
    enum Kind: Hashable, Sendable {
        /// Songs played again and again.
        case onRepeat
        /// Favourites in one genre plus what's trending in it.
        case genre(String)
        /// Songs similar to recent plays that the user hasn't heard.
        case discover
    }

    var kind: Kind
    /// Songs from the user's history the mix starts from.
    var seeds: [TrackInfo]

    var id: String {
        switch kind {
        case .onRepeat: "on-repeat"
        case .genre(let genre): "genre-\(genre)"
        case .discover: "discover"
        }
    }

    var title: String {
        switch kind {
        case .onRepeat: String(localized: "On Repeat")
        case .genre(let genre): String(localized: "\(genre) Mix")
        case .discover: String(localized: "Discover")
        }
    }

    var subtitle: String {
        switch kind {
        case .onRepeat: String(localized: "The songs you keep coming back to")
        case .genre: String(localized: "Your favourites and what's new")
        case .discover: String(localized: "New songs based on what you play")
        }
    }

    var coverURLs: [URL] { Playlist.mosaicURLs(from: seeds) }
}

enum MixBuilder {
    /// `history` is every play, most recent first, with repeats.
    static func mixes(from history: [TrackInfo]) -> [Mix] {
        guard !history.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        var unique: [TrackInfo] = []
        for track in history {
            counts[track.id.key, default: 0] += 1
            if counts[track.id.key] == 1 { unique.append(track) }
        }

        var mixes: [Mix] = []

        // Stable sort keeps recency as the tie-breaker.
        let repeated = unique
            .enumerated()
            .filter { counts[$0.element.id.key, default: 0] >= 2 }
            .sorted { lhs, rhs in
                let left = counts[lhs.element.id.key, default: 0]
                let right = counts[rhs.element.id.key, default: 0]
                return left != right ? left > right : lhs.offset < rhs.offset
            }
            .map(\.element)
        if repeated.count >= 3 {
            mixes.append(Mix(kind: .onRepeat, seeds: Array(repeated.prefix(30))))
        }

        if unique.count >= 3 {
            mixes.append(Mix(kind: .discover, seeds: Array(unique.prefix(5))))
        }

        var genrePlays: [String: Int] = [:]
        var genreOrder: [String] = []
        for track in history {
            guard let genre = track.genre?.trimmingCharacters(in: .whitespaces), !genre.isEmpty else { continue }
            if genrePlays[genre] == nil { genreOrder.append(genre) }
            genrePlays[genre, default: 0] += 1
        }
        let topGenres = genreOrder
            .filter { genrePlays[$0, default: 0] >= 3 }
            .sorted { genrePlays[$0, default: 0] > genrePlays[$1, default: 0] }
            .prefix(3)
        for genre in topGenres {
            let seeds = unique.filter { $0.genre?.trimmingCharacters(in: .whitespaces) == genre }
            mixes.append(Mix(kind: .genre(genre), seeds: Array(seeds.prefix(15))))
        }

        return mixes
    }

    /// The songs to play for a mix. Falls back to the seeds when the catalog has nothing.
    static func tracks(for mix: Mix, catalog: any CatalogService) async -> [TrackInfo] {
        switch mix.kind {
        case .onRepeat:
            return mix.seeds
        case .genre:
            // Similar songs come from the seed's genre, mapped to one the catalog knows.
            guard let seed = mix.seeds.first else { return [] }
            let fresh = (try? await catalog.similarTracks(to: seed)) ?? []
            return Array(dedupe(SearchRanking.interleave([mix.seeds, fresh])).prefix(50))
        case .discover:
            let heard = Set(mix.seeds.map(\.id))
            let seeds = Array(mix.seeds.prefix(3))
            let batches = await withTaskGroup(of: (Int, [TrackInfo]).self) { group in
                for (index, seed) in seeds.enumerated() {
                    group.addTask { (index, (try? await catalog.similarTracks(to: seed)) ?? []) }
                }
                var results = Array(repeating: [TrackInfo](), count: seeds.count)
                for await (index, tracks) in group {
                    results[index] = tracks
                }
                return results
            }
            let fresh = dedupe(SearchRanking.interleave(batches)).filter { !heard.contains($0.id) }
            return fresh.isEmpty ? mix.seeds : Array(fresh.prefix(50))
        }
    }

    private static func dedupe(_ tracks: [TrackInfo]) -> [TrackInfo] {
        var seen = Set<CatalogID>()
        return tracks.filter { seen.insert($0.id).inserted }
    }
}
