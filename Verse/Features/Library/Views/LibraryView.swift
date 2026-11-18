import SwiftData
import SwiftUI

/// The user's own music: likes, saved albums and playlists, followed artists, history.
struct LibraryView: View {
    let router: Router

    @Query(sort: \LikedTrack.likedAt, order: .reverse) private var liked: [LikedTrack]
    @Query(sort: \SavedCollection.savedAt, order: .reverse) private var saved: [SavedCollection]
    @Query(sort: \FollowedArtist.followedAt, order: .reverse) private var followed: [FollowedArtist]
    @Query private var playlists: [Playlist]

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            List {
                Section {
                    entry("Playlists", "music.note.list", count: playlists.count, route: .playlists)
                    entry("Liked Songs", "heart.fill", count: liked.count, route: .likedSongs)
                    entry("Albums & Playlists", "square.stack.fill", count: saved.count, route: .saved)
                    entry("Artists", "music.microphone", count: followed.count, route: .following)
                    entry("Recently Played", "clock.fill", count: nil, route: .recentlyPlayed)
                }
                let recentSaves = saved.prefix(6).compactMap(\.collection)
                if !recentSaves.isEmpty {
                    Section("Recently Saved") {
                        ForEach(recentSaves) { collection in
                            Button { router.open(.collection(collection)) } label: {
                                HStack(spacing: DS.Spacing.s) {
                                    ArtworkView(url: collection.artworkURL, size: 56)
                                        .frame(width: 56, height: 56)
                                        .zoomSource(collection.id)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(collection.title).font(DS.Typography.rowTitle).lineLimit(1)
                                        Text(collection.subtitle).font(DS.Typography.rowSubtitle)
                                            .foregroundStyle(DS.Text.tertiary).lineLimit(1)
                                    }
                                }
                                .contentShape(.rect)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .buttonStyle(.plain)
            .navigationTitle("Library")
            .catalogDestinations()
        }
        .environment(router)
    }

    private func entry(_ title: LocalizedStringKey, _ systemImage: String, count: Int?, route: CatalogRoute) -> some View {
        Button { router.open(route) } label: {
            LibraryEntryRow(title: title, systemImage: systemImage, detail: count.map(String.init))
        }
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

struct SavedCollectionsView: View {
    @Query(sort: \SavedCollection.savedAt, order: .reverse) private var saved: [SavedCollection]
    @Environment(Router.self) private var router: Router?

    var body: some View {
        let collections = saved.compactMap(\.collection)
        ScrollView {
            if collections.isEmpty {
                ContentUnavailableView("Nothing Saved Yet", systemImage: "square.stack",
                                       description: Text("Save albums and playlists from their page."))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: DS.Spacing.m)], spacing: DS.Spacing.l) {
                    ForEach(collections) { collection in
                        Button { router?.open(.collection(collection)) } label: { CollectionCard(collection: collection, size: 160) }
                            .buttonStyle(.pressable)
                    }
                }
                .padding(DS.Spacing.m)
            }
        }
        .navigationTitle("Albums & Playlists")
    }
}

struct FollowedArtistsView: View {
    @Query(sort: \FollowedArtist.followedAt, order: .reverse) private var followed: [FollowedArtist]
    @Environment(Router.self) private var router: Router?

    var body: some View {
        let artists = followed.compactMap(\.artist)
        ScrollView {
            if artists.isEmpty {
                ContentUnavailableView("No Artists Yet", systemImage: "music.microphone",
                                       description: Text("Follow artists from their page."))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: DS.Spacing.m)], spacing: DS.Spacing.l) {
                    ForEach(artists) { artist in
                        Button { router?.open(.artist(artist)) } label: { ArtistBubble(artist: artist, size: 110) }
                            .buttonStyle(.pressable)
                    }
                }
                .padding(DS.Spacing.m)
            }
        }
        .navigationTitle("Artists")
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
