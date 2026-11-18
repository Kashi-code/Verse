import SwiftData
import SwiftUI

struct AlbumsCollectionView: View {
    @Query private var albums: [Album]

    private let layout: CollectionLayout
    private let searchText: String
    private let onImport: () -> Void

    init(sort: AlbumSortOrder, layout: CollectionLayout, searchText: String, onImport: @escaping () -> Void) {
        _albums = Query(filter: Album.matching(searchText), sort: sort.descriptors)
        self.layout = layout
        self.searchText = searchText
        self.onImport = onImport
    }

    var body: some View {
        if albums.isEmpty {
            LibraryEmptyState(title: "No Albums", systemImage: "square.stack", searchText: searchText, onImport: onImport)
        } else {
            switch layout {
            case .grid:
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 20) {
                        ForEach(albums) { album in
                            NavigationLink(value: LibraryRoute.album(album)) {
                                AlbumTile(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            case .list:
                List(albums) { album in
                    NavigationLink(value: LibraryRoute.album(album)) {
                        AlbumRow(album: album)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct AlbumTile: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ArtworkView(key: album.artworkKey, cornerRadius: 10)
            Text(album.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text(album.artistName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AlbumRow: View {
    let album: Album

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(key: album.artworkKey, cornerRadius: 6)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .lineLimit(1)
                Text(album.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
