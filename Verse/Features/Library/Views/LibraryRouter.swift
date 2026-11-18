import SwiftUI

enum LibraryRoute: Hashable {
    case album(Album)
    case artist(Artist)
}

/// Navigation path for one tab, so context menus can open album and artist pages.
@MainActor
@Observable
final class LibraryRouter {
    var path = NavigationPath()

    func open(_ route: LibraryRoute) {
        path.append(route)
    }
}

extension View {
    func libraryDestinations() -> some View {
        navigationDestination(for: LibraryRoute.self) { route in
            switch route {
            case .album(let album): AlbumDetailView(album: album)
            case .artist(let artist): ArtistDetailView(artist: artist)
            }
        }
    }
}
