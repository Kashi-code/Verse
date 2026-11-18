import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Verse

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "VerseTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

struct ManagedFileStoreTests {
    @Test func copiesRemovesAndMeasuresFiles() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "Original Song.MP3")
        try Data("hello".utf8).write(to: source)

        let store = ManagedFileStore(directory: root.appending(path: "Music", directoryHint: .isDirectory))
        let stored = try store.copyIn(source)

        #expect(stored.name.hasSuffix(".mp3"))
        #expect(stored.size == 5)
        #expect(store.contains(stored.name))
        #expect(store.totalSize() == 5)
        // The original stays where it was.
        #expect(FileManager.default.fileExists(atPath: source.path(percentEncoded: false)))

        let second = try store.copyIn(source)
        #expect(second.name != stored.name)
        #expect(store.totalSize() == 10)

        store.remove(stored.name)
        #expect(!store.contains(stored.name))

        try store.removeAll()
        #expect(store.totalSize() == 0)
    }
}

struct ArtworkStoreTests {
    private func makePNG(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func storesDownscaledCopyOnce() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ArtworkStore(directory: root, maxPixelSize: 600)
        let png = try makePNG(width: 1200, height: 800)

        let key = try #require(try store.store(png))
        #expect(try store.store(png) == key)

        let source = try #require(CGImageSourceCreateWithURL(store.url(for: key) as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(max(image.width, image.height) == 600)
    }

    @Test func rejectsNonImageData() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ArtworkStore(directory: root)
        #expect(try store.store(Data("not an image".utf8)) == nil)
    }
}
