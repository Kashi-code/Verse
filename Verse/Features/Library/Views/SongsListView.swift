import SwiftData
import SwiftUI

struct SongsListView: View {
    @Query private var songs: [Song]
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerController.self) private var player
    @State private var songPendingDeletion: Song?

    private let searchText: String
    private let onImport: () -> Void

    init(sort: SongSortOrder, searchText: String, onImport: @escaping () -> Void) {
        _songs = Query(filter: Song.matching(searchText), sort: sort.descriptors)
        self.searchText = searchText
        self.onImport = onImport
    }

    var body: some View {
        if songs.isEmpty {
            LibraryEmptyState(title: "No Songs", systemImage: "music.note", searchText: searchText, onImport: onImport)
        } else {
            List {
                Section {
                    PlayShuffleButtons { shuffled in
                        player.play(songs.map(TrackInfo.init), from: .songs, shuffled: shuffled)
                    }
                    .listRowSeparator(.hidden)
                }
                ForEach(songs.indices, id: \.self) { index in
                    let song = songs[index]
                    Button {
                        player.play(songs.map(TrackInfo.init), startingAt: index, from: .songs)
                    } label: {
                        SongRow(song: song)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            songPendingDeletion = song
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                            player.playNext([TrackInfo(song)])
                        }
                        .tint(.indigo)
                    }
                    .contextMenu {
                        SongContextMenu(song: song) { songPendingDeletion = song }
                    }
                }
            }
            .listStyle(.plain)
            .deleteSongConfirmation(song: $songPendingDeletion, context: modelContext)
        }
    }
}
