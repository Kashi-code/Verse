import CoreGraphics
import Foundation
import Testing
@testable import Verse

struct ColorExtractionTests {
    private let red = SIMD3<Double>(0.9, 0.1, 0.1)
    private let blue = SIMD3<Double>(0.1, 0.2, 0.9)

    private func repeated(_ color: SIMD3<Double>, _ count: Int) -> [SIMD3<Double>] {
        Array(repeating: color, count: count)
    }

    private func isClose(_ a: RGBColor, _ b: SIMD3<Double>, tolerance: Double = 0.05) -> Bool {
        abs(a.red - b.x) < tolerance && abs(a.green - b.y) < tolerance && abs(a.blue - b.z) < tolerance
    }

    /// An image whose left half is `left` and right half is `right`.
    private func splitImage(left: CGColor, right: CGColor, width: Int = 100, height: Int = 50) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(left)
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(right)
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        return try #require(context.makeImage())
    }

    @Test func findsColorsAndTheirShare() {
        let result = ColorExtractor.dominantColors(in: repeated(red, 700) + repeated(blue, 300), count: 5)
        #expect(result.count == 2)
        #expect(abs(result[0].weight - 0.7) < 0.001)
        #expect(isClose(result[0].color, red))
        #expect(isClose(result[1].color, blue))
    }

    @Test func noisyClustersConvergeToTheirCentres() {
        var pixels: [SIMD3<Double>] = []
        for index in 0..<600 {
            let jitter = Double(index % 7) * 0.01 - 0.03
            pixels.append(red + SIMD3(jitter, jitter, -jitter))
            if index < 400 {
                pixels.append(blue + SIMD3(-jitter, jitter, jitter))
            }
        }
        let result = ColorExtractor.dominantColors(in: pixels, count: 2)
        #expect(result.count == 2)
        #expect(isClose(result[0].color, red))
        #expect(isClose(result[1].color, blue))
        #expect(abs(result[0].weight - 0.6) < 0.01)
    }

    @Test func isDeterministic() {
        let pixels: [SIMD3<Double>] = (0..<500).map { i in
            let red = Double(i % 10) / 10
            let green = Double(i % 7) / 7
            let blue = Double(i % 3) / 3
            return SIMD3(red, green, blue)
        }
        #expect(ColorExtractor.dominantColors(in: pixels, count: 5) == ColorExtractor.dominantColors(in: pixels, count: 5))
    }

    @Test func emptyInput() {
        #expect(ColorExtractor.dominantColors(in: [], count: 5).isEmpty)
        #expect(CoverPalette(dominant: []) == nil)
    }

    @Test func readsPixelsFromAnImage() throws {
        let image = try splitImage(
            left: CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1),
            right: CGColor(srgbRed: 0, green: 0.8, blue: 0, alpha: 1)
        )
        let pixels = ColorExtractor.pixels(of: image, maxDimension: 40)
        #expect(pixels.count == 40 * 20)

        let colors = ColorExtractor.dominantColors(in: pixels, count: 5)
        #expect(colors.count >= 2)
        #expect(colors[0].weight > 0.4 && colors[1].weight > 0.4)
        let found = colors.prefix(2).map(\.color)
        #expect(found.contains { isClose($0, SIMD3(1, 0, 0), tolerance: 0.1) })
        #expect(found.contains { isClose($0, SIMD3(0, 0.8, 0), tolerance: 0.1) })
    }

    @Test func skipsTransparentPixels() throws {
        let image = try splitImage(
            left: CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1),
            right: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)
        )
        let pixels = ColorExtractor.pixels(of: image)
        #expect(!pixels.isEmpty)
        #expect(pixels.allSatisfy { $0.z > 0.9 && $0.x < 0.1 })
    }

    @Test func paletteIsReadyForWhiteText() throws {
        let palette = try #require(CoverPalette(dominant: [
            WeightedColor(color: RGBColor(red: 1, green: 1, blue: 1), weight: 0.9),
            WeightedColor(color: RGBColor(red: 1, green: 0.95, blue: 0.2), weight: 0.08),
            WeightedColor(color: RGBColor(red: 0, green: 0, blue: 0), weight: 0.02),
        ]))
        #expect(palette.colors.count == CoverPalette.colorCount)
        #expect(palette.meshColors.count == 9)
        let range = CoverPalette.brightnessRange
        for color in palette.colors {
            let brightness = color.hsb.brightness
            #expect(brightness >= range.lowerBound - 1e-9 && brightness <= range.upperBound + 1e-9)
        }
        // The 2% black cluster is treated as noise, so the second colour is the yellow one.
        #expect(palette.colors[1].hsb.hue > 0.1 && palette.colors[1].hsb.hue < 0.2)
    }

    @Test(arguments: [
        RGBColor(red: 0.8, green: 0.2, blue: 0.1),
        RGBColor(red: 0.1, green: 0.7, blue: 0.3),
        RGBColor(red: 0.2, green: 0.3, blue: 0.9),
        RGBColor(red: 0.5, green: 0.5, blue: 0.5),
        RGBColor(red: 0.9, green: 0.1, blue: 0.8),
    ])
    func hsbRoundTrip(_ color: RGBColor) {
        let (hue, saturation, brightness) = color.hsb
        let back = RGBColor(hue: hue, saturation: saturation, brightness: brightness)
        #expect(abs(back.red - color.red) < 1e-9)
        #expect(abs(back.green - color.green) < 1e-9)
        #expect(abs(back.blue - color.blue) < 1e-9)
    }

    @Test func meshPointsStayInsideTheUnitSquare() {
        for time in stride(from: 0.0, to: 600, by: 7.3) {
            let points = CoverMeshBackground.points(at: time)
            #expect(points.count == 9)
            #expect(points.allSatisfy { $0.x >= 0 && $0.x <= 1 && $0.y >= 0 && $0.y <= 1 })
        }
    }
}
