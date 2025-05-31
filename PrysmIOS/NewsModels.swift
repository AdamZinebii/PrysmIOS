import Foundation

struct StructuredNewsSummaryResponse: Codable {
    let sections: [NewsSection]
    let generatedAt: String
    let cached: Bool
    let rawSummaryHeader: String
    let globalAudioSummaryUrl: String?
}

struct NewsSection: Identifiable, Codable {
    let id = UUID()
    let type: String
    let title: String
    let contentMarkdown: String
    let sources: [NewsSource]?
    let subtopics: [Subtopic]?
}

struct NewsSource: Identifiable, Codable {
    let id = UUID()
    let title: String
    let link: String
    let sourceName: String
    let published: String?
    let thumbnail: String?
    let thumbnailSmall: String?
}

struct Subtopic: Identifiable, Codable {
    let id = UUID()
    let title: String
    let contentMarkdown: String
    let sources: [String]?
} 