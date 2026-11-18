import SwiftUI

/// The lyrics area of the fullscreen player.
struct LyricsPanel: View {
    @Environment(PlayerController.self) private var player
    @Environment(LyricsController.self) private var lyrics
    @Environment(AppSettings.self) private var settings

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                if case .loaded(let loaded, _) = lyrics.state, loaded.timing != .none {
                    LyricsOptionsMenu()
                }
            }
            .task(id: player.currentTrack?.id) {
                await lyrics.load(for: player.currentTrack)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch lyrics.state {
        case .idle, .loading:
            ProgressView()
        case .notFound:
            ContentUnavailableView {
                Label("No Lyrics", systemImage: "quote.bubble")
            } description: {
                if settings.lrclibEnabled {
                    Text("No lyrics for this song.")
                } else {
                    Text("Turn on Find Lyrics Online in Settings to look them up.")
                }
            }
        case .instrumental:
            ContentUnavailableView("Instrumental", systemImage: "music.note")
        case .previewOnly:
            ContentUnavailableView(
                "Lyrics Need the Full Song",
                systemImage: "quote.bubble",
                description: Text("Previews start partway through a song, so lyrics can’t follow along.")
            )
        case .loaded(let loaded, let source):
            if loaded.timing == .none {
                PlainLyricsView(lyrics: loaded, source: source)
            } else {
                SyncedLyricsView(lyrics: loaded, offset: lyrics.offset, source: source)
            }
        }
    }
}

/// Unsynced lyrics: scrollable text, no highlighting.
struct PlainLyricsView: View {
    let lyrics: Lyrics
    let source: LyricsSource

    @Environment(AppSettings.self) private var settings
    @ScaledMetric(relativeTo: .title) private var baseFontSize: CGFloat = 22

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(lyrics.lines.map(\.text).joined(separator: "\n"))
                    .font(.system(size: baseFontSize * settings.lyricsTextSize.scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .textSelection(.enabled)
                Group {
                    if source == .lrclib {
                        Text("Not synced · Lyrics from LRCLIB")
                    } else {
                        Text("Not synced")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
    }
}

/// Per-song timing and text size.
struct LyricsOptionsMenu: View {
    @Environment(LyricsController.self) private var lyrics
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Menu {
            Section {
                Button("Show Lyrics Earlier", systemImage: "backward") { lyrics.adjustOffset(by: 0.1) }
                    .menuActionDismissBehavior(.disabled)
                Button("Show Lyrics Later", systemImage: "forward") { lyrics.adjustOffset(by: -0.1) }
                    .menuActionDismissBehavior(.disabled)
                Button("Reset Timing", systemImage: "arrow.counterclockwise") { lyrics.resetOffset() }
                    .disabled(lyrics.offset == 0)
            } header: {
                Text("Timing \(offsetText)")
            }
            Picker("Text Size", selection: $settings.lyricsTextSize) {
                ForEach(LyricsTextSize.allCases) { size in
                    Text(size.title).tag(size)
                }
            }
            Toggle("Show Translations", isOn: $settings.showLyricsTranslations)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Lyrics Options")
    }

    private var offsetText: String {
        let value = lyrics.offset.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)))
        return "\(value) s"
    }
}
