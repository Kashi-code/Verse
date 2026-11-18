import SwiftUI

/// Extracts cover palettes off the main thread and remembers them for the session.
@MainActor
final class CoverPaletteProvider {
    static let shared = CoverPaletteProvider()

    private let images: ImageLoader
    private var cache: [URL: CoverPalette] = [:]

    init(images: ImageLoader = .shared) {
        self.images = images
    }

    func cachedPalette(for url: URL?) -> CoverPalette? {
        guard let url else { return .neutral }
        return cache[url]
    }

    func palette(for url: URL?) async -> CoverPalette {
        guard let url else { return .neutral }
        if let cached = cache[url] { return cached }
        guard let file = await images.fileURL(for: url) else { return .neutral }
        let palette = await ColorExtractor.palette(fromImageAt: file) ?? .neutral
        cache[url] = palette
        return palette
    }
}

extension Color {
    init(_ color: RGBColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue)
    }
}
