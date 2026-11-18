import SwiftUI
import UIKit

/// A faint, tiled noise texture over gradients so they don't show banding.
struct GrainOverlay: View {
    var opacity: Double = 0.07

    var body: some View {
        Image(uiImage: GrainTexture.image)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .blendMode(.overlay)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

enum GrainTexture {
    /// Made once: 128×128 grey noise from a fixed seed.
    @MainActor static let image: UIImage = make(size: 128, seed: 0x5EED)

    static func make(size: Int, seed: UInt64) -> UIImage {
        var state = seed
        var pixels = [UInt8](repeating: 0, count: size * size)
        for index in pixels.indices {
            // SplitMix64
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            pixels[index] = UInt8(truncatingIfNeeded: z ^ (z >> 31))
        }
        let image = pixels.withUnsafeMutableBytes { raw -> CGImage? in
            guard let context = CGContext(
                data: raw.baseAddress, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            return context.makeImage()
        }
        return image.map { UIImage(cgImage: $0) } ?? UIImage()
    }
}
