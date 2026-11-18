import MediaPlayer
import UIKit

enum RemoteAction: Equatable {
    case play, pause, togglePlayPause, next, previous, toggleLike
    case seek(TimeInterval)
}

/// Lock screen, Control Center and Dynamic Island: publishes now-playing info and receives
/// remote commands. Used for local files only; MusicKit does this itself.
@MainActor
final class NowPlayingCenter {
    var handler: ((RemoteAction) -> Void)?

    private var artworkURL: URL?
    private var artwork: MPMediaItemArtwork?

    init() {
        let center = MPRemoteCommandCenter.shared()
        addTarget(center.playCommand, .play)
        addTarget(center.pauseCommand, .pause)
        addTarget(center.togglePlayPauseCommand, .togglePlayPause)
        addTarget(center.nextTrackCommand, .next)
        addTarget(center.previousTrackCommand, .previous)
        addTarget(center.likeCommand, .toggleLike)
        center.likeCommand.localizedTitle = String(localized: "Like")
        center.likeCommand.localizedShortTitle = String(localized: "Like")

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            return MainActor.assumeIsolated { self?.perform(.seek(position)) ?? .commandFailed }
        }

        let unused: [MPRemoteCommand] = [
            center.skipForwardCommand, center.skipBackwardCommand, center.dislikeCommand,
            center.bookmarkCommand, center.changeRepeatModeCommand, center.changeShuffleModeCommand,
        ]
        for command in unused {
            command.isEnabled = false
        }
    }

    func update(track: TrackInfo?, isPlaying: Bool, elapsed: TimeInterval, duration: TimeInterval, isLiked: Bool) {
        let infoCenter = MPNowPlayingInfoCenter.default()
        guard let track else {
            infoCenter.nowPlayingInfo = nil
            artworkURL = nil
            artwork = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album ?? "",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if track.artworkURL == artworkURL, let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        infoCenter.nowPlayingInfo = info
        MPRemoteCommandCenter.shared().likeCommand.isActive = isLiked

        if track.artworkURL != artworkURL {
            loadArtwork(for: track.artworkURL)
        }
    }

    private func loadArtwork(for url: URL?) {
        artworkURL = url
        artwork = nil
        guard let url else { return }
        Task {
            guard let image = await ImageLoader.shared.image(for: url, pixelSize: 600), artworkURL == url else { return }
            let artwork = Self.makeArtwork(image)
            self.artwork = artwork
            let infoCenter = MPNowPlayingInfoCenter.default()
            if var info = infoCenter.nowPlayingInfo {
                info[MPMediaItemPropertyArtwork] = artwork
                infoCenter.nowPlayingInfo = info
            }
        }
    }

    /// Built outside the main actor: the system asks for the image on a background thread.
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func addTarget(_ command: MPRemoteCommand, _ action: RemoteAction) {
        command.isEnabled = true
        command.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.perform(action) ?? .commandFailed }
        }
    }

    private func perform(_ action: RemoteAction) -> MPRemoteCommandHandlerStatus {
        guard let handler else { return .noActionableNowPlayingItem }
        handler(action)
        return .success
    }
}
