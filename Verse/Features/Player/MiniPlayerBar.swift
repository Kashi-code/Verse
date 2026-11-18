import SwiftUI

/// Sits above the tab bar. Tapping the song opens the fullscreen player.
struct MiniPlayerBar: View {
    var onOpen: () -> Void = {}

    @Environment(PlayerController.self) private var player

    var body: some View {
        let track = player.currentTrack

        HStack(spacing: 12) {
            Button {
                if track != nil { onOpen() }
            } label: {
                HStack(spacing: 12) {
                    ArtworkView(url: track?.thumbnailURL ?? track?.artworkURL, cornerRadius: DS.Radius.control, size: DS.Size.miniPlayerArtwork)
                        .frame(width: 36, height: 36)
                    titles(for: track)
                }
                .contentShape(.rect)
            }
            .accessibilityHint(track == nil ? Text("") : Text("Opens the player"))
            .accessibilityIdentifier("mini-player")

            Button(
                player.isPlaying ? LocalizedStringKey("Pause") : LocalizedStringKey("Play"),
                systemImage: player.isPlaying ? "pause.fill" : "play.fill"
            ) {
                player.togglePlayPause()
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .contentTransition(.symbolEffect(.replace))
            .disabled(track == nil)

            Button("Next", systemImage: "forward.fill") {
                player.skipToNext()
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .disabled(track == nil)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private func titles(for track: TrackInfo?) -> some View {
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
    }
}
