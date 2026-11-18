import SwiftUI

struct HomeView: View {
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Nothing Played Yet",
                systemImage: "music.note",
                description: Text("Import songs in Library to get started.")
            )
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
    }
}
