import SwiftData
import SwiftUI

// MARK: Covers and cards

/// Four covers in a 2×2 grid, one cover when there are fewer, or a placeholder.
struct PlaylistMosaic: View {
    let urls: [URL]
    var size: CGFloat
    var cornerRadius: CGFloat = DS.Radius.card

    var body: some View {
        Group {
            if urls.count >= 4 {
                let half = size / 2
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        tile(urls[0], half)
                        tile(urls[1], half)
                    }
                    GridRow {
                        tile(urls[2], half)
                        tile(urls[3], half)
                    }
                }
            } else if let first = urls.first {
                ArtworkView(url: first, cornerRadius: 0, size: size)
            } else {
                LinearGradient(colors: [.indigo, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        Image(systemName: "music.note.list")
                            .font(.system(size: size * 0.3, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private func tile(_ url: URL, _ side: CGFloat) -> some View {
        ArtworkView(url: url, cornerRadius: 0, size: side)
            .frame(width: side, height: side)
    }
}

struct PlaylistCard: View {
    let playlist: Playlist
    var size: CGFloat = DS.Size.cardArtwork

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            PlaylistMosaic(urls: playlist.coverURLs, size: size)
                .zoomSource(AnyHashable(UserPlaylistRoute.zoomID(playlist.id)))
                .shadow(color: DS.Shadow.color, radius: 10, y: 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(playlist.entries.count) songs")
                    .font(.footnote)
                    .foregroundStyle(DS.Text.tertiary)
            }
            .frame(width: size, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A mix cover: the mosaic with its name on a dark fade.
struct MixCard: View {
    let mix: Mix
    var size: CGFloat = DS.Size.cardArtwork

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            PlaylistMosaic(urls: mix.coverURLs, size: size)
                .overlay(alignment: .bottomLeading) {
                    Text(mix.title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(DS.Spacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .zoomSource(AnyHashable(MixRoute.zoomID(mix.id)))
                .shadow(color: DS.Shadow.color, radius: 10, y: 5)
            Text(mix.subtitle)
                .font(.footnote)
                .foregroundStyle(DS.Text.tertiary)
                .lineLimit(2)
                .frame(width: size, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

enum UserPlaylistRoute {
    static func zoomID(_ id: UUID) -> String { "user-playlist:\(id.uuidString)" }
}

enum MixRoute {
    static func zoomID(_ id: String) -> String { "mix:\(id)" }
}

// MARK: Pages

/// All of the user's own playlists.
struct PlaylistsView: View {
    @Query(sort: \Playlist.dateModified, order: .reverse) private var playlists: [Playlist]
    @Environment(Router.self) private var router: Router?
    @Environment(\.modelContext) private var modelContext
    @State private var isNaming = false
    @State private var newName = ""

    var body: some View {
        List {
            Button { isNaming = true } label: {
                Label("New Playlist", systemImage: "plus")
                    .font(DS.Typography.rowTitle)
            }
            ForEach(playlists) { playlist in
                Button { router?.open(.userPlaylist(playlist.id)) } label: {
                    HStack(spacing: DS.Spacing.s) {
                        PlaylistMosaic(urls: playlist.coverURLs, size: 56, cornerRadius: DS.Radius.control)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.name).font(DS.Typography.rowTitle).lineLimit(1)
                            Text("\(playlist.entries.count) songs").font(DS.Typography.rowSubtitle)
                                .foregroundStyle(DS.Text.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                let library = UserLibrary(context: modelContext)
                offsets.map { playlists[$0] }.forEach(library.delete)
            }
        }
        .overlay {
            if playlists.isEmpty {
                ContentUnavailableView("No Playlists Yet", systemImage: "music.note.list",
                                       description: Text("Make one here, or use Add to Playlist on any song."))
                    .allowsHitTesting(false)
                    .padding(.top, 120)
            }
        }
        .navigationTitle("Playlists")
        .newPlaylistAlert(isPresented: $isNaming, name: $newName) { name in
            let playlist = UserLibrary(context: modelContext).createPlaylist(named: name)
            router?.open(.userPlaylist(playlist.id))
        }
    }
}

/// One of the user's playlists: play, reorder, remove, rename, delete.
struct UserPlaylistDetailView: View {
    @Query private var matches: [Playlist]
    @Environment(PlayerController.self) private var player
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isRenaming = false
    @State private var isConfirmingDelete = false
    @State private var newName = ""

    init(id: UUID) {
        _matches = Query(filter: #Predicate<Playlist> { $0.id == id })
    }

    var body: some View {
        if let playlist = matches.first {
            content(playlist)
        } else {
            ContentUnavailableView("Playlist Deleted", systemImage: "music.note.list")
        }
    }

    private func content(_ playlist: Playlist) -> some View {
        let entries = playlist.orderedEntries
        let tracks = entries.compactMap(\.track)
        return List {
            VStack(spacing: DS.Spacing.m) {
                PlaylistMosaic(urls: playlist.coverURLs, size: 220, cornerRadius: DS.Radius.panel)
                    .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, y: DS.Shadow.y)
                VStack(spacing: 4) {
                    Text(playlist.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("\(tracks.count) songs")
                        .font(.subheadline)
                        .foregroundStyle(DS.Text.tertiary)
                }
                if !tracks.isEmpty {
                    PlayShuffleButtons { shuffled in
                        player.play(tracks, from: .playlist(playlist.name), shuffled: shuffled)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(entries) { entry in
                if let track = entry.track {
                    Button {
                        player.play(tracks, startingAt: tracks.firstIndex(of: track), from: .playlist(playlist.name))
                    } label: {
                        TrackRow(track: track)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { TrackContextMenu(track: track) }
                    .listRowBackground(Color.clear)
                }
            }
            .onDelete { offsets in
                UserLibrary(context: modelContext).removeEntries(at: offsets, from: playlist)
            }
            .onMove { offsets, destination in
                UserLibrary(context: modelContext).moveEntries(fromOffsets: offsets, toOffset: destination, in: playlist)
            }

            if tracks.isEmpty {
                ContentUnavailableView("No Songs Yet", systemImage: "text.badge.plus",
                                       description: Text("Long-press any song and choose Add to Playlist."))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !tracks.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Rename", systemImage: "pencil") {
                        newName = playlist.name
                        isRenaming = true
                    }
                    Button("Add to Queue", systemImage: "text.line.last.and.arrowtriangle.forward") {
                        player.addToQueue(tracks)
                    }
                    .disabled(tracks.isEmpty)
                    Divider()
                    Button("Delete Playlist", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                }
            }
        }
        .alert("Rename Playlist", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { UserLibrary(context: modelContext).rename(playlist, to: newName) }
        }
        .confirmationDialog("Delete “\(playlist.name)”?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Playlist", role: .destructive) {
                dismiss()
                UserLibrary(context: modelContext).delete(playlist)
            }
        } message: {
            Text("The songs stay in your library and in their catalogs.")
        }
    }
}

/// A "Made for You" mix, filled from the catalog when it opens.
struct MixDetailView: View {
    let mix: Mix

    @Environment(\.catalog) private var catalog
    @Environment(PlayerController.self) private var player
    @State private var loader = PageLoader<[TrackInfo]>()

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.l) {
                VStack(spacing: DS.Spacing.m) {
                    MixCard(mix: mix, size: 220)
                        .allowsHitTesting(false)
                    Text(mix.title).font(.title2.bold())
                }
                .padding(.top, DS.Spacing.m)

                switch loader.state {
                case .loading:
                    SkeletonRows(count: 8)
                case .failed:
                    ContentUnavailableView("Couldn't Load", systemImage: "wifi.exclamationmark")
                case .loaded(let tracks):
                    PlayShuffleButtons { shuffled in
                        player.play(tracks, from: .playlist(mix.title), shuffled: shuffled)
                    }
                    .padding(.horizontal, DS.Spacing.m)
                    TrackList(tracks: tracks) { index in
                        player.play(tracks, startingAt: index, from: .playlist(mix.title))
                    }
                }
            }
            .padding(.bottom, DS.Spacing.xl)
        }
        .toolbarTitleDisplayMode(.inline)
        .task {
            let catalog = catalog
            let mix = mix
            await loader.load { await MixBuilder.tracks(for: mix, catalog: catalog) }
        }
    }
}

// MARK: Add to playlist

/// Songs waiting for the user to pick a playlist.
struct TrackSelection: Identifiable {
    let id = UUID()
    let tracks: [TrackInfo]
}

/// Lets any context menu open the "Add to Playlist" sheet. Each presenting screen hosts its own.
@MainActor
@Observable
final class PlaylistPicker {
    var selection: TrackSelection?

    func present(_ tracks: [TrackInfo]) {
        guard !tracks.isEmpty else { return }
        selection = TrackSelection(tracks: tracks)
    }
}

private struct PlaylistPickerHost: ViewModifier {
    @State private var picker = PlaylistPicker()

    func body(content: Content) -> some View {
        @Bindable var picker = picker
        content
            .environment(picker)
            .sheet(item: $picker.selection) { selection in
                AddToPlaylistSheet(tracks: selection.tracks)
            }
    }
}

extension View {
    func playlistPickerHost() -> some View {
        modifier(PlaylistPickerHost())
    }

    func newPlaylistAlert(isPresented: Binding<Bool>, name: Binding<String>, onCreate: @escaping (String) -> Void) -> some View {
        alert("New Playlist", isPresented: isPresented) {
            TextField("Name", text: name)
            Button("Cancel", role: .cancel) { name.wrappedValue = "" }
            Button("Create") {
                onCreate(name.wrappedValue)
                name.wrappedValue = ""
            }
        }
    }
}

struct AddToPlaylistSheet: View {
    let tracks: [TrackInfo]

    @Query(sort: \Playlist.dateModified, order: .reverse) private var playlists: [Playlist]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isNaming = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Button { isNaming = true } label: {
                    Label("New Playlist", systemImage: "plus")
                        .font(DS.Typography.rowTitle)
                }
                ForEach(playlists) { playlist in
                    Button {
                        UserLibrary(context: modelContext).add(tracks, to: playlist)
                        dismiss()
                    } label: {
                        HStack(spacing: DS.Spacing.s) {
                            PlaylistMosaic(urls: playlist.coverURLs, size: 44, cornerRadius: DS.Radius.control)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name).font(DS.Typography.rowTitle).lineLimit(1)
                                Text("\(playlist.entries.count) songs").font(DS.Typography.rowSubtitle)
                                    .foregroundStyle(DS.Text.tertiary)
                            }
                            Spacer(minLength: 0)
                            if containsAll(playlist) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .accessibilityLabel("Already added")
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(containsAll(playlist))
                }
            }
            .navigationTitle("Add to Playlist")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .newPlaylistAlert(isPresented: $isNaming, name: $newName) { name in
                UserLibrary(context: modelContext).createPlaylist(named: name, with: tracks)
                dismiss()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func containsAll(_ playlist: Playlist) -> Bool {
        let keys = Set(playlist.entries.map(\.trackKey))
        return tracks.allSatisfy { keys.contains($0.id.key) }
    }
}
