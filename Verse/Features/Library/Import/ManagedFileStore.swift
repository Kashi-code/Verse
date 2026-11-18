import Foundation

struct StoredFile: Sendable, Equatable {
    let name: String
    let size: Int64
}

/// A folder of user files the app owns (imported audio, imported `.lrc` files).
/// These live in Application Support and are never touched by "clear cache".
struct ManagedFileStore: Sendable {
    let directory: URL

    static let music = ManagedFileStore(
        directory: .applicationSupportDirectory.appending(path: "Music", directoryHint: .isDirectory)
    )
    static let importedLyrics = ManagedFileStore(
        directory: .applicationSupportDirectory.appending(path: "Lyrics", directoryHint: .isDirectory)
    )

    func url(for fileName: String) -> URL {
        directory.appending(path: fileName, directoryHint: .notDirectory)
    }

    /// Copies `source` into the store under a new unique name that keeps the file extension.
    func copyIn(_ source: URL) throws -> StoredFile {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileExtension = source.pathExtension.lowercased()
        let name = fileExtension.isEmpty ? UUID().uuidString : "\(UUID().uuidString).\(fileExtension)"
        let destination = url(for: name)
        try FileManager.default.copyItem(at: source, to: destination)
        let size = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        return StoredFile(name: name, size: Int64(size))
    }

    func contains(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName).path(percentEncoded: false))
    }

    func remove(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    func removeAll() throws {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    func totalSize() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        while let url = enumerator.nextObject() as? URL {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}
