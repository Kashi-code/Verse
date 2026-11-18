import SwiftData
import SwiftUI

struct SongsListView: View {
    @Query private var songs: [Song]
    @Environment(\.modelContext) private var modelContext
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
            List(songs) { song in
                SongRow(song: song)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            songPendingDeletion = song
                        }
                    }
                    .contextMenu {
                        SongContextMenu(song: song) { songPendingDeletion = song }
                    }
            }
            .listStyle(.plain)
            .deleteSongConfirmation(song: $songPendingDeletion, context: modelContext)
        }
    }
}
