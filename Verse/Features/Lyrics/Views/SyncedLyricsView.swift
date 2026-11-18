import SwiftUI

/// Lyrics that follow the song. The active line sits about a third from the top; tap a line to
/// jump to it; scrolling by hand pauses auto-follow for 3 seconds.
///
/// Only one tiny `TimelineView` tracks the active row; the active line has its own for the word
/// fill. Past and upcoming lines don't redraw per frame.
struct SyncedLyricsView: View {
    let lyrics: Lyrics
    let offset: Double
    let source: LyricsSource

    @Environment(PlayerController.self) private var player
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var baseFontSize: CGFloat = 30

    @State private var activeIndex: Int?
    @State private var isFollowing = true
    @State private var resumeFollowTask: Task<Void, Never>?
    @State private var seekCount = 0

    private let items: [LyricsItem]
    private let timeline: LyricsTimeline

    init(lyrics: Lyrics, offset: Double, source: LyricsSource) {
        self.lyrics = lyrics
        self.offset = offset
        self.source = source
        let items = LyricsLayout.items(for: lyrics)
        self.items = items
        self.timeline = LyricsTimeline(items: items)
    }

    private var fontSize: CGFloat { baseFontSize * settings.lyricsTextSize.scale }
    private var tickInterval: Double? { player.isPlaying ? nil : 0.25 }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: fontSize * 0.75) {
                        Color.clear.frame(height: geometry.size.height * 0.25)
                        ForEach(items) { item in
                            row(for: item)
                                .id(item.id)
                        }
                        if source == .lrclib {
                            Text("Lyrics from LRCLIB")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 24)
                        }
                        Color.clear.frame(height: geometry.size.height * 0.6)
                    }
                    .padding(.horizontal, 4)
                }
                .scrollIndicators(.hidden)
                .onScrollPhaseChange { _, phase in
                    handleScrollPhase(phase, proxy: proxy)
                }
                .onChange(of: activeIndex) { _, index in
                    guard isFollowing, let index else { return }
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.1)) {
                        proxy.scrollTo(index, anchor: UnitPoint(x: 0, y: 0.3))
                    }
                }
                .onAppear {
                    if let activeIndex { proxy.scrollTo(activeIndex, anchor: UnitPoint(x: 0, y: 0.3)) }
                }
            }
        }
        .background { activeRowTracker }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.08),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.15), value: activeIndex)
        .sensoryFeedback(.selection, trigger: seekCount)
    }

    /// Cheap per-frame check that only writes state when the active row changes.
    private var activeRowTracker: some View {
        TimelineView(.animation(minimumInterval: player.isPlaying ? 1.0 / 30 : 0.25)) { _ in
            let index = timeline.activeIndex(at: player.currentTime + offset)
            Color.clear
                .onChange(of: index, initial: true) { _, newIndex in
                    activeIndex = newIndex
                }
        }
    }

    @ViewBuilder
    private func row(for item: LyricsItem) -> some View {
        switch item.kind {
        case .line(let line):
            let lineEmphasis = emphasis(for: item.id)
            Button {
                seek(to: line)
            } label: {
                LyricLineView(
                    line: line,
                    emphasis: lineEmphasis,
                    fontSize: fontSize,
                    showsTranslation: settings.showLyricsTranslations,
                    offset: offset
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityText(for: line))
            .accessibilityHint("Plays from this line")
            .accessibilityAddTraits(lineEmphasis == .active ? .isSelected : [])
        case .gap(let end):
            if item.id == activeIndex {
                TimelineView(.animation(minimumInterval: tickInterval)) { context in
                    let time = player.currentTime + offset
                    GapDotsView(
                        progress: LyricsTimeline.progress(from: item.start, to: end, at: time),
                        breathing: reduceMotion ? 0 : (sin(context.date.timeIntervalSinceReferenceDate * 2.4) + 1) / 2
                    )
                }
                .frame(height: 28)
                .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .leading)))
            }
        }
    }

    private func emphasis(for id: Int) -> LyricLineView.Emphasis {
        guard let activeIndex else { return .upcoming }
        if id == activeIndex { return .active }
        return id < activeIndex ? .past : .upcoming
    }

    private func accessibilityText(for line: LyricsLine) -> String {
        guard settings.showLyricsTranslations, let translation = line.translation else { return line.text }
        return "\(line.text). \(translation)"
    }

    private func seek(to line: LyricsLine) {
        player.seek(to: max(line.start - offset, 0))
        isFollowing = true
        resumeFollowTask?.cancel()
        seekCount += 1
    }

    private func handleScrollPhase(_ phase: ScrollPhase, proxy: ScrollViewProxy) {
        switch phase {
        case .interacting:
            isFollowing = false
            resumeFollowTask?.cancel()
        case .idle where !isFollowing:
            resumeFollowTask?.cancel()
            resumeFollowTask = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                isFollowing = true
                if let activeIndex {
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.1)) {
                        proxy.scrollTo(activeIndex, anchor: UnitPoint(x: 0, y: 0.3))
                    }
                }
            }
        default:
            break
        }
    }
}
