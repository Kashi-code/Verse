import AppIntents
import SwiftData
import SwiftUI

@main
struct VerseApp: App {
    @State private var settings: AppSettings
    @State private var player: PlayerController
    @State private var lyrics: LyricsController
    @State private var network = NetworkMonitor()
    private let container: ModelContainer
    private let catalog: any CatalogService
    private let stateStore: PlaybackStateStore?

    /// `-sampleData` runs the app on bundled sample responses with nothing saved (screenshots, UI tests).
    static let usesSampleData = ProcessInfo.processInfo.arguments.contains("-sampleData")

    init() {
        // SwiftData's default store lives here; create it so Core Data doesn't log a missing-folder error.
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)

        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: Schema(LibrarySchema.models),
                configurations: ModelConfiguration(isStoredInMemoryOnly: Self.usesSampleData)
            )
        } catch {
            fatalError("Couldn't open the library database: \(error)")
        }
        self.container = container
        let library = UserLibrary(context: container.mainContext)
        let catalog: any CatalogService = Self.usesSampleData ? MergedCatalog.sample() : MergedCatalog.live()
        self.catalog = catalog
        stateStore = Self.usesSampleData ? nil : PlaybackStateStore.shared

        let settings = AppSettings()
        _settings = State(initialValue: settings)

        let player = PlayerController.live()
        player.library = library
        player.catalog = catalog
        player.autoplayEnabled = settings.autoplay
        if settings.launchBehavior == .resume, let saved = stateStore?.load() {
            player.restore(saved.queue, position: saved.position)
        }
        _player = State(initialValue: player)
        // Siri and Shortcuts actions reach the same player and library.
        AppDependencyManager.shared.add(dependency: player)
        AppDependencyManager.shared.add(dependency: container)

        let lyrics = LyricsController(provider: .live(), settings: settings)
        lyrics.library = library
        _lyrics = State(initialValue: lyrics)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(player)
                .environment(lyrics)
                .environment(network)
                .environment(\.catalog, catalog)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onChange(of: settings.lrclibEnabled) {
                    lyrics.forgetLoadedLyrics()
                }
                .onChange(of: settings.autoplay) { _, enabled in
                    player.autoplayEnabled = enabled
                }
                .task {
                    network.onReconnect = { player.retryAfterReconnect() }
                    network.start()
                    player.onStateChange = { saveState() }
                    await seedSampleLibrary()
                }
        }
        .modelContainer(container)
    }

    /// Sample mode only: a playlist, a saved playlist and some plays, so every screen has content.
    private func seedSampleLibrary() async {
        guard Self.usesSampleData, let feed = try? await catalog.homeFeed() else { return }
        let library = UserLibrary(context: container.mainContext)
        guard library.playlists().isEmpty else { return }
        let songs = feed.trending + feed.topSongs + feed.genres.flatMap(\.tracks)
        library.createPlaylist(named: "Late Night Drive", with: Array(songs.prefix(8)))
        let plays = Array(songs.prefix(6)) + Array(songs.prefix(3))
        for (offset, track) in plays.enumerated() {
            library.recordPlay(of: track, at: .now.addingTimeInterval(-Double(offset) * 60))
        }
        if let collection = feed.playlists.first {
            library.toggleSaved(collection)
        }
    }

    private func saveState() {
        guard let stateStore, let saved = player.savedState else { return }
        stateStore.save(saved)
    }
}
