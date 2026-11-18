import UIKit

/// Decodes cover art from `ArtworkStore` off the main thread and keeps recent images in memory.
@MainActor
final class ArtworkImageLoader {
    static let shared = ArtworkImageLoader()

    private let store: ArtworkStore
    private let cache = NSCache<NSString, UIImage>()

    init(store: ArtworkStore = .shared) {
        self.store = store
        cache.countLimit = 300
    }

    func cachedImage(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func image(for key: String) async -> UIImage? {
        if let cached = cachedImage(for: key) { return cached }
        guard let image = await ArtworkDecoder.decode(store.url(for: key)) else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }
}

enum ArtworkDecoder {
    @concurrent
    static func decode(_ url: URL) async -> UIImage? {
        guard let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) else { return nil }
        return await image.byPreparingForDisplay() ?? image
    }
}
