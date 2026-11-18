import SwiftUI

struct ArtistDetailView: View {
    let artist: Artist

    var body: some View {
        let albums = artist.orderedAlbums

        List {
            if !albums.isEmpty {
                Section("Albums") {
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 16) {
                            ForEach(albums) { album in
                                NavigationLink(value: LibraryRoute.album(album)) {
                                    AlbumTile(album: album)
                                        .frame(width: 150)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .scrollIndicators(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
            }

            Section("Songs") {
                ForEach(artist.orderedSongs) { song in
                    SongRow(song: song)
                        .contextMenu { SongContextMenu(song: song) }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(artist.name)
    }
}
