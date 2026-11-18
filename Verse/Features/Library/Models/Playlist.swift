import Foundation
import SwiftData

@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateCreated: Date
    var dateModified: Date

    @Relationship(deleteRule: .cascade, inverse: \PlaylistEntry.playlist)
    var entries: [PlaylistEntry] = []

    init(id: UUID = UUID(), name: String, dateCreated: Date = .now) {
        self.id = id
        self.name = name
        self.dateCreated = dateCreated
        self.dateModified = dateCreated
    }
}

/// One position in a playlist. A song can appear in a playlist more than once.
@Model
final class PlaylistEntry {
    var position: Int
    var dateAdded: Date
    var playlist: Playlist?
    var song: Song?

    init(position: Int, dateAdded: Date = .now) {
        self.position = position
        self.dateAdded = dateAdded
    }
}
