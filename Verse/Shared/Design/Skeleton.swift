import SwiftUI

/// A soft shimmer that sweeps over placeholder shapes while content loads.
struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.overlay {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.16), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: (proxy.size.width * 1.6) * phase - proxy.size.width * 0.6)
                    }
                }
                .mask(content)
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat = DS.Radius.control

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DS.Fill.standard)
            .frame(width: width, height: height)
    }
}

/// Placeholder for a horizontal shelf of cards.
struct SkeletonShelf: View {
    var cardSize: CGFloat = DS.Size.cardArtwork

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            SkeletonBlock(width: 160, height: 22)
                .padding(.horizontal, DS.Spacing.m)
            ScrollView(.horizontal) {
                HStack(spacing: DS.Spacing.s) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            SkeletonBlock(width: cardSize, height: cardSize, cornerRadius: DS.Radius.card)
                            SkeletonBlock(width: cardSize * 0.8, height: 12)
                            SkeletonBlock(width: cardSize * 0.5, height: 10)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.m)
            }
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
        }
        .shimmer()
        .accessibilityHidden(true)
    }
}

/// Placeholder for a list of song rows.
struct SkeletonRows: View {
    var count = 6

    var body: some View {
        VStack(spacing: DS.Spacing.s) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: DS.Spacing.s) {
                    SkeletonBlock(width: DS.Size.rowArtwork, height: DS.Size.rowArtwork)
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        SkeletonBlock(width: 180, height: 12)
                        SkeletonBlock(width: 110, height: 10)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.m)
        .shimmer()
        .accessibilityHidden(true)
    }
}
