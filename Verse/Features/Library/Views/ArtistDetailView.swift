import SwiftUI

struct ArtistDetailView: View {
    let artist: Artist

    @Environment(PlayerController.self) private var player

    var body: some View {
        let albums = artist.orderedAlbums
        let songs = artist.orderedSongs

        List {
            Section {
                PlayShuffleButtons { shuffled in
                    play(songs, startingAt: nil, shuffled: shuffled)
                }
                .listRowSeparator(.hidden)
            }

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
                ForEach(songs.indices, id: \.self) { index in
                    let song = songs[index]
                    Button {
                        play(songs, startingAt: index)
                    } label: {
                        SongRow(song: song)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { SongContextMenu(song: song) }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(artist.name)
    }

    private func play(_ songs: [Song], startingAt index: Int?, shuffled: Bool = false) {
        player.play(songs.map(TrackInfo.init), startingAt: index, from: .artist(artist.name), shuffled: shuffled)
    }
}
