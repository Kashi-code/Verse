import Foundation

/// An sRGB colour with components from 0 to 1.
struct RGBColor: Sendable, Hashable, Codable {
    var red: Double
    var green: Double
    var blue: Double
}

extension RGBColor {
    init(hue: Double, saturation: Double, brightness: Double) {
        let s = min(max(saturation, 0), 1)
        let v = min(max(brightness, 0), 1)
        let h = (hue - hue.rounded(.down)) * 6
        let sector = Int(h) % 6
        let f = h - h.rounded(.down)
        let p = v * (1 - s)
        let q = v * (1 - s * f)
        let t = v * (1 - s * (1 - f))
        let rgb: (Double, Double, Double) = switch sector {
        case 0: (v, t, p)
        case 1: (q, v, p)
        case 2: (p, v, t)
        case 3: (p, q, v)
        case 4: (t, p, v)
        default: (v, p, q)
        }
        self.init(red: rgb.0, green: rgb.1, blue: rgb.2)
    }

    var hsb: (hue: Double, saturation: Double, brightness: Double) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue
        var hue = 0.0
        if delta > 0 {
            if maxValue == red {
                hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxValue == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, maxValue == 0 ? 0 : delta / maxValue, maxValue)
    }

    /// Keeps the hue but limits brightness and saturation so white text stays readable on top.
    func adjustedForBackground() -> RGBColor {
        let (hue, saturation, brightness) = hsb
        return RGBColor(
            hue: hue,
            saturation: min(saturation * 1.15, 0.85),
            brightness: min(max(brightness, CoverPalette.brightnessRange.lowerBound), CoverPalette.brightnessRange.upperBound)
        )
    }

    func scalingBrightness(by factor: Double) -> RGBColor {
        let (hue, saturation, brightness) = hsb
        let range = CoverPalette.brightnessRange
        return RGBColor(hue: hue, saturation: saturation, brightness: min(max(brightness * factor, range.lowerBound), range.upperBound))
    }

    var simd: SIMD3<Double> { SIMD3(red, green, blue) }

    init(_ vector: SIMD3<Double>) {
        self.init(red: vector.x, green: vector.y, blue: vector.z)
    }
}
