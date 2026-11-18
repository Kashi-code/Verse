import Foundation

/// Splits a picked set of files into audio files, each paired with a `.lrc` file of the same name if one was picked.
enum ImportPlanner {
    static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "alac", "flac", "wav", "aif", "aiff", "caf"]
    static let lyricsExtensions: Set<String> = ["lrc"]

    struct Item: Sendable, Equatable {
        let audio: URL
        let lyrics: URL?
    }

    static func plan(_ urls: [URL]) -> [Item] {
        var lyricsByName: [String: URL] = [:]
        for url in urls where lyricsExtensions.contains(url.pathExtension.lowercased()) {
            lyricsByName[baseName(of: url)] = url
        }
        return urls
            .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            .map { Item(audio: $0, lyrics: lyricsByName[baseName(of: $0)]) }
    }

    private static func baseName(of url: URL) -> String {
        url.deletingPathExtension().lastPathComponent.lowercased()
    }
}
