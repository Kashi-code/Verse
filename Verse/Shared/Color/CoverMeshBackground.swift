import SwiftUI

/// A slowly moving mesh gradient in the cover's colours. Cross-fades when the palette changes
/// and stays still with Reduce Motion.
struct CoverMeshBackground: View {
    let palette: CoverPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach([palette], id: \.self) { palette in
                layer(for: palette)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.2), value: palette)
        .overlay(Color.black.opacity(0.12))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func layer(for palette: CoverPalette) -> some View {
        let colors = palette.meshColors.map { Color($0) }
        if reduceMotion {
            MeshGradient(width: 3, height: 3, points: Self.points(at: 0), colors: colors)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: Self.points(at: context.date.timeIntervalSinceReferenceDate),
                    colors: colors
                )
            }
        }
    }

    /// Corner points stay fixed, edge points slide along their edge, the centre wanders.
    nonisolated static func points(at time: TimeInterval) -> [SIMD2<Float>] {
        let a = Float(sin(time * 0.21))
        let b = Float(cos(time * 0.17))
        let c = Float(sin(time * 0.13 + 1.3))
        let d = Float(cos(time * 0.19 + 0.7))
        return [
            [0, 0], [0.5 + 0.12 * a, 0], [1, 0],
            [0, 0.5 + 0.12 * b], [0.5 + 0.16 * c, 0.5 + 0.14 * d], [1, 0.5 + 0.12 * a],
            [0, 1], [0.5 + 0.12 * d, 1], [1, 1],
        ]
    }
}
