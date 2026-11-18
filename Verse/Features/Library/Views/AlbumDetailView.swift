import SwiftUI

struct AlbumDetailView: View {
    let album: Album

    @Environment(LibraryRouter.self) private var router: LibraryRouter?

    var body: some View {
        let tracks = album.orderedSongs

        List {
            header
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            Section {
                ForEach(tracks) { song in
                    AlbumTrackRow(song: song, showsArtist: song.artistName != album.artistName)
                        .contextMenu { SongContextMenu(song: song) }
                }
            } footer: {
                Text(summary(trackCount: tracks.count))
            }
        }
        .listStyle(.plain)
        .navigationTitle(album.title)
        .toolbarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ArtworkView(key: album.artworkKey, cornerRadius: 12)
                .frame(maxWidth: 260)
                .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                .padding(.bottom, 8)
            Text(album.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            if let artist = album.artist {
                Button(album.artistName) { router?.open(.artist(artist)) }
                    .font(.title3)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
            } else {
                Text(album.artistName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            if let year = album.year {
                Text(String(year))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func summary(trackCount: Int) -> String {
        String(localized: "\(trackCount) songs, \(TimeFormatting.total(album.totalDuration))")
    }
}
