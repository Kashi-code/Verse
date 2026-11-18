import SwiftUI

/// Empty state shared by the library sections: a search "no results" view, or an invitation to import.
struct LibraryEmptyState: View {
    let title: LocalizedStringKey
    let systemImage: String
    let searchText: String
    let onImport: () -> Void

    var body: some View {
        if searchText.isEmpty {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                Text("Import audio files from the Files app. Add a .lrc file with the same name to include lyrics.")
            } actions: {
                Button("Import Music", action: onImport)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}
