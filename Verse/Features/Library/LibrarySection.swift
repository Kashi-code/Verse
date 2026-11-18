import Foundation

enum LibrarySection: String, CaseIterable, Identifiable, Sendable {
    case songs, albums, artists, playlists

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .songs: "Songs"
        case .albums: "Albums"
        case .artists: "Artists"
        case .playlists: "Playlists"
        }
    }
}
