import SwiftData
import SwiftUI

/// The user's own music. Playlists, saved albums and followed artists arrive in the library milestone.
struct LibraryView: View {
    @State private var router = Router()
    @Query(sort: \LikedTrack.likedAt, order: .reverse) private var liked: [LikedTrack]

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            List {
                Button { router.open(.likedSongs) } label: {
                    LibraryEntryRow(title: "Liked Songs", systemImage: "heart.fill", detail: "\(liked.count)")
                }
                Button { router.open(.recentlyPlayed) } label: {
                    LibraryEntryRow(title: "Recently Played", systemImage: "clock.fill", detail: nil)
                }
            }
            .listStyle(.insetGrouped)
            .buttonStyle(.plain)
            .navigationTitle("Library")
            .catalogDestinations()
        }
        .environment(router)
    }
}

private struct LibraryEntryRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let detail: String?

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .glassSurface(cornerRadius: DS.Radius.control, shadow: false)
            Text(title).font(DS.Typography.rowTitle)
            Spacer()
            if let detail {
                Text(detail).foregroundStyle(DS.Text.tertiary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DS.Text.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
    }
}

struct LikedSongsView: View {
    @Query(sort: \LikedTrack.likedAt, order: .reverse) private var liked: [LikedTrack]
    @Environment(PlayerController.self) private var player

    var body: some View {
        let tracks = liked.compactMap(\.track)
        ScrollView {
            VStack(spacing: DS.Spacing.l) {
                if tracks.isEmpty {
                    ContentUnavailableView("No Liked Songs", systemImage: "heart",
                                           description: Text("Tap the heart on any song to save it here."))
                } else {
                    PlayShuffleButtons { shuffled in
                        player.play(tracks, from: .playlist(String(localized: "Liked Songs")), shuffled: shuffled)
                    }
                    .padding(.horizontal, DS.Spacing.m)
                    TrackList(tracks: tracks) { index in
                        player.play(tracks, startingAt: index, from: .playlist(String(localized: "Liked Songs")))
                    }
                }
            }
            .padding(.vertical, DS.Spacing.m)
        }
        .navigationTitle("Liked Songs")
    }
}

struct RecentlyPlayedView: View {
    @Query(HomeView.historyDescriptor) private var history: [PlayHistory]
    @Environment(PlayerController.self) private var player

    var body: some View {
        let tracks = uniqueTracks
        ScrollView {
            if tracks.isEmpty {
                ContentUnavailableView("Nothing Played Yet", systemImage: "clock",
                                       description: Text("Songs you play will show up here."))
            } else {
                TrackList(tracks: tracks) { index in
                    player.play(tracks, startingAt: index, from: .songs)
                }
                .padding(.vertical, DS.Spacing.m)
            }
        }
        .navigationTitle("Recently Played")
    }

    private var uniqueTracks: [TrackInfo] {
        var seen = Set<String>()
        return history.filter { seen.insert($0.trackKey).inserted }.compactMap(\.track)
    }
}
