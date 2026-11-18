import SwiftData
import SwiftUI

@main
struct VerseApp: App {
    @State private var settings = AppSettings()
    @State private var player: PlayerController
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

        let player = PlayerController.live()
        player.library = PlaybackLibraryBridge(context: container.mainContext)
        _player = State(initialValue: player)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(player)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .modelContainer(container)
    }
}
