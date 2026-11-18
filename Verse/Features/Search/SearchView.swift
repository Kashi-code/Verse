import SwiftUI

struct SearchView: View {
    @Environment(\.catalog) private var catalog
    @Environment(PlayerController.self) private var player
    @State private var model = SearchModel()
    @State private var router = Router()

    var body: some View {
        @Bindable var model = model
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
                        browse
                    } else {
                        results
                    }
                }
                .padding(.vertical, DS.Spacing.m)
            }
            .navigationTitle("Search")
            .searchable(text: $model.query, prompt: Text("Songs, artists, albums"))
            .onSubmit(of: .search) { model.rememberQuery() }
            .task(id: model.query) { await model.search(using: catalog) }
            .catalogDestinations()
        }
        .environment(router)
    }

    // MARK: Empty state

    @ViewBuilder
    private var browse: some View {
        if !model.recentSearches.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                HStack {
                    Text("Recent Searches").font(DS.Typography.sectionTitle)
                    Spacer()
                    Button("Clear") { model.clearRecentSearches() }
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, DS.Spacing.m)
                ScrollView(.horizontal) {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(model.recentSearches, id: \.self) { text in
                            Button(text) { model.query = text }
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, DS.Spacing.s)
                                .padding(.vertical, DS.Spacing.xs)
                                .glassSurface(cornerRadius: 18, shadow: false)
                                .buttonStyle(.pressable)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.m)
                }
                .scrollIndicators(.hidden)
            }
        }

        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Browse").font(DS.Typography.sectionTitle).padding(.horizontal, DS.Spacing.m)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: DS.Spacing.s)], spacing: DS.Spacing.s) {
                ForEach(BrowseGenre.all, id: \.self) { genre in
                    Button { router.open(.genre(genre)) } label: { GenreTile(genre: genre) }
                        .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, DS.Spacing.m)
        }
    }

    // MARK: Results

    @ViewBuilder
    private var results: some View {
        if let results = model.results {
            if results.isEmpty {
                ContentUnavailableView.search(text: model.query)
            } else {
                if let top = results.top {
                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        SectionHeader(title: "Top Result")
                        TopResultCard(result: top) { open(top, songs: results.songs) }
                            .padding(.horizontal, DS.Spacing.m)
                    }
                }
                if !results.songs.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        SectionHeader(title: "Songs")
                        VStack(spacing: DS.Spacing.s) {
                            ForEach(Array(results.songs.prefix(10).enumerated()), id: \.element.id) { index, track in
                                Button {
                                    model.rememberQuery()
                                    player.play(results.songs, startingAt: index, from: .search)
                                } label: {
                                    TrackRow(track: track)
                                }
                                .buttonStyle(.pressable)
                                .contextMenu { TrackContextMenu(track: track) }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.m)
                    }
                }
                if !results.artists.isEmpty {
                    Shelf(title: "Artists", items: results.artists) { artist in
                        Button { model.rememberQuery(); router.open(.artist(artist)) } label: { ArtistBubble(artist: artist, size: 96) }
                            .buttonStyle(.pressable)
                    }
                }
                if !results.collections.isEmpty {
                    Shelf(title: "Albums & Playlists", items: results.collections) { collection in
                        Button { model.rememberQuery(); router.open(.collection(collection)) } label: { CollectionCard(collection: collection, size: 140) }
                            .buttonStyle(.pressable)
                    }
                }
            }
        } else if model.failed {
            ContentUnavailableView("Search Failed", systemImage: "wifi.exclamationmark",
                                   description: Text("Check your connection and try again."))
        } else {
            SkeletonRows()
        }
    }

    private func open(_ result: SearchTopResult, songs: [TrackInfo]) {
        model.rememberQuery()
        switch result {
        case .track(let track):
            player.play(songs, startingAt: songs.firstIndex(of: track) ?? 0, from: .search)
        case .artist(let artist):
            router.open(.artist(artist))
        case .collection(let collection):
            router.open(.collection(collection))
        }
    }
}

private struct GenreTile: View {
    let genre: String

    var body: some View {
        let colors = BrowseGenre.colors(for: genre)
        Text(genre)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .padding(DS.Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .bottomLeading)
            .background(
                LinearGradient(colors: [Color(colors.0), Color(colors.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Border.color, lineWidth: DS.Border.hairline)
            }
    }
}

private struct TopResultCard: View {
    let result: SearchTopResult
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.m) {
                artwork
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title3.weight(.bold)).lineLimit(2)
                    Text(subtitle).font(.subheadline).foregroundStyle(DS.Text.tertiary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: isTrack ? "play.circle.fill" : "chevron.right")
                    .font(isTrack ? .largeTitle : .body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.s)
            .glassSurface(cornerRadius: DS.Radius.panel)
        }
        .buttonStyle(.pressable)
    }

    @ViewBuilder
    private var artwork: some View {
        switch result {
        case .track(let track):
            ArtworkView(url: track.artworkURL, cornerRadius: DS.Radius.card, size: 88).frame(width: 88, height: 88)
        case .artist(let artist):
            ArtworkView(url: artist.imageURL, size: 88, isCircle: true).frame(width: 88, height: 88)
        case .collection(let collection):
            ArtworkView(url: collection.artworkURL, cornerRadius: DS.Radius.card, size: 88).frame(width: 88, height: 88)
        }
    }

    private var isTrack: Bool {
        if case .track = result { true } else { false }
    }

    private var title: String {
        switch result {
        case .track(let track): track.title
        case .artist(let artist): artist.name
        case .collection(let collection): collection.title
        }
    }

    private var subtitle: String {
        switch result {
        case .track(let track): String(localized: "Song · \(track.artist)")
        case .artist(let artist): String(localized: "Artist · \(artist.id.source.displayName)")
        case .collection(let collection):
            collection.kind == .album
                ? String(localized: "Album · \(collection.subtitle)")
                : String(localized: "Playlist · \(collection.subtitle)")
        }
    }
}
