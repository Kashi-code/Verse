import Foundation

/// Five background-ready colours taken from a cover, most dominant first.
struct CoverPalette: Sendable, Hashable {
    static let colorCount = 5
    static let brightnessRange: ClosedRange<Double> = 0.18...0.62
    /// Clusters smaller than this share of the image are noise (edges, text).
    static let minimumWeight = 0.03

    let colors: [RGBColor]

    static let neutral = CoverPalette(uncheckedColors: [
        RGBColor(red: 0.24, green: 0.24, blue: 0.27),
        RGBColor(red: 0.31, green: 0.31, blue: 0.34),
        RGBColor(red: 0.19, green: 0.19, blue: 0.21),
        RGBColor(red: 0.27, green: 0.27, blue: 0.31),
        RGBColor(red: 0.35, green: 0.35, blue: 0.38),
    ])

    private init(uncheckedColors: [RGBColor]) {
        colors = uncheckedColors
    }

    /// Builds a palette from extracted colours; nil when there is nothing usable.
    init?(dominant: [WeightedColor]) {
        var usable = dominant.filter { $0.weight >= Self.minimumWeight }.map(\.color)
        if usable.isEmpty, let first = dominant.first?.color {
            usable = [first]
        }
        guard !usable.isEmpty else { return nil }

        var adjusted = usable.prefix(Self.colorCount).map { $0.adjustedForBackground() }
        // Pad with darker and lighter versions of what we have.
        var step = 0
        while adjusted.count < Self.colorCount {
            let base = adjusted[step % adjusted.count]
            adjusted.append(base.scalingBrightness(by: step.isMultiple(of: 2) ? 0.7 : 1.3))
            step += 1
        }
        colors = adjusted
    }

    var accent: RGBColor { colors[0] }

    /// Colours for a 3×3 mesh, row by row. The most dominant colour sits in the centre.
    var meshColors: [RGBColor] {
        let c = colors
        return [c[1], c[2], c[3],
                c[4], c[0], c[1],
                c[3], c[0], c[2]]
    }
}
