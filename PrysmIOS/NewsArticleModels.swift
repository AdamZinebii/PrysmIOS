import Foundation

struct NewsArticleResponse: Codable {
    let articles: [NewsArticle]
    let generatedAt: String
    let cached: Bool
    let cacheAgeHours: Double?
    
    enum CodingKeys: String, CodingKey {
        case articles
        case generatedAt
        case cached
        case cacheAgeHours = "cache_age_hours"
    }
}

struct NewsArticle: Identifiable, Codable {
    let id = UUID()
    let title: String
    let summary: String
    let source: String?
    let link: String?
    let thumbnail: String?
    let topic: String?
    
    // CodingKeys pour correspondre à la structure de l'API
    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case source
        case link
        case thumbnail
        case topic
    }
}
