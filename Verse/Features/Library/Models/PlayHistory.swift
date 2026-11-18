import Foundation
import SwiftData

@Model
final class PlayHistory {
    var playedAt: Date
    var song: Song?

    init(playedAt: Date = .now) {
        self.playedAt = playedAt
    }
}
