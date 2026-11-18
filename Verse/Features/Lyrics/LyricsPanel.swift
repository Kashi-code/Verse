import SwiftUI

/// The lyrics area of the fullscreen player. Synced lyrics arrive in milestone 5.
struct LyricsPanel: View {
    var body: some View {
        ContentUnavailableView(
            "No Lyrics",
            systemImage: "quote.bubble",
            description: Text("Synced lyrics will appear here.")
        )
    }
}
