import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Downscaled cover art, stored in Caches (it can always be re-read from the audio files).
struct ArtworkStore: Sendable {
    let directory: URL
    var maxPixelSize = 600

    static let shared = ArtworkStore(
        directory: .cachesDirectory.appending(path: "Artwork", directoryHint: .isDirectory)
    )

    func url(for key: String) -> URL {
        directory.appending(path: "\(key).jpg", directoryHint: .notDirectory)
    }

    /// Stores a downscaled JPEG of `imageData` and returns its key, or `nil` if the data is not an image.
    /// Identical images share one key, so an album's songs share one file.
    func store(_ imageData: Data) throws -> String? {
        let key = Self.key(for: imageData)
        let destinationURL = url(for: key)
        if FileManager.default.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
            return key
        }
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        let destinationOptions: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.85]
        CGImageDestinationAddImage(destination, image, destinationOptions as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return key
    }

    func removeAll() throws {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    static func key(for data: Data) -> String {
        SHA256.hash(data: data).prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
