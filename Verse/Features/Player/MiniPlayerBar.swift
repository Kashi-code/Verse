import SwiftUI

/// Sits above the tab bar. Opens the fullscreen player in milestone 4.
struct MiniPlayerBar: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        let track = player.currentTrack

        HStack(spacing: 12) {
            ArtworkView(key: track?.artworkKey, cornerRadius: 6)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 0) {
                Text(track?.title ?? String(localized: "Not Playing"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(track == nil ? .secondary : .primary)
                    .lineLimit(1)
                if let message = player.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else if let artist = track?.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(
                player.isPlaying ? LocalizedStringKey("Pause") : LocalizedStringKey("Play"),
                systemImage: player.isPlaying ? "pause.fill" : "play.fill"
            ) {
                player.togglePlayPause()
            }
            .contentTransition(.symbolEffect(.replace))
            .disabled(track == nil)

            Button("Next", systemImage: "forward.fill") {
                player.skipToNext()
            }
            .disabled(track == nil)
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}
