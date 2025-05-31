import Foundation

// MARK: - AI Feed Response Models

// Model for API responses (with success field)
struct AIFeedResponse: Codable {
    let success: Bool
    let formatVersion: String
    let generationStats: GenerationStats
    let generationTimestamp: String
    let language: String
    let refreshTimestamp: String
    let reports: [String: TopicReport]
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case formatVersion = "format_version"
        case generationStats = "generation_stats"
        case generationTimestamp = "generation_timestamp"
        case language
        case refreshTimestamp = "refresh_timestamp"
        case reports
        case userId = "user_id"
    }
    
    // Custom initializer for manual creation
    init(success: Bool, formatVersion: String, generationStats: GenerationStats, generationTimestamp: String, language: String, refreshTimestamp: String, reports: [String: TopicReport], userId: String) {
        self.success = success
        self.formatVersion = formatVersion
        self.generationStats = generationStats
        self.generationTimestamp = generationTimestamp
        self.language = language
        self.refreshTimestamp = refreshTimestamp
        self.reports = reports
        self.userId = userId
    }
    
    // Convert reports dictionary to array for UI
    var reportsArray: [TopicReport] {
        return Array(reports.values).sorted { $0.topicName < $1.topicName }
    }
}

// Model for Firestore data (without success field)
struct FirestoreAIFeedData: Codable {
    let formatVersion: String
    let generationStats: GenerationStats
    let generationTimestamp: String
    let language: String
    let refreshTimestamp: String
    let reports: [String: TopicReport]
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case formatVersion = "format_version"
        case generationStats = "generation_stats"
        case generationTimestamp = "generation_timestamp"
        case language
        case refreshTimestamp = "refresh_timestamp"
        case reports
        case userId = "user_id"
    }
    
    // Convert to AIFeedResponse for compatibility
    func toAIFeedResponse() -> AIFeedResponse {
        return AIFeedResponse(
            success: true,
            formatVersion: formatVersion,
            generationStats: generationStats,
            generationTimestamp: generationTimestamp,
            language: language,
            refreshTimestamp: refreshTimestamp,
            reports: reports,
            userId: userId
        )
    }
}

struct GenerationStats: Codable {
    let failedReports: Int
    let successfulReports: Int
    let topicsProcessed: Int
    let totalTopics: Int
    
    enum CodingKeys: String, CodingKey {
        case failedReports = "failed_reports"
        case successfulReports = "successful_reports"
        case topicsProcessed = "topics_processed"
        case totalTopics = "total_topics"
    }
    
    // Custom initializer for manual creation
    init(failedReports: Int, successfulReports: Int, topicsProcessed: Int, totalTopics: Int) {
        self.failedReports = failedReports
        self.successfulReports = successfulReports
        self.topicsProcessed = topicsProcessed
        self.totalTopics = totalTopics
    }
}

struct TopicReport: Identifiable, Codable {
    var id: String { topicName }
    let topicName: String
    let pickupLine: String
    let topicSummary: String
    let subtopics: [String: SubtopicReport]
    let generationStats: TopicGenerationStats?
    
    enum CodingKeys: String, CodingKey {
        case topicName = "topic_name"
        case pickupLine = "pickup_line"
        case topicSummary = "topic_summary"
        case subtopics
        case generationStats = "generation_stats"
    }
    
    // Custom initializer for when topic name is the key (Firestore format)
    init(topicName: String, pickupLine: String, topicSummary: String, subtopics: [String: SubtopicReport], generationStats: TopicGenerationStats? = nil) {
        self.topicName = topicName
        self.pickupLine = pickupLine
        self.topicSummary = topicSummary
        self.subtopics = subtopics
        self.generationStats = generationStats
    }
    
    // Custom decoder to handle both formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode topic_name field first (API format)
        if let topicNameFromField = try container.decodeIfPresent(String.self, forKey: .topicName) {
            self.topicName = topicNameFromField
        } else {
            // If no topic_name field, we'll set it later from the key
            self.topicName = ""
        }
        
        self.pickupLine = try container.decode(String.self, forKey: .pickupLine)
        self.topicSummary = try container.decode(String.self, forKey: .topicSummary)
        self.subtopics = try container.decode([String: SubtopicReport].self, forKey: .subtopics)
        self.generationStats = try container.decodeIfPresent(TopicGenerationStats.self, forKey: .generationStats)
    }
}

struct TopicGenerationStats: Codable {
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case error
    }
}

struct SubtopicReport: Identifiable, Codable {
    var id: String { UUID().uuidString }
    let subtopicSummary: String
    let redditSummary: String
    
    enum CodingKeys: String, CodingKey {
        case subtopicSummary = "subtopic_summary"
        case redditSummary = "reddit_summary"
    }
    
    // Custom initializer for manual creation
    init(subtopicSummary: String, redditSummary: String) {
        self.subtopicSummary = subtopicSummary
        self.redditSummary = redditSummary
    }
}

// MARK: - UI Helper Extensions
extension TopicReport {
    var displayTitle: String {
        return topicName.capitalized
    }
    
    var hasValidContent: Bool {
        return !pickupLine.isEmpty && !topicSummary.isEmpty
    }
    
    var subtopicsArray: [(String, SubtopicReport)] {
        return subtopics.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }
    
    var colorTheme: TopicColorTheme {
        return TopicColorTheme.theme(for: topicName)
    }
    
    // Get article thumbnail URLs for the thumbnail grid
    @MainActor
    var articleThumbnails: [String] {
        // Get thumbnails from AIFeedService
        let articles = AIFeedService.shared.articleData[topicName] ?? []
        print("🔍 TopicReport '\(topicName)': Found \(articles.count) articles in articleData")
        
        let thumbnails = articles.compactMap { $0.thumbnail }.filter { !$0.isEmpty }
        print("🖼️ TopicReport '\(topicName)': Extracted \(thumbnails.count) thumbnails:")
        for (index, thumbnail) in thumbnails.enumerated() {
            print("  [\(index)] \(thumbnail)")
        }
        
        // Deduplicate URLs to prevent showing the same image multiple times
        let uniqueThumbnails = Array(Set(thumbnails))
        print("🎯 TopicReport '\(topicName)': After deduplication: \(uniqueThumbnails.count) unique thumbnails")
        
        let result = Array(uniqueThumbnails.prefix(6)) // Limit to 6 unique thumbnails
        print("✅ TopicReport '\(topicName)': Returning \(result.count) unique thumbnails for display")
        return result
    }
}

extension SubtopicReport {
    var hasRedditContent: Bool {
        return !redditSummary.isEmpty && 
               !redditSummary.contains("No recent Reddit discussions") &&
               !redditSummary.contains("Community insights unavailable")
    }
}

// MARK: - Color Themes
struct TopicColorTheme {
    let primaryColor: String
    let secondaryColor: String
    let gradientColors: [String]
    let iconName: String
    
    static func theme(for topicName: String) -> TopicColorTheme {
        let normalizedTopic = topicName.lowercased()
        
        switch normalizedTopic {
        case "technology":
            return TopicColorTheme(
                primaryColor: "0066FF",
                secondaryColor: "00CCFF",
                gradientColors: ["0066FF", "00CCFF"],
                iconName: "laptopcomputer"
            )
        case "business":
            return TopicColorTheme(
                primaryColor: "00AA55",
                secondaryColor: "66DD88",
                gradientColors: ["00AA55", "66DD88"],
                iconName: "chart.line.uptrend.xyaxis"
            )
        case "health":
            return TopicColorTheme(
                primaryColor: "FF6B6B",
                secondaryColor: "FF8E8E",
                gradientColors: ["FF6B6B", "FF8E8E"],
                iconName: "heart.fill"
            )
        case "science":
            return TopicColorTheme(
                primaryColor: "8B5CF6",
                secondaryColor: "A78BFA",
                gradientColors: ["8B5CF6", "A78BFA"],
                iconName: "atom"
            )
        case "sports":
            return TopicColorTheme(
                primaryColor: "F59E0B",
                secondaryColor: "FCD34D",
                gradientColors: ["F59E0B", "FCD34D"],
                iconName: "sportscourt.fill"
            )
        case "entertainment":
            return TopicColorTheme(
                primaryColor: "EC4899",
                secondaryColor: "F472B6",
                gradientColors: ["EC4899", "F472B6"],
                iconName: "tv.fill"
            )
        case "world":
            return TopicColorTheme(
                primaryColor: "6366F1",
                secondaryColor: "818CF8",
                gradientColors: ["6366F1", "818CF8"],
                iconName: "globe"
            )
        case "nation":
            return TopicColorTheme(
                primaryColor: "DC2626",
                secondaryColor: "EF4444",
                gradientColors: ["DC2626", "EF4444"],
                iconName: "flag.fill"
            )
        case "general":
            return TopicColorTheme(
                primaryColor: "6B7280",
                secondaryColor: "9CA3AF",
                gradientColors: ["6B7280", "9CA3AF"],
                iconName: "newspaper.fill"
            )
        default:
            return TopicColorTheme(
                primaryColor: "6366F1",
                secondaryColor: "818CF8",
                gradientColors: ["6366F1", "818CF8"],
                iconName: "doc.text.fill"
            )
        }
    }
}

// MARK: - Color Extensions
extension String {
    var hexColor: Color {
        let hex = self.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

import SwiftUI

// MARK: - Article Models
struct ArticleData: Identifiable, Codable {
    var id: String { link }
    let title: String
    let thumbnail: String?
    let source: String
    let link: String
    let published: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case thumbnail
        case source
        case link
        case published
    }
    
    init(title: String, thumbnail: String?, source: String, link: String, published: String? = nil) {
        self.title = title
        self.thumbnail = thumbnail
        self.source = source
        self.link = link
        self.published = published
    }
}

struct RedditPost: Identifiable, Codable {
    var id: String { url }
    let title: String
    let url: String
    let score: Int
    let author: String
    let subreddit: String
    let numComments: Int
    let createdUtc: Double
    let selftext: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case url
        case score
        case author
        case subreddit
        case numComments = "num_comments"
        case createdUtc = "created_utc"
        case selftext
    }
} 