import SwiftData
import SwiftUI

@main
struct VerseApp: App {
    @State private var settings: AppSettings
    @State private var player: PlayerController
    @State private var lyrics: LyricsController
    private let container: ModelContainer

    init() {
        // SwiftData's default store lives here; create it so Core Data doesn't log a missing-folder error.
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: Schema(LibrarySchema.models), configurations: ModelConfiguration())
        } catch {
            fatalError("Couldn't open the library database: \(error)")
        }
        self.container = container
        let library = PlaybackLibraryBridge(context: container.mainContext)

        let settings = AppSettings()
        _settings = State(initialValue: settings)

        let player = PlayerController.live()
        player.library = library
        _player = State(initialValue: player)

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
                .preferredColorScheme(settings.appearance.colorScheme)
                .onChange(of: settings.lrclibEnabled) {
                    lyrics.forgetLoadedLyrics()
                }
        }
        .modelContainer(container)
    }
}
