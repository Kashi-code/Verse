import SwiftUI

struct LibraryView: View {
    @State private var section: LibrarySection = .songs

    var body: some View {
        NavigationStack {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .top) {
                    Picker("Library Section", selection: $section) {
                        ForEach(LibrarySection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                .navigationTitle("Library")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch section {
        case .songs:
            ContentUnavailableView("No Songs", systemImage: "music.note",
                                   description: Text("Imported songs will appear here."))
        case .albums:
            ContentUnavailableView("No Albums", systemImage: "square.stack",
                                   description: Text("Albums from your songs will appear here."))
        case .artists:
            ContentUnavailableView("No Artists", systemImage: "music.microphone",
                                   description: Text("Artists from your songs will appear here."))
        case .playlists:
            ContentUnavailableView("No Playlists", systemImage: "music.note.list",
                                   description: Text("Playlists you create will appear here."))
        }
    }
}
