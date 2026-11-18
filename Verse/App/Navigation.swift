import SwiftUI

enum CatalogRoute: Hashable {
    case collection(CatalogCollection)
    case artist(CatalogArtist)
    case genre(String)
    case likedSongs
    case recentlyPlayed
}

/// Navigation path for one tab, so rows and menus can open pages.
@MainActor
@Observable
final class Router {
    var path = NavigationPath()

    func open(_ route: CatalogRoute) {
        path.append(route)
    }
}

extension View {
    func catalogDestinations() -> some View {
        navigationDestination(for: CatalogRoute.self) { route in
            switch route {
            case .collection(let collection): CollectionDetailView(collection: collection)
            case .artist(let artist): ArtistDetailView(artist: artist)
            case .genre(let genre): GenreView(genre: genre)
            case .likedSongs: LikedSongsView()
            case .recentlyPlayed: RecentlyPlayedView()
            }
        }
    }
}

extension EnvironmentValues {
    @Entry var catalog: any CatalogService = MergedCatalog.sample()
}

extension TrackInfo {
    /// A minimal artist value to open the artist page from a song.
    var artistReference: CatalogArtist? {
        artistID.map { CatalogArtist(id: $0, name: artist, imageURL: nil) }
    }

    var albumReference: CatalogCollection? {
        guard let albumID, let album else { return nil }
        return CatalogCollection(id: albumID, kind: .album, title: album, subtitle: artist, artworkURL: artworkURL, ownerID: artistID)
    }
}
