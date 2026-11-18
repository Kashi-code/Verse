import SwiftUI

enum AppTab: Hashable {
    case home, library, search
}

struct RootView: View {
    @State private var selectedTab: AppTab = .home
    @State private var isPlayerPresented = false
    @Namespace private var playerTransition

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView()
            }
            Tab("Library", systemImage: "square.stack", value: AppTab.library) {
                LibraryView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            MiniPlayerBar { isPlayerPresented = true }
                .matchedTransitionSource(id: "player", in: playerTransition)
        }
        .fullScreenCover(isPresented: $isPlayerPresented) {
            FullscreenPlayerView()
                .navigationTransition(.zoom(sourceID: "player", in: playerTransition))
        }
    }
}

#Preview {
    RootView()
        .environment(AppSettings())
        .environment(PlayerController(backend: LocalAudioEngine()))
        .modelContainer(for: LibrarySchema.models, inMemory: true)
}
