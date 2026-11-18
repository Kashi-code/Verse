import CoreGraphics
import Foundation
import ImageIO

struct WeightedColor: Sendable, Equatable {
    var color: RGBColor
    /// Share of the image's pixels, 0 to 1.
    var weight: Double
}

/// Finds the main colours of an image with k-means clustering on a small thumbnail.
enum ColorExtractor {
    /// Reads the opaque pixels of a downscaled copy, as RGB from 0 to 1.
    static func pixels(of image: CGImage, maxDimension: Int = 40) -> [SIMD3<Double>] {
        let scale = min(1, Double(maxDimension) / Double(max(image.width, image.height, 1)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return [] }

        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return [] }

        var pixels: [SIMD3<Double>] = []
        pixels.reserveCapacity(width * height)
        for offset in stride(from: 0, to: buffer.count, by: 4) {
            let alpha = Double(buffer[offset + 3])
            guard alpha >= 128 else { continue }
            // Undo premultiplication; components are now 0...1.
            pixels.append(SIMD3(Double(buffer[offset]), Double(buffer[offset + 1]), Double(buffer[offset + 2])) / alpha)
        }
        return pixels
    }

    /// k-means with a deterministic farthest-point start. Returns up to `count` colours, most common first.
    static func dominantColors(in pixels: [SIMD3<Double>], count: Int, iterations: Int = 12) -> [WeightedColor] {
        guard !pixels.isEmpty, count > 0 else { return [] }

        let mean = pixels.reduce(SIMD3<Double>.zero, +) / Double(pixels.count)
        var centroids = [pixels.min { distanceSquared($0, mean) < distanceSquared($1, mean) }!]
        while centroids.count < count {
            var farthest = pixels[0]
            var farthestDistance = -1.0
            for pixel in pixels {
                let distance = centroids.map { distanceSquared(pixel, $0) }.min() ?? 0
                if distance > farthestDistance {
                    farthestDistance = distance
                    farthest = pixel
                }
            }
            // Fewer distinct colours than requested.
            if farthestDistance < 1e-6 { break }
            centroids.append(farthest)
        }

        var counts = [Int](repeating: 0, count: centroids.count)
        for _ in 0..<max(iterations, 1) {
            var sums = [SIMD3<Double>](repeating: .zero, count: centroids.count)
            counts = [Int](repeating: 0, count: centroids.count)
            for pixel in pixels {
                let index = nearest(pixel, in: centroids)
                sums[index] += pixel
                counts[index] += 1
            }
            var moved = false
            for index in centroids.indices where counts[index] > 0 {
                let updated = sums[index] / Double(counts[index])
                if distanceSquared(updated, centroids[index]) > 1e-10 { moved = true }
                centroids[index] = updated
            }
            if !moved { break }
        }

        let total = Double(pixels.count)
        return centroids.indices
            .filter { counts[$0] > 0 }
            .map { WeightedColor(color: RGBColor(centroids[$0]), weight: Double(counts[$0]) / total) }
            .sorted { $0.weight > $1.weight }
    }

    /// Palette for the cover art file at `url`, or nil if it can't be read.
    @concurrent
    static func palette(fromImageAt url: URL) async -> CoverPalette? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 64,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return CoverPalette(dominant: dominantColors(in: pixels(of: image), count: 5))
    }

    private static func nearest(_ pixel: SIMD3<Double>, in centroids: [SIMD3<Double>]) -> Int {
        var best = 0
        var bestDistance = Double.infinity
        for (index, centroid) in centroids.enumerated() {
            let distance = distanceSquared(pixel, centroid)
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    private static func distanceSquared(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = a - b
        return (d * d).sum()
    }
}
