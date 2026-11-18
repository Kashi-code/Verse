import Foundation

/// Where a track's audio comes from.
enum TrackSource: Codable, Sendable, Hashable {
    case local(songID: UUID, fileName: String)
    case appleMusic(id: String)

    var localSongID: UUID? {
        if case .local(let songID, _) = self { songID } else { nil }
    }
}

/// A snapshot of what the player needs to know about a track. Independent of SwiftData so the
/// queue can be saved, restored and shared with Apple Music tracks.
struct TrackInfo: Codable, Sendable, Hashable {
    var source: TrackSource
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var artworkKey: String?
}

extension TrackInfo {
    init(_ song: Song) {
        self.init(
            source: .local(songID: song.id, fileName: song.fileName),
            title: song.title,
            artist: song.artistName,
            album: song.albumTitle,
            duration: song.duration,
            artworkKey: song.displayArtworkKey
        )
    }
}

/// What the queue was started from, shown as "Playing from …".
enum QueueSource: Codable, Sendable, Hashable {
    case songs
    case album(String)
    case artist(String)
    case playlist(String)
    case search

    var title: String {
        switch self {
        case .songs: String(localized: "Songs")
        case .album(let name), .artist(let name), .playlist(let name): name
        case .search: String(localized: "Search")
        }
    }
}

enum RepeatMode: String, Codable, Sendable, CaseIterable {
    case off, all, one

    var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}

struct QueueItem: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let track: TrackInfo

    init(track: TrackInfo, id: UUID = UUID()) {
        self.id = id
        self.track = track
    }
}
