import Foundation

enum SongSortOrder: String, CaseIterable, Identifiable, Sendable {
    case title, artist, album, recentlyAdded

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .title: "Title"
        case .artist: "Artist"
        case .album: "Album"
        case .recentlyAdded: "Recently Added"
        }
    }

    var descriptors: [SortDescriptor<Song>] {
        switch self {
        case .title:
            [SortDescriptor(\Song.title, comparator: .localizedStandard)]
        case .artist:
            [SortDescriptor(\Song.artistName, comparator: .localizedStandard),
             SortDescriptor(\Song.title, comparator: .localizedStandard)]
        case .album:
            [SortDescriptor(\Song.albumTitle, comparator: .localizedStandard),
             SortDescriptor(\Song.discNumber),
             SortDescriptor(\Song.trackNumber)]
        case .recentlyAdded:
            [SortDescriptor(\Song.dateAdded, order: .reverse)]
        }
    }
}

enum AlbumSortOrder: String, CaseIterable, Identifiable, Sendable {
    case title, artist, year, recentlyAdded

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .title: "Title"
        case .artist: "Artist"
        case .year: "Year"
        case .recentlyAdded: "Recently Added"
        }
    }

    var descriptors: [SortDescriptor<Album>] {
        switch self {
        case .title:
            [SortDescriptor(\Album.title, comparator: .localizedStandard)]
        case .artist:
            [SortDescriptor(\Album.artistName, comparator: .localizedStandard),
             SortDescriptor(\Album.title, comparator: .localizedStandard)]
        case .year:
            [SortDescriptor(\Album.year, order: .reverse),
             SortDescriptor(\Album.title, comparator: .localizedStandard)]
        case .recentlyAdded:
            [SortDescriptor(\Album.dateAdded, order: .reverse)]
        }
    }
}

enum CollectionLayout: String, CaseIterable, Identifiable, Sendable {
    case grid, list

    var id: Self { self }
}
