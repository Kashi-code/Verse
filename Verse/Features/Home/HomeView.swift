import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.catalog) private var catalog
    @Environment(PlayerController.self) private var player
    @State private var model = HomeModel()
    let router: Router
    @State private var isShowingSettings = false

    @Query(HomeView.historyDescriptor) private var history: [PlayHistory]
    @Query(sort: \Playlist.dateModified, order: .reverse) private var playlists: [Playlist]
    @State private var mixes: [Mix] = []
    @State private var recentlyPlayed: [TrackInfo] = []

    static var historyDescriptor: FetchDescriptor<PlayHistory> {
        var descriptor = FetchDescriptor<PlayHistory>(sortBy: [SortDescriptor(\.playedAt, order: .reverse)])
        descriptor.fetchLimit = 300
        return descriptor
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    Text(HomeModel.greeting())
                        .font(DS.Typography.pageTitle)
                        .tracking(-0.5)
                        .padding(.horizontal, DS.Spacing.m)
                        .accessibilityAddTraits(.isHeader)
                    content
                }
                .padding(.vertical, DS.Spacing.m)
            }
            .refreshable { await model.load(using: catalog, force: true) }
            .task { await model.load(using: catalog) }
            .onChange(of: history.first?.playedAt, initial: true) { rebuildFromHistory() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                }
            }
            .sheet(isPresented: $isShowingSettings) { SettingsView() }
            .catalogDestinations()
        }
        .environment(router)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            SkeletonShelf(cardSize: DS.Size.heroArtwork)
            SkeletonShelf()
            SkeletonShelf()
        case .failed:
            ContentUnavailableView {
                Label("Couldn't Load Music", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and pull to refresh.")
            } actions: {
                Button("Try Again") { Task { await model.load(using: catalog, force: true) } }
                    .buttonStyle(.glass)
            }
        case .loaded(let feed):
            loaded(feed)
        }
    }

    @ViewBuilder
    private func loaded(_ feed: HomeFeed) -> some View {
        if !feed.trending.isEmpty {
            Shelf(title: "Trending Now", items: feed.trending) { track in
                Button { play(track, in: feed.trending, source: .songs) } label: { HeroTrackCard(track: track) }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("trending-card")
                    .contextMenu { TrackContextMenu(track: track) }
            }
        }

        let recent = recentlyPlayed
        if !recent.isEmpty {
            Shelf(title: "Recently Played", items: recent) { track in
                Button { play(track, in: recent, source: .songs) } label: { TrackCard(track: track) }
                    .buttonStyle(.pressable)
                    .contextMenu { TrackContextMenu(track: track) }
            }
        }

        if !mixes.isEmpty {
            Shelf(title: "Made for You", items: mixes) { mix in
                Button { router.open(.mix(mix)) } label: { MixCard(mix: mix) }
                    .buttonStyle(.pressable)
            }
        }

        if !playlists.isEmpty {
            Shelf(title: "Your Playlists", items: Array(playlists.prefix(12))) { playlist in
                Button { router.open(.userPlaylist(playlist.id)) } label: { PlaylistCard(playlist: playlist) }
                    .buttonStyle(.pressable)
            }
        }

        if !feed.topSongs.isEmpty {
            Shelf(title: "Top Songs", items: feed.topSongs) { track in
                Button { play(track, in: feed.topSongs, source: .songs) } label: { TrackCard(track: track) }
                    .buttonStyle(.pressable)
                    .contextMenu { TrackContextMenu(track: track) }
            }
        }

        ForEach(feed.genres) { shelf in
            Shelf(title: LocalizedStringKey(shelf.genre), items: shelf.tracks) { track in
                Button { play(track, in: shelf.tracks, source: .playlist(shelf.genre)) } label: { TrackCard(track: track) }
                    .buttonStyle(.pressable)
                    .contextMenu { TrackContextMenu(track: track) }
            }
        }

        if !feed.topArtists.isEmpty {
            Shelf(title: "Top Artists", items: feed.topArtists) { artist in
                Button { router.open(.artist(artist)) } label: { ArtistBubble(artist: artist) }
                    .buttonStyle(.pressable)
            }
        }

        if !feed.playlists.isEmpty {
            Shelf(title: "Popular Playlists", items: feed.playlists) { collection in
                Button { router.open(.collection(collection)) } label: { CollectionCard(collection: collection) }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("playlist-card")
            }
        }
    }

    /// Decoding snapshots is not free, so this runs only when a new play is recorded.
    private func rebuildFromHistory() {
        var seen = Set<String>()
        recentlyPlayed = history
            .filter { seen.insert($0.trackKey).inserted }
            .prefix(15)
            .compactMap(\.track)
        mixes = MixBuilder.mixes(from: history.compactMap(\.track))
    }

    private func play(_ track: TrackInfo, in tracks: [TrackInfo], source: QueueSource) {
        let index = tracks.firstIndex(of: track) ?? 0
        player.play(tracks, startingAt: index, from: source)
    }
}
