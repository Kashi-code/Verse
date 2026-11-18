import SwiftUI

/// Extracts cover palettes off the main thread and remembers them for the session.
@MainActor
final class CoverPaletteProvider {
    static let shared = CoverPaletteProvider()

    private let store: ArtworkStore
    private var cache: [String: CoverPalette] = [:]

    init(store: ArtworkStore = .shared) {
        self.store = store
    }

    func cachedPalette(for key: String?) -> CoverPalette? {
        guard let key else { return .neutral }
        return cache[key]
    }

    func palette(for key: String?) async -> CoverPalette {
        guard let key else { return .neutral }
        if let cached = cache[key] { return cached }
        let palette = await ColorExtractor.palette(fromImageAt: store.url(for: key)) ?? .neutral
        cache[key] = palette
        return palette
    }
}

extension Color {
    init(_ color: RGBColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue)
    }
}
