import Foundation

/// What the queue was started from, shown as "Playing from …".
enum QueueSource: Codable, Sendable, Hashable {
    case songs
    case album(String)
    case artist(String)
    case playlist(String)
    case search
    case autoplay

    var title: String {
        switch self {
        case .songs: String(localized: "Songs")
        case .album(let name), .artist(let name), .playlist(let name): name
        case .search: String(localized: "Search")
        case .autoplay: String(localized: "Autoplay")
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
