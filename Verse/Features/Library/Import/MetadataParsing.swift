import Foundation

/// Small, pure helpers for turning raw tag values into clean fields.
enum MetadataParsing {
    static func cleaned(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// ID3 style positions: "3/12" or "3" → 3.
    static func position(from string: String) -> Int? {
        guard let first = string.split(separator: "/").first,
              let number = Int(first.trimmingCharacters(in: .whitespaces)),
              number > 0 else { return nil }
        return number
    }

    /// iTunes `trkn` / `disk` atoms: two reserved bytes, then a big-endian UInt16 position, then the total.
    static func iTunesPosition(from data: Data) -> Int? {
        guard data.count >= 4 else { return nil }
        let bytes = [UInt8](data)
        let number = Int(bytes[2]) << 8 | Int(bytes[3])
        return number > 0 ? number : nil
    }

    /// "2019", "2019-05-01" or "2019-05-01T10:00:00Z" → 2019.
    static func year(from string: String) -> Int? {
        let digits = string.trimmingCharacters(in: .whitespaces).prefix { $0.isASCII && $0.isNumber }
        guard digits.count == 4, let year = Int(digits), year > 0 else { return nil }
        return year
    }

    /// Title to use when a file has no title tag: the file name without extension.
    static func fallbackTitle(for url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ")
        return cleaned(base) ?? String(localized: "Unknown Title")
    }
}
