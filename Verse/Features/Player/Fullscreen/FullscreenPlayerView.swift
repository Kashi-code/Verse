import SwiftUI

/// The full-screen player. Opened from the mini player with a zoom transition; swipe down to close.
struct FullscreenPlayerView: View {
    @Environment(PlayerController.self) private var player
    @Environment(AppNavigator.self) private var navigator: AppNavigator?
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
        .task(id: player.currentTrack?.artworkURL) { await loadPalette() }
        .sheet(isPresented: $showsQueue) { QueueSheet() }
        .playlistPickerHost()
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
            PlayerMoreMenu()
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    private func cover(cornerRadius: CGFloat) -> some View {
        ArtworkView(url: player.currentTrack?.artworkURL, cornerRadius: cornerRadius, size: 360)
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .matchedGeometryEffect(id: "cover", in: coverSpace)
    }

    private var trackTitles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(player.currentTrack?.title ?? "")
                .font(.title3.bold())
                .lineLimit(1)
            if let artist = player.currentTrack?.artistReference, let navigator {
                Button(artist.name) { navigator.open(.artist(artist)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityHint("Opens the artist")
            } else {
                Text(player.currentTrack?.artist ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let track = player.currentTrack, track.isPreview {
                HStack(spacing: 6) {
                    Text("Preview")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.18)))
                    if let url = track.externalURL {
                        Link("Listen on Apple Music", destination: url)
                            .font(.caption.weight(.semibold))
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        VStack(spacing: 20) {
            PlaybackScrubber()
            TransportControls()
            VolumeSlider()
                .frame(height: 34)
            PlayerBottomBar(showsLyrics: $showsLyrics, showsQueue: $showsQueue)
        }
        .padding(.top, 20)
    }

    private func loadPalette() async {
        let key = player.currentTrack?.artworkURL
        if let cached = CoverPaletteProvider.shared.cachedPalette(for: key) {
            palette = cached
        } else {
            palette = await CoverPaletteProvider.shared.palette(for: key)
        }
    }
}

/// Add to playlist, similar songs, album and share for the current song.
private struct PlayerMoreMenu: View {
    @Environment(PlayerController.self) private var player
    @Environment(AppNavigator.self) private var navigator: AppNavigator?
    @Environment(PlaylistPicker.self) private var playlistPicker: PlaylistPicker?
    @State private var similarTaps = 0

    var body: some View {
        Menu {
            if let track = player.currentTrack {
                if let playlistPicker {
                    Button("Add to Playlist…", systemImage: "text.badge.plus") { playlistPicker.present([track]) }
                }
                Button("Play Similar Songs", systemImage: "sparkles") {
                    similarTaps += 1
                    Task { await player.playSimilarSongs() }
                }
                if let album = track.albumReference, let navigator {
                    Button("Go to Album", systemImage: "square.stack") { navigator.open(.collection(album)) }
                }
                if let url = track.externalURL {
                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .disabled(player.currentTrack == nil)
        .sensoryFeedback(.impact(weight: .light), trigger: similarTaps)
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
        .symbolEffect(.bounce, value: taps)
        .buttonStyle(.plain)
        .disabled(player.currentTrack == nil)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}
