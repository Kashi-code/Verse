import Foundation

/// Response shapes from https://api.audius.co/v1 (checked against the published OpenAPI spec and
/// live responses). Decoded with `convertFromSnakeCase`.
struct AudiusEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T
}

struct AudiusArtwork: Decodable, Sendable, Equatable {
    let small: URL?
    let medium: URL?
    let large: URL?

    enum CodingKeys: String, CodingKey {
        case small = "150x150"
        case medium = "480x480"
        case large = "1000x1000"
    }
}

struct AudiusCoverPhoto: Decodable, Sendable, Equatable {
    let medium: URL?
    let large: URL?

    enum CodingKeys: String, CodingKey {
        case medium = "640x"
        case large = "2000x"
    }
}

struct AudiusUserDTO: Decodable, Sendable {
    let id: String
    let name: String
    let handle: String?
    let isVerified: Bool?
    let followerCount: Int?
    let trackCount: Int?
    let profilePicture: AudiusArtwork?
    let coverPhoto: AudiusCoverPhoto?
}

struct AudiusTrackDTO: Decodable, Sendable {
    struct Access: Decodable, Sendable {
        let stream: Bool?
    }

    let id: String
    let title: String
    let duration: Double?
    let genre: String?
    let mood: String?
    let playCount: Int?
    let artwork: AudiusArtwork?
    let user: AudiusUserDTO
    let isStreamable: Bool?
    let isStreamGated: Bool?
    let isDelete: Bool?
    let isAvailable: Bool?
    let access: Access?
    let allowedApiKeys: [String]?
    let permalink: String?
}

struct AudiusPlaylistDTO: Decodable, Sendable {
    let id: String
    let playlistName: String
    let isAlbum: Bool?
    let artwork: AudiusArtwork?
    let user: AudiusUserDTO
    let trackCount: Int?
    let permalink: String?
}
