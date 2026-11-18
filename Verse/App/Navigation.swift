import SwiftUI

enum CatalogRoute: Hashable {
    case collection(CatalogCollection)
    case artist(CatalogArtist)
    case genre(String)
    case likedSongs
    case recentlyPlayed
    case saved
    case following

    /// The card the page zooms out of, when there is one.
    var zoomSourceID: CatalogID? {
        switch self {
        case .collection(let collection): collection.id
        case .artist(let artist): artist.id
        default: nil
        }
    }
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

/// Lets screens outside a tab's stack (the fullscreen player) open a page in the current tab.
@MainActor
@Observable
final class AppNavigator {
    var request: CatalogRoute?

    func open(_ route: CatalogRoute) {
        request = route
    }
}

extension View {
    func catalogDestinations() -> some View {
        navigationDestination(for: CatalogRoute.self) { route in
            RouteDestination(route: route)
        }
    }

    /// Marks this view as the card a page zooms out of.
    func zoomSource(_ id: CatalogID) -> some View {
        modifier(ZoomSource(id: id))
    }
}

private struct RouteDestination: View {
    let route: CatalogRoute

    @Environment(\.zoomNamespace) private var namespace

    var body: some View {
        if let id = route.zoomSourceID, let namespace {
            page.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            page
        }
    }

    @ViewBuilder
    private var page: some View {
        switch route {
        case .collection(let collection): CollectionDetailView(collection: collection)
        case .artist(let artist): ArtistDetailView(artist: artist)
        case .genre(let genre): GenreView(genre: genre)
        case .likedSongs: LikedSongsView()
        case .recentlyPlayed: RecentlyPlayedView()
        case .saved: SavedCollectionsView()
        case .following: FollowedArtistsView()
        }
    }
}

private struct ZoomSource: ViewModifier {
    let id: CatalogID

    @Environment(\.zoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

extension EnvironmentValues {
    @Entry var catalog: any CatalogService = MergedCatalog.sample()
    @Entry var zoomNamespace: Namespace.ID? = nil
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
