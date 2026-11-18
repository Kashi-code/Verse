import Foundation

struct ImportSummary: Sendable, Equatable {
    var imported = 0
    var skippedDuplicates = 0
    var failedFiles: [String] = []

    var needsAttention: Bool { skippedDuplicates > 0 || !failedFiles.isEmpty }

    var message: String {
        var parts = [String(localized: "Imported \(imported) songs.")]
        if skippedDuplicates > 0 {
            parts.append(String(localized: "\(skippedDuplicates) were already in your library."))
        }
        if !failedFiles.isEmpty {
            parts.append(String(localized: "Couldn't import: \(failedFiles.formatted(.list(type: .and)))."))
        }
        return parts.joined(separator: " ")
    }
}

/// Imports files picked in the Files app: copy, read tags, then add to the catalog.
@MainActor
struct LibraryImporter {
    let catalog: LibraryCatalog
    var processor = ImportFileProcessor()

    func importFiles(_ urls: [URL]) async -> ImportSummary {
        var summary = ImportSummary()
        for item in ImportPlanner.plan(urls) {
            do {
                let track = try await processor.process(item)
                if try catalog.isDuplicate(track) {
                    catalog.discardFiles(of: track)
                    summary.skippedDuplicates += 1
                } else {
                    try catalog.insert(track)
                    summary.imported += 1
                }
            } catch {
                summary.failedFiles.append(item.audio.lastPathComponent)
            }
        }
        try? catalog.context.save()
        return summary
    }
}
