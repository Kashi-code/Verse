import SwiftUI

/// Loads something from the catalog for a page, with a skeleton while waiting.
@MainActor
@Observable
final class PageLoader<Value: Sendable> {
    enum State {
        case loading
        case loaded(Value)
        case failed
    }

    private(set) var state: State = .loading

    func load(_ work: @escaping @Sendable () async throws -> Value) async {
        if case .loaded = state { return }
        do {
            state = .loaded(try await work())
        } catch {
            state = .failed
        }
    }
}

/// An album (Apple) or playlist (Audius).
struct CollectionDetailView: View {
    let collection: CatalogCollection

    @Environment(\.catalog) private var catalog
    @Environment(PlayerController.self) private var player
    @Environment(Router.self) private var router: Router?
    @Environment(\.modelContext) private var modelContext
    @State private var loader = PageLoader<[TrackInfo]>()
    @State private var scrollOffset: CGFloat = 0
    @State private var isSaved = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.l) {
                HeroHeader(
                    artworkURL: collection.artworkURL,
                    title: collection.title,
                    subtitle: collection.subtitle,
                    scrollOffset: scrollOffset,
                    onSubtitleTap: ownerAction
                ) {
                    HStack(spacing: DS.Spacing.s) {
                        GlassIconButton(
                            title: isSaved ? "Remove from Library" : "Save to Library",
                            systemImage: isSaved ? "checkmark" : "plus",
                            isOn: isSaved
                        ) {
                            isSaved = UserLibrary(context: modelContext).toggleSaved(collection)
                        }
                        PlayShuffleButtons { shuffled in
                            if case .loaded(let tracks) = loader.state { play(tracks, at: nil, shuffled: shuffled) }
                        }
                        if let url = collection.externalURL {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3.weight(.semibold))
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)
                            .controlSize(.large)
                            .accessibilityLabel("Share")
                        }
                    }
                }
                switch loader.state {
                case .loading:
                    SkeletonRows(count: 8)
                case .failed:
                    ContentUnavailableView("Couldn't Load", systemImage: "wifi.exclamationmark")
                case .loaded(let tracks):
                    TrackList(tracks: tracks, numbered: collection.kind == .album) { index in
                        play(tracks, at: index)
                    }
                    attribution
                }
            }
            .padding(.bottom, DS.Spacing.xl)
        }
        .toolbarTitleDisplayMode(.inline)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
            scrollOffset = offset
        }
        .task {
            isSaved = UserLibrary(context: modelContext).isSaved(collection.id)
            let catalog = catalog
            let collection = collection
            await loader.load { try await catalog.tracks(in: collection) }
        }
    }

    private var ownerAction: (() -> Void)? {
        guard let ownerID = collection.ownerID, let router else { return nil }
        let artist = CatalogArtist(id: ownerID, name: collection.subtitle, imageURL: nil)
        return { router.open(.artist(artist)) }
    }

    @ViewBuilder
    private var attribution: some View {
        if collection.id.source == .apple {
            Text("Previews provided courtesy of Apple Music.")
                .font(.footnote)
                .foregroundStyle(DS.Text.tertiary)
            if let url = collection.externalURL {
                Link("Listen on Apple Music", destination: url)
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    private func play(_ tracks: [TrackInfo], at index: Int?, shuffled: Bool = false) {
        let source: QueueSource = collection.kind == .album ? .album(collection.title) : .playlist(collection.title)
        player.play(tracks, startingAt: index, from: source, shuffled: shuffled)
    }
}

struct ArtistDetailView: View {
    let artist: CatalogArtist

    @Environment(\.catalog) private var catalog
    @Environment(PlayerController.self) private var player
    @Environment(Router.self) private var router: Router?
    @Environment(\.modelContext) private var modelContext
    @State private var loader = PageLoader<ArtistPage>()
    @State private var scrollOffset: CGFloat = 0
    @State private var isFollowing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                HeroHeader(
                    artworkURL: headerImage,
                    title: artist.name,
                    subtitle: artist.id.source.displayName,
                    isCircle: true,
                    scrollOffset: scrollOffset
                ) {
                    HStack(spacing: DS.Spacing.s) {
                        GlassIconButton(
                            title: isFollowing ? "Unfollow" : "Follow",
                            systemImage: isFollowing ? "person.fill.checkmark" : "person.badge.plus",
                            isOn: isFollowing
                        ) {
                            isFollowing = UserLibrary(context: modelContext).toggleFollow(followable)
                        }
                        PlayShuffleButtons { shuffled in
                            if case .loaded(let page) = loader.state {
                                player.play(page.popular, from: .artist(artist.name), shuffled: shuffled)
                            }
                        }
                    }
                }
                switch loader.state {
                case .loading:
                    SkeletonRows(count: 5)
                    SkeletonShelf()
                case .failed:
                    ContentUnavailableView("Couldn't Load", systemImage: "wifi.exclamationmark")
                case .loaded(let page):
                    if !page.popular.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.s) {
                            SectionHeader(title: "Popular")
                            TrackList(tracks: Array(page.popular.prefix(10)), numbered: true) { index in
                                player.play(page.popular, startingAt: index, from: .artist(artist.name))
                            }
                        }
                    }
                    if !page.releases.isEmpty {
                        Shelf(title: "Releases", items: page.releases) { collection in
                            Button { router?.open(.collection(collection)) } label: { CollectionCard(collection: collection) }
                                .buttonStyle(.pressable)
                        }
                    }
                    if !page.playlists.isEmpty {
                        Shelf(title: "Playlists", items: page.playlists) { collection in
                            Button { router?.open(.collection(collection)) } label: { CollectionCard(collection: collection) }
                                .buttonStyle(.pressable)
                        }
                    }
                    if let url = artist.externalURL {
                        Group {
                            if artist.id.source == .apple {
                                Link("Open in Apple Music", destination: url)
                            } else {
                                Link("Open on Audius", destination: url)
                            }
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, DS.Spacing.m)
                    }
                }
            }
            .padding(.bottom, DS.Spacing.xl)
        }
        .toolbarTitleDisplayMode(.inline)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
            scrollOffset = offset
        }
        .task {
            isFollowing = UserLibrary(context: modelContext).isFollowing(artist.id)
            let catalog = catalog
            let artist = artist
            await loader.load { try await catalog.artistPage(for: artist) }
        }
    }

    /// Saved with a picture so the Library can show it.
    private var followable: CatalogArtist {
        var copy = artist
        if copy.imageURL == nil { copy.imageURL = headerImage }
        return copy
    }

    /// Apple artists have no photo in the public catalog; use their top song's cover instead.
    private var headerImage: URL? {
        if let image = artist.imageURL { return image }
        if case .loaded(let page) = loader.state { return page.popular.first?.artworkURL }
        return nil
    }
}

/// Trending songs in one genre (from the Browse tiles).
struct GenreView: View {
    let genre: String

    @Environment(\.catalog) private var catalog
    @Environment(PlayerController.self) private var player
    @State private var loader = PageLoader<[TrackInfo]>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                switch loader.state {
                case .loading:
                    SkeletonRows(count: 10)
                case .failed:
                    ContentUnavailableView("Couldn't Load", systemImage: "wifi.exclamationmark")
                case .loaded(let tracks):
                    PlayShuffleButtons { shuffled in
                        player.play(tracks, from: .playlist(genre), shuffled: shuffled)
                    }
                    .padding(.horizontal, DS.Spacing.m)
                    TrackList(tracks: tracks, numbered: true) { index in
                        player.play(tracks, startingAt: index, from: .playlist(genre))
                    }
                }
            }
            .padding(.vertical, DS.Spacing.m)
        }
        .navigationTitle(genre)
        .task {
            let catalog = catalog
            let genre = genre
            await loader.load { try await catalog.trending(genre: genre) }
        }
    }
}

/// A vertical list of song rows with context menus.
struct TrackList: View {
    let tracks: [TrackInfo]
    var numbered = false
    let onSelect: (Int) -> Void

    var body: some View {
        LazyVStack(spacing: DS.Spacing.s) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                Button { onSelect(index) } label: {
                    TrackRow(track: track, number: numbered ? index + 1 : nil, showsArtwork: !numbered)
                }
                .buttonStyle(.pressable)
                .contextMenu { TrackContextMenu(track: track) }
            }
        }
        .padding(.horizontal, DS.Spacing.m)
    }
}
