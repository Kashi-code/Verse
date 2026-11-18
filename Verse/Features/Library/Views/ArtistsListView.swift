import SwiftData
import SwiftUI

struct ArtistsListView: View {
    @Query private var artists: [Artist]

    private let searchText: String
    private let onImport: () -> Void

    init(searchText: String, onImport: @escaping () -> Void) {
        _artists = Query(
            filter: Artist.matching(searchText),
            sort: [SortDescriptor(\Artist.name, comparator: .localizedStandard)]
        )
        self.searchText = searchText
        self.onImport = onImport
    }

    var body: some View {
        // Album artists can exist without songs of their own; only list artists with songs.
        let visibleArtists = artists.filter { !$0.songs.isEmpty }
        if visibleArtists.isEmpty {
            LibraryEmptyState(title: "No Artists", systemImage: "music.microphone", searchText: searchText, onImport: onImport)
        } else {
            List(visibleArtists) { artist in
                NavigationLink(value: LibraryRoute.artist(artist)) {
                    ArtistRow(artist: artist)
                }
            }
            .listStyle(.plain)
        }
    }
}

struct ArtistRow: View {
    let artist: Artist

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(key: artist.artworkKey, cornerRadius: 28)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name)
                    .lineLimit(1)
                Text("\(artist.songs.count) songs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
