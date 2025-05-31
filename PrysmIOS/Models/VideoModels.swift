import Foundation

// MARK: - Video Models for VideoCacheLink

struct VideoItem: Codable, Identifiable, Equatable {
    let id = UUID()
    let url: String
    let storage_path: String
    let filename: String
    let theme_identifier: String
    let article_title: String
    let created_at: String
    let duration: Double?
    
    enum CodingKeys: String, CodingKey {
        case url
        case storage_path
        case filename
        case theme_identifier
        case article_title
        case created_at
        case duration
    }
    
    // MARK: - Equatable conformance
    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool {
        return lhs.url == rhs.url &&
               lhs.storage_path == rhs.storage_path &&
               lhs.filename == rhs.filename &&
               lhs.article_title == rhs.article_title &&
               lhs.created_at == rhs.created_at
    }
}

struct VideoCacheResponse: Codable {
    let videos: [VideoItem]
    let total_videos: Int
    let user_id: String
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case videos
        case total_videos
        case user_id
        case message
    }
}

struct GenerateVideosRequest: Codable {
    let user_id: String
}

struct GenerateVideosResponse: Codable {
    let success: Bool
    let message: String
    let videos_generated: Int?
} 