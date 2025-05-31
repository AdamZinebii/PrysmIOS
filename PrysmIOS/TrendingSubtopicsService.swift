import Foundation

// MARK: - Models
struct TrendingAPIResponse: Codable {
    let success: Bool
    let topic: String
    let articlesAnalyzed: Int
    let subtopics: [String]
    let usage: TrendingTokenUsage?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, topic, subtopics, usage, error
        case articlesAnalyzed = "articles_analyzed"
    }
}

struct TrendingTokenUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct TrendingSubtopicsRequest: Codable {
    let topic: String
    let lang: String
    let country: String
    let maxArticles: Int
    
    enum CodingKeys: String, CodingKey {
        case topic, lang, country
        case maxArticles = "max_articles"
    }
}

struct SubtopicTrendingRequest: Codable {
    let subtopicTitle: String
    let subtopicQuery: String
    let subreddits: [String]
    let lang: String
    let country: String
    let maxArticles: Int
    
    enum CodingKeys: String, CodingKey {
        case subtopicTitle = "subtopic_title"
        case subtopicQuery = "subtopic_query"
        case subreddits, lang, country
        case maxArticles = "max_articles"
    }
}

struct SubtopicTrendingResponse: Codable {
    let success: Bool
    let subtopic: String
    let gnewsArticlesCount: Int
    let redditPostsCount: Int
    let trendingTopics: [String]
    let usage: TrendingTokenUsage?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, subtopic, usage, error
        case gnewsArticlesCount = "gnews_articles_count"
        case redditPostsCount = "reddit_posts_count"
        case trendingTopics = "trending_topics"
    }
}

// MARK: - Service
class TrendingSubtopicsService: ObservableObject {
    static let shared = TrendingSubtopicsService()
    
    private let baseURL = "https://us-central1-prysmios.cloudfunctions.net"
    private let session = URLSession.shared
    
    private init() {}
    
    func fetchTrendingSubtopics(
        for topic: String,
        language: String = "en",
        country: String = "us",
        maxArticles: Int = 10
    ) async throws -> [String] {
        
        // Map topic to backend category format
        let backendTopic = mapToBackendCategory(topic)
        
        let url = URL(string: "\(baseURL)/get_trending_subtopics")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = TrendingSubtopicsRequest(
            topic: backendTopic,
            lang: language,
            country: country,
            maxArticles: maxArticles
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrendingSubtopicsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TrendingSubtopicsError.httpError(httpResponse.statusCode)
        }
        
        let trendingResponse = try JSONDecoder().decode(TrendingAPIResponse.self, from: data)
        
        if !trendingResponse.success {
            throw TrendingSubtopicsError.apiError(trendingResponse.error ?? "Unknown error")
        }
        
        return trendingResponse.subtopics
    }
    
    func fetchTrendingForSubtopic(
        title: String,
        query: String,
        subreddits: [String],
        language: String = "en",
        country: String = "us",
        maxArticles: Int = 10
    ) async throws -> [String] {
        
        let url = URL(string: "\(baseURL)/get_trending_for_subtopic")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = SubtopicTrendingRequest(
            subtopicTitle: title,
            subtopicQuery: query,
            subreddits: subreddits,
            lang: language,
            country: country,
            maxArticles: maxArticles
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrendingSubtopicsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TrendingSubtopicsError.httpError(httpResponse.statusCode)
        }
        
        let trendingResponse = try JSONDecoder().decode(SubtopicTrendingResponse.self, from: data)
        
        if !trendingResponse.success {
            throw TrendingSubtopicsError.apiError(trendingResponse.error ?? "Unknown error")
        }
        
        return trendingResponse.trendingTopics
    }
    
    private func mapToBackendCategory(_ frontendCategory: String) -> String {
        // Create separate mappings to avoid duplicate keys
        var categoryMappings: [String: String] = [:]
        
        // English mappings
        let englishMappings: [String: String] = [
            "General": "general",
            "World": "world", 
            "Nation": "nation",
            "Business": "business",
            "Technology": "technology",
            "Entertainment": "entertainment",
            "Sports": "sports",
            "Science": "science",
            "Health": "health"
        ]
        
        // French mappings (from fr.lproj/Localizable.strings)
        let frenchMappings: [String: String] = [
            "Général": "general",
            "Monde": "world",
            "National": "nation", 
            "Économie": "business",
            "Technologie": "technology",
            "Divertissement": "entertainment",
            "Sports": "sports",  // Same as English but handled separately
            "Science": "science", // Same as English but handled separately
            "Santé": "health"
        ]
        
        // Spanish mappings (from es.lproj/Localizable.strings)
        let spanishMappings: [String: String] = [
            "General": "general", // Same as English but handled separately
            "Mundo": "world",
            "Nacional": "nation",
            "Negocios": "business",
            "Tecnología": "technology",
            "Entretenimiento": "entertainment",
            "Deportes": "sports",
            "Ciencia": "science",
            "Salud": "health"
        ]
        
        // Arabic mappings (from ar.lproj/Localizable.strings)
        let arabicMappings: [String: String] = [
            "عام": "general",
            "العالم": "world",
            "وطني": "nation",
            "أعمال": "business",
            "تكنولوجيا": "technology",
            "ترفيه": "entertainment",
            "رياضة": "sports",
            "علوم": "science",
            "صحة": "health"
        ]
        
        // Merge all mappings (later ones override earlier ones if there are conflicts)
        categoryMappings.merge(englishMappings) { _, new in new }
        categoryMappings.merge(frenchMappings) { _, new in new }
        categoryMappings.merge(spanishMappings) { _, new in new }
        categoryMappings.merge(arabicMappings) { _, new in new }
        
        return categoryMappings[frontendCategory] ?? frontendCategory.lowercased()
    }
}

// MARK: - Errors
enum TrendingSubtopicsError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        case .networkError:
            return "Network connection error"
        }
    }
} 