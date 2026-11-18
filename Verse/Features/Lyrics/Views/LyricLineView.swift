import SwiftUI

/// One lyrics line. When active and word-timed, each word fills with colour as it is sung.
struct LyricLineView: View {
    enum Emphasis {
        case past, active, upcoming
    }

    let line: LyricsLine
    let emphasis: Emphasis
    let fontSize: CGFloat
    let showsTranslation: Bool
    let offset: Double

    @Environment(PlayerController.self) private var player
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.2) {
            if emphasis == .active, let words = line.words {
                TimelineView(.animation(minimumInterval: player.isPlaying ? nil : 0.25)) { _ in
                    let time = player.currentTime + offset
                    WordFlowLayout(spaceWidth: fontSize * 0.27, lineSpacing: fontSize * 0.12) {
                        ForEach(words.indices, id: \.self) { index in
                            KaraokeWord(
                                text: words[index].text,
                                progress: words[index].progress(at: time),
                                fontSize: fontSize,
                                lifts: !reduceMotion
                            )
                            .layoutValue(key: TrailingSpace.self, value: words[index].hasTrailingSpace)
                        }
                    }
                }
            } else {
                Text(line.text)
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showsTranslation, let translation = line.translation {
                Text(translation)
                    .font(.system(size: fontSize * 0.6, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.white)
        .opacity(opacity)
        .blur(radius: reduceTransparency ? 0 : blurRadius)
        .scaleEffect(emphasis == .active ? 1 : 0.94, anchor: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    /// Past lines are slightly blurred, upcoming ones barely; the active line is sharp.
    private var blurRadius: CGFloat {
        switch emphasis {
        case .active: 0
        case .upcoming: 0.6
        case .past: 1.6
        }
    }

    private var opacity: Double {
        switch emphasis {
        case .active: 1
        case .upcoming: 0.5
        case .past: 0.3
        }
    }
}

/// A word drawn twice: dim underneath, bright on top behind a moving gradient mask.
/// While it is being sung it lifts slightly and glows.
struct KaraokeWord: View {
    let text: String
    let progress: Double
    let fontSize: CGFloat
    let lifts: Bool

    var body: some View {
        let font = Font.system(size: fontSize, weight: .heavy, design: .rounded)
        let wave = lifts ? sin(Double.pi * progress) : 0

        Text(text)
            .font(font)
            .foregroundStyle(.white.opacity(0.35))
            .overlay(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundStyle(.white)
                    .mask {
                        LinearGradient(stops: Self.maskStops(progress: progress), startPoint: .leading, endPoint: .trailing)
                    }
            }
            .shadow(color: .white.opacity(0.35 * wave), radius: 8)
            .offset(y: -2.5 * wave)
            .fixedSize()
    }

    /// Opaque up to the sung point, then a soft edge.
    nonisolated static func maskStops(progress: Double) -> [Gradient.Stop] {
        let edge = 0.18
        let tail = progress * (1 + edge)
        let head = tail - edge
        return [
            .init(color: .black, location: 0),
            .init(color: .black, location: min(max(head, 0), 1)),
            .init(color: .clear, location: min(max(tail, 0), 1)),
            .init(color: .clear, location: 1),
        ]
    }
}

struct TrailingSpace: LayoutValueKey {
    static let defaultValue = false
}

/// Lays words out left to right and wraps, adding a space only where the lyrics have one.
struct WordFlowLayout: Layout {
    var spaceWidth: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrange(maxWidth: bounds.width, subviews: subviews).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            widest = max(widest, x + size.width)
            x += size.width + (subview[TrailingSpace.self] ? spaceWidth : 0)
            lineHeight = max(lineHeight, size.height)
        }
        return (frames, CGSize(width: widest, height: y + lineHeight))
    }
}

/// Three dots that fill one by one during an instrumental break.
struct GapDotsView: View {
    let progress: Double
    /// 0...1, a slow pulse; 0 with Reduce Motion.
    let breathing: Double

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                let fill = min(max(progress * 3 - Double(index), 0), 1)
                Circle()
                    .fill(.white.opacity(0.25 + 0.75 * fill))
                    .frame(width: 12, height: 12)
            }
        }
        .scaleEffect(1 + 0.08 * breathing, anchor: .leading)
        .accessibilityElement()
        .accessibilityLabel("Instrumental")
    }
}
