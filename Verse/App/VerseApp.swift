import SwiftData
import SwiftUI

@main
struct VerseApp: App {
    @State private var settings = AppSettings()

    init() {
        // SwiftData's default store lives here; create it so Core Data doesn't log a missing-folder error.
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .modelContainer(for: LibrarySchema.models)
    }
}
