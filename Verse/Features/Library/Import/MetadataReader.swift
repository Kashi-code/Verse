import AVFoundation
import Foundation

struct TrackMetadata: Sendable, Equatable {
    var title: String?
    var artist: String?
    var albumTitle: String?
    var albumArtist: String?
    var trackNumber: Int?
    var discNumber: Int?
    var year: Int?
    var duration: TimeInterval = 0
    var lyrics: String?
    var artworkData: Data?
}

/// Reads tags from an audio file with AVFoundation (ID3, iTunes/MP4 and QuickTime keys).
enum MetadataReader {
    @concurrent
    static func read(from url: URL) async throws -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        let (duration, commonItems, allItems) = try await asset.load(.duration, .commonMetadata, .metadata)

        var metadata = TrackMetadata()
        let seconds = duration.seconds
        metadata.duration = seconds.isFinite ? max(seconds, 0) : 0

        // Format-specific items first: they are more precise than the common key space.
        for item in allItems + commonItems {
            guard let identifier = item.identifier else { continue }
            switch identifier {
            case .iTunesMetadataSongName, .id3MetadataTitleDescription, .quickTimeMetadataTitle,
                 .commonIdentifierTitle:
                if metadata.title == nil {
                    metadata.title = MetadataParsing.cleaned(try? await item.load(.stringValue))
                }
            case .iTunesMetadataArtist, .id3MetadataLeadPerformer, .quickTimeMetadataArtist,
                 .commonIdentifierArtist:
                if metadata.artist == nil {
                    metadata.artist = MetadataParsing.cleaned(try? await item.load(.stringValue))
                }
            case .iTunesMetadataAlbum, .id3MetadataAlbumTitle, .quickTimeMetadataAlbum,
                 .commonIdentifierAlbumName:
                if metadata.albumTitle == nil {
                    metadata.albumTitle = MetadataParsing.cleaned(try? await item.load(.stringValue))
                }
            case .iTunesMetadataAlbumArtist, .id3MetadataBand:
                if metadata.albumArtist == nil {
                    metadata.albumArtist = MetadataParsing.cleaned(try? await item.load(.stringValue))
                }
            case .iTunesMetadataTrackNumber:
                if metadata.trackNumber == nil, let data = try? await item.load(.dataValue) {
                    metadata.trackNumber = MetadataParsing.iTunesPosition(from: data)
                }
            case .id3MetadataTrackNumber:
                if metadata.trackNumber == nil, let string = try? await item.load(.stringValue) {
                    metadata.trackNumber = MetadataParsing.position(from: string)
                }
            case .iTunesMetadataDiscNumber:
                if metadata.discNumber == nil, let data = try? await item.load(.dataValue) {
                    metadata.discNumber = MetadataParsing.iTunesPosition(from: data)
                }
            case .id3MetadataPartOfASet:
                if metadata.discNumber == nil, let string = try? await item.load(.stringValue) {
                    metadata.discNumber = MetadataParsing.position(from: string)
                }
            case .iTunesMetadataReleaseDate, .id3MetadataYear, .id3MetadataRecordingTime,
                 .id3MetadataReleaseTime, .commonIdentifierCreationDate:
                if metadata.year == nil, let string = try? await item.load(.stringValue) {
                    metadata.year = MetadataParsing.year(from: string)
                }
            case .iTunesMetadataLyrics, .id3MetadataUnsynchronizedLyric:
                if metadata.lyrics == nil {
                    metadata.lyrics = MetadataParsing.cleaned(try? await item.load(.stringValue))
                }
            case .iTunesMetadataCoverArt, .id3MetadataAttachedPicture, .commonIdentifierArtwork:
                if metadata.artworkData == nil, let data = try? await item.load(.dataValue), !data.isEmpty {
                    metadata.artworkData = data
                }
            default:
                break
            }
        }
        return metadata
    }
}
