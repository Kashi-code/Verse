import SwiftUI

/// Sits above the tab bar. Tapping the song opens the fullscreen player.
struct MiniPlayerBar: View {
    var onOpen: () -> Void = {}

    @Environment(PlayerController.self) private var player
    @State private var palette = CoverPalette.neutral

    var body: some View {
        bar
            .background {
                // The bar takes on a hint of the cover colour.
                Color(palette.accent).opacity(player.currentTrack == nil ? 0 : 0.22)
                    .animation(DS.Motion.smooth, value: palette)
            }
            .overlay(alignment: .bottom) {
                if player.currentTrack != nil {
                    ProgressLine(tint: Color(palette.colors[1]).opacity(0.9))
                        .padding(.horizontal, DS.Spacing.l)
                }
            }
            .task(id: player.currentTrack?.artworkURL) {
                palette = await CoverPaletteProvider.shared.palette(for: player.currentTrack?.artworkURL)
            }
    }

    @ViewBuilder
    private var bar: some View {
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

/// A thin line showing how far the song has played.
private struct ProgressLine: View {
    let tint: Color

    @Environment(PlayerController.self) private var player

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: !player.isPlaying)) { _ in
            let progress = player.duration > 0 ? min(max(player.currentTime / player.duration, 0), 1) : 0
            GeometryReader { proxy in
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * progress)
            }
            .frame(height: 2)
        }
        .accessibilityHidden(true)
    }
}
