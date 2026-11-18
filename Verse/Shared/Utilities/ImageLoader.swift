import CryptoKit
import ImageIO
import UIKit

/// Loads remote images with a memory cache and a disk cache in Caches/Images.
/// Images are decoded off the main thread at the size they are shown.
@MainActor
final class ImageLoader {
    static let shared = ImageLoader()

    let directory: URL
    private let memory = NSCache<NSString, UIImage>()
    private var downloads: [URL: Task<URL?, Never>] = [:]

    init(directory: URL = .cachesDirectory.appending(path: "Images", directoryHint: .isDirectory)) {
        self.directory = directory
        memory.countLimit = 400
    }

    func cachedImage(for url: URL, pixelSize: Int) -> UIImage? {
        memory.object(forKey: Self.memoryKey(url, pixelSize))
    }

    func image(for url: URL, pixelSize: Int) async -> UIImage? {
        let key = Self.memoryKey(url, pixelSize)
        if let cached = memory.object(forKey: key) { return cached }
        guard let file = await fileURL(for: url),
              let image = await ImageDecoding.decode(file, maxPixelSize: pixelSize) else { return nil }
        memory.setObject(image, forKey: key)
        return image
    }

    /// The image's file on disk, downloading it once if needed.
    func fileURL(for url: URL) async -> URL? {
        let file = directory.appending(path: Self.fileName(for: url), directoryHint: .notDirectory)
        if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) { return file }
        if let running = downloads[url] { return await running.value }
        let directory = directory
        let task = Task { await ImageDecoding.download(url, to: file, directory: directory) }
        downloads[url] = task
        let result = await task.value
        downloads[url] = nil
        return result
    }

    func clearDiskCache() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
    }

    nonisolated static func fileName(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private static func memoryKey(_ url: URL, _ pixelSize: Int) -> NSString {
        "\(url.absoluteString)#\(pixelSize)" as NSString
    }
}

enum ImageDecoding {
    @concurrent
    static func download(_ url: URL, to file: URL, directory: URL) async -> URL? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode ?? 200 < 400, !data.isEmpty else { return nil }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            return file
        } catch {
            return nil
        }
    }

    @concurrent
    static func decode(_ file: URL, maxPixelSize: Int) async -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 32),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

/// Total size of the files in a folder.
enum DirectorySize {
    static func of(_ directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        while let url = enumerator.nextObject() as? URL {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}
