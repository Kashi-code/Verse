import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case home, library, search
}

struct RootView: View {
    @Environment(PlayerController.self) private var player
    @Environment(NetworkMonitor.self) private var network
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: AppTab = .home
    @State private var isPlayerPresented = false
    @State private var navigator = AppNavigator()
    @State private var homeRouter = Router()
    @State private var libraryRouter = Router()
    @State private var searchRouter = Router()
    @Namespace private var playerTransition
    @Namespace private var cardTransition

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(router: homeRouter)
            }
            Tab("Library", systemImage: "square.stack.fill", value: AppTab.library) {
                LibraryView(router: libraryRouter)
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                SearchView(router: searchRouter)
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
        .overlay(alignment: .top) {
            if !network.isOnline {
                OfflineBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .playlistPickerHost()
        .environment(navigator)
        .environment(\.zoomNamespace, cardTransition)
        .animation(DS.Motion.smooth, value: network.isOnline)
        .onChange(of: navigator.request) { _, route in
            guard let route else { return }
            navigator.request = nil
            isPlayerPresented = false
            currentRouter.open(route)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { player.onStateChange?() }
        }
    }

    private var currentRouter: Router {
        switch selectedTab {
        case .home: homeRouter
        case .library: libraryRouter
        case .search: searchRouter
        }
    }
}

private struct OfflineBanner: View {
    var body: some View {
        Label("You're offline", systemImage: "wifi.slash")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.xs)
            .glassSurface(cornerRadius: 20)
            .padding(.top, DS.Spacing.xs)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
