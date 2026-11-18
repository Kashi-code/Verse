import SwiftData
import SwiftUI

struct SongContextMenu: View {
    let song: Song
    var onDelete: (() -> Void)?

    @Environment(LibraryRouter.self) private var router: LibraryRouter?

    var body: some View {
        if song.isLiked {
            Button("Unlike", systemImage: "heart.slash") { song.isLiked = false }
        } else {
            Button("Like", systemImage: "heart") { song.isLiked = true }
        }
        if let album = song.album {
            Button("Go to Album", systemImage: "square.stack") { router?.open(.album(album)) }
        }
        if let artist = song.artist {
            Button("Go to Artist", systemImage: "music.microphone") { router?.open(.artist(artist)) }
        }
        if let onDelete {
            Divider()
            Button("Delete from Library", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

extension View {
    /// Asks before deleting a song and its imported file.
    func deleteSongConfirmation(song: Binding<Song?>, context: ModelContext) -> some View {
        confirmationDialog(
            "Delete Song?",
            isPresented: Binding(get: { song.wrappedValue != nil }, set: { if !$0 { song.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: song.wrappedValue
        ) { pending in
            Button("Delete from Library", role: .destructive) {
                try? LibraryCatalog(context: context).delete([pending])
            }
        } message: { _ in
            Text("The imported file will be removed from this iPhone.")
        }
    }
}
