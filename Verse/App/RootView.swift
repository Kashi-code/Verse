import SwiftUI

enum AppTab: Hashable {
    case home, library, search
}

struct RootView: View {
    @State private var selectedTab: AppTab = .home

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
            MiniPlayerBar()
        }
    }
}

#Preview {
    RootView()
        .environment(AppSettings())
        .modelContainer(for: LibrarySchema.models, inMemory: true)
}
