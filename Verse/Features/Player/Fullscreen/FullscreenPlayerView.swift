import SwiftUI

/// The full-screen player. Opened from the mini player with a zoom transition; swipe down to close.
struct FullscreenPlayerView: View {
    @Environment(PlayerController.self) private var player
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var palette = CoverPalette.neutral
    @State private var showsLyrics = false
    @State private var showsQueue = false
    @Namespace private var coverSpace

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height * 1.15
            VStack(spacing: 0) {
                header
                if isWide {
                    wideLayout(size: proxy.size)
                } else {
                    tallLayout(size: proxy.size)
                }
            }
            .padding(.horizontal, isWide ? 32 : 24)
            .padding(.bottom, 8)
        }
        .tint(.white)
        .background { CoverMeshBackground(palette: palette).ignoresSafeArea() }
        .environment(\.colorScheme, .dark)
        .animation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.12), value: showsLyrics)
        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.2), value: player.isPlaying)
        .task(id: player.currentTrack?.artworkKey) { await loadPalette() }
        .sheet(isPresented: $showsQueue) { QueueSheet() }
        .onChange(of: player.currentTrack == nil) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }

    // MARK: Layouts

    @ViewBuilder
    private func tallLayout(size: CGSize) -> some View {
        if showsLyrics {
            HStack(spacing: 12) {
                cover(cornerRadius: 8)
                    .frame(width: 60, height: 60)
                trackTitles
                LikeButton()
            }
            .padding(.top, 8)
            LyricsPanel()
                .frame(maxHeight: .infinity)
        } else {
            Spacer(minLength: 12)
            cover(cornerRadius: 14)
                .frame(maxWidth: min(size.width - 48, size.height * 0.46))
                .scaleEffect(player.isPlaying ? 1 : 0.88)
            Spacer(minLength: 12)
            HStack(spacing: 12) {
                trackTitles
                LikeButton()
            }
        }
        controls
    }

    private func wideLayout(size: CGSize) -> some View {
        HStack(spacing: 32) {
            Group {
                if showsLyrics {
                    LyricsPanel()
                } else {
                    cover(cornerRadius: 14)
                        .scaleEffect(player.isPlaying ? 1 : 0.88)
                        .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    if showsLyrics {
                        cover(cornerRadius: 8)
                            .frame(width: 60, height: 60)
                    }
                    trackTitles
                    LikeButton()
                }
                controls
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 440)
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Button("Close", systemImage: "chevron.down") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
            Spacer()
            if let source = player.queue.source {
                VStack(spacing: 0) {
                    Text("Playing From")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(source.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    private func cover(cornerRadius: CGFloat) -> some View {
        ArtworkView(key: player.currentTrack?.artworkKey, cornerRadius: cornerRadius)
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .matchedGeometryEffect(id: "cover", in: coverSpace)
    }

    private var trackTitles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(player.currentTrack?.title ?? "")
                .font(.title3.bold())
                .lineLimit(1)
            Text(player.currentTrack?.artist ?? "")
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        VStack(spacing: 20) {
            PlaybackScrubber()
            TransportControls()
            PlayerBottomBar(showsLyrics: $showsLyrics, showsQueue: $showsQueue)
        }
        .padding(.top, 20)
    }

    private func loadPalette() async {
        let key = player.currentTrack?.artworkKey
        if let cached = CoverPaletteProvider.shared.cachedPalette(for: key) {
            palette = cached
        } else {
            palette = await CoverPaletteProvider.shared.palette(for: key)
        }
    }
}

struct LikeButton: View {
    @Environment(PlayerController.self) private var player
    @State private var taps = 0

    var body: some View {
        Button(
            player.isCurrentLiked ? LocalizedStringKey("Unlike") : LocalizedStringKey("Like"),
            systemImage: player.isCurrentLiked ? "heart.fill" : "heart"
        ) {
            player.toggleLike()
            taps += 1
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .frame(width: 44, height: 44)
        .contentTransition(.symbolEffect(.replace))
        .buttonStyle(.plain)
        .disabled(player.currentTrack?.source.localSongID == nil)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}
