import AppIntents
import SwiftData

// Siri, Shortcuts and Spotlight actions. They run inside the app, using the same player and library.

enum VerseIntentError: Error, CustomLocalizedStringResourceConvertible {
    case nothingPlaying
    case playlistNotFound
    case emptyPlaylist
    case nothingSimilar

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .nothingPlaying: "Nothing is playing in Verse."
        case .playlistNotFound: "That playlist doesn't exist anymore."
        case .emptyPlaylist: "That playlist has no songs yet."
        case .nothingSimilar: "Couldn't find similar songs right now."
        }
    }
}

struct TogglePlaybackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause"

    @Dependency private var player: PlayerController

    @MainActor
    func perform() async throws -> some IntentResult {
        guard player.currentTrack != nil else { throw VerseIntentError.nothingPlaying }
        player.togglePlayPause()
        return .result()
    }
}

struct NextSongIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Next Song"

    @Dependency private var player: PlayerController

    @MainActor
    func perform() async throws -> some IntentResult {
        guard player.currentTrack != nil else { throw VerseIntentError.nothingPlaying }
        player.skipToNext()
        return .result()
    }
}

struct PreviousSongIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Previous Song"

    @Dependency private var player: PlayerController

    @MainActor
    func perform() async throws -> some IntentResult {
        guard player.currentTrack != nil else { throw VerseIntentError.nothingPlaying }
        player.skipToPrevious()
        return .result()
    }
}

struct LikeCurrentSongIntent: AppIntent {
    static let title: LocalizedStringResource = "Like Current Song"

    @Dependency private var player: PlayerController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let track = player.currentTrack else { throw VerseIntentError.nothingPlaying }
        if !player.isCurrentLiked { player.toggleLike() }
        return .result(dialog: "Added \(track.title) to Liked Songs.")
    }
}

struct PlaySimilarIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play Something Like This"

    @Dependency private var player: PlayerController

    @MainActor
    func perform() async throws -> some IntentResult {
        guard player.currentTrack != nil else { throw VerseIntentError.nothingPlaying }
        guard await player.playSimilarSongs() else { throw VerseIntentError.nothingSimilar }
        return .result()
    }
}

struct PlayPlaylistIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play Playlist"

    @Parameter(title: "Playlist")
    var playlist: PlaylistEntity

    @Parameter(title: "Shuffle", default: false)
    var shuffle: Bool

    @Dependency private var player: PlayerController
    @Dependency private var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$playlist)") {
            \.$shuffle
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let id = playlist.id
        var descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let found = try container.mainContext.fetch(descriptor).first else {
            throw VerseIntentError.playlistNotFound
        }
        let tracks = found.tracks
        guard !tracks.isEmpty else { throw VerseIntentError.emptyPlaylist }
        player.play(tracks, from: .playlist(found.name), shuffled: shuffle)
        return .result()
    }
}

/// One of the user's own playlists, for Siri and Shortcuts.
struct PlaylistEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Playlist") }
    static var defaultQuery: PlaylistEntityQuery { PlaylistEntityQuery() }

    let id: UUID
    let name: String
    let songCount: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(songCount) songs")
    }
}

struct PlaylistEntityQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    func entities(for identifiers: [UUID]) async throws -> [PlaylistEntity] {
        let wanted = Set(identifiers)
        return try allPlaylists().filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [PlaylistEntity] {
        let needle = LibraryKey.normalized(string)
        return try allPlaylists().filter { LibraryKey.normalized($0.name).contains(needle) }
    }

    func suggestedEntities() async throws -> [PlaylistEntity] {
        try allPlaylists()
    }

    /// A private context, so this works off the main thread.
    private func allPlaylists() throws -> [PlaylistEntity] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\.dateModified, order: .reverse)])
        return try context.fetch(descriptor).map {
            PlaylistEntity(id: $0.id, name: $0.name, songCount: $0.entries.count)
        }
    }
}

struct VerseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayPlaylistIntent(),
            phrases: [
                "Play \(\.$playlist) in \(.applicationName)",
                "Play my playlist in \(.applicationName)",
            ],
            shortTitle: "Play Playlist",
            systemImageName: "music.note.list"
        )
        AppShortcut(
            intent: PlaySimilarIntent(),
            phrases: [
                "Play something like this in \(.applicationName)",
                "Play more like this in \(.applicationName)",
            ],
            shortTitle: "Play Similar",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: LikeCurrentSongIntent(),
            phrases: ["Like this song in \(.applicationName)"],
            shortTitle: "Like Song",
            systemImageName: "heart"
        )
        AppShortcut(
            intent: TogglePlaybackIntent(),
            phrases: ["Pause \(.applicationName)", "Resume \(.applicationName)"],
            shortTitle: "Play or Pause",
            systemImageName: "playpause"
        )
        AppShortcut(
            intent: NextSongIntent(),
            phrases: ["Skip this song in \(.applicationName)"],
            shortTitle: "Next Song",
            systemImageName: "forward"
        )
    }
}
