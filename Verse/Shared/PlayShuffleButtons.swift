import SwiftUI

/// The Play / Shuffle pair used at the top of song lists and album, artist and playlist pages.
struct PlayShuffleButtons: View {
    let action: (_ shuffled: Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                action(false)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            Button {
                action(true)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .font(.headline)
    }
}
