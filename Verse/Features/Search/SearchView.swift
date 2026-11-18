import SwiftUI

struct SearchView: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ContentUnavailableView(
                        "Search Your Music",
                        systemImage: "magnifyingglass",
                        description: Text("Find songs, albums, artists and playlists.")
                    )
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: Text("Songs, albums, artists"))
        }
    }
}
