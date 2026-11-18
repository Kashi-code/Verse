import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("library.section") private var section: LibrarySection = .songs
    @AppStorage("library.songSort") private var songSort: SongSortOrder = .title
    @AppStorage("library.albumSort") private var albumSort: AlbumSortOrder = .title
    @AppStorage("library.albumLayout") private var albumLayout: CollectionLayout = .grid

    @State private var router = LibraryRouter()
    @State private var searchText = ""
    @State private var isPickingFiles = false
    @State private var isImporting = false
    @State private var importSummary: ImportSummary?

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaBar(edge: .top) { sectionPicker }
                .navigationTitle("Library")
                .searchable(text: $searchText, prompt: Text("Search Library"))
                .toolbar { toolbarContent }
                .libraryDestinations()
        }
        .environment(router)
        .fileImporter(
            isPresented: $isPickingFiles,
            allowedContentTypes: ImportPlanner.contentTypes,
            allowsMultipleSelection: true,
            onCompletion: importFiles
        )
        .alert("Import Finished", isPresented: isShowingSummary, presenting: importSummary) { _ in
            Button("OK", role: .cancel) {}
        } message: { summary in
            Text(summary.message)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .songs:
            SongsListView(sort: songSort, searchText: searchText, onImport: showFilePicker)
        case .albums:
            AlbumsCollectionView(sort: albumSort, layout: albumLayout, searchText: searchText, onImport: showFilePicker)
        case .artists:
            ArtistsListView(searchText: searchText, onImport: showFilePicker)
        case .playlists:
            ContentUnavailableView(
                "No Playlists",
                systemImage: "music.note.list",
                description: Text("Playlists you create will appear here.")
            )
        }
    }

    private var sectionPicker: some View {
        Picker("Library Section", selection: $section) {
            ForEach(LibrarySection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if section == .songs || section == .albums {
            ToolbarItem(placement: .topBarTrailing) {
                viewOptionsMenu
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if isImporting {
                ProgressView()
                    .accessibilityLabel("Importing")
            } else {
                Button("Import Music", systemImage: "plus", action: showFilePicker)
            }
        }
    }

    private var viewOptionsMenu: some View {
        Menu("View Options", systemImage: "arrow.up.arrow.down") {
            if section == .songs {
                Picker("Sort By", selection: $songSort) {
                    ForEach(SongSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
            } else {
                Picker("Sort By", selection: $albumSort) {
                    ForEach(AlbumSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                Picker("Layout", selection: $albumLayout) {
                    Label("Grid", systemImage: "square.grid.2x2").tag(CollectionLayout.grid)
                    Label("List", systemImage: "list.bullet").tag(CollectionLayout.list)
                }
            }
        }
    }

    private var isShowingSummary: Binding<Bool> {
        Binding(
            get: { importSummary != nil },
            set: { if !$0 { importSummary = nil } }
        )
    }

    private func showFilePicker() {
        isPickingFiles = true
    }

    private func importFiles(_ result: Result<[URL], any Error>) {
        guard case .success(let urls) = result, !urls.isEmpty else { return }
        isImporting = true
        let importer = LibraryImporter(catalog: LibraryCatalog(context: modelContext))
        Task {
            let summary = await importer.importFiles(urls)
            isImporting = false
            if summary.needsAttention {
                importSummary = summary
            }
        }
    }
}
