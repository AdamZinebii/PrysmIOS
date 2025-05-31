import Foundation
import Combine
import FirebaseFirestore

@MainActor
class AIFeedService: ObservableObject {
    static let shared = AIFeedService()
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var aiFeedData: AIFeedResponse?
    @Published var articleData: [String: [ArticleData]] = [:]
    
    private let db = Firestore.firestore()
    
    // Demo mode for testing UI
    var isDemoMode = false
    
    private init() {}
    
    func fetchAIFeedReports(userId: String) async {
        // Use demo data if in demo mode
        if isDemoMode {
            isLoading = true
            // Simulate network delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            self.aiFeedData = DemoData.sampleAIFeedResponse
            isLoading = false
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            print("Fetching AI Feed data from Firestore for user: \(userId)")
            
            // Fetch document from aifeed collection
            let document = try await db.collection("aifeed").document(userId).getDocument()
            
            guard document.exists else {
                print("No AI Feed document found for user: \(userId)")
                // If no data exists, show a helpful message instead of an error
                self.error = "Aucun rapport AI Feed trouvé. Essayez de rafraîchir pour générer de nouveaux rapports."
                isLoading = false
                return
            }
            
            guard let data = document.data() else {
                throw AIFeedError.invalidData
            }
            
            print("Raw Firestore data keys: \(data.keys)")
            
            // Manually decode the Firestore data to handle the different structure
            let formatVersion = data["format_version"] as? String ?? "1.0"
            let language = data["language"] as? String ?? "en"
            let generationTimestamp = data["generation_timestamp"] as? String ?? ""
            let refreshTimestamp = data["refresh_timestamp"] as? String ?? ""
            let userId = data["user_id"] as? String ?? userId
            
            // Decode generation stats
            var generationStats = GenerationStats(failedReports: 0, successfulReports: 0, topicsProcessed: 0, totalTopics: 0)
            if let statsData = data["generation_stats"] as? [String: Any] {
                generationStats = GenerationStats(
                    failedReports: statsData["failed_reports"] as? Int ?? 0,
                    successfulReports: statsData["successful_reports"] as? Int ?? 0,
                    topicsProcessed: statsData["topics_processed"] as? Int ?? 0,
                    totalTopics: statsData["total_topics"] as? Int ?? 0
                )
            }
            
            // Manually decode reports where topic names are keys
            var reports: [String: TopicReport] = [:]
            if let reportsData = data["reports"] as? [String: [String: Any]] {
                for (topicKey, topicData) in reportsData {
                    // Decode subtopics
                    var subtopics: [String: SubtopicReport] = [:]
                    if let subtopicsData = topicData["subtopics"] as? [String: [String: Any]] {
                        for (subtopicKey, subtopicData) in subtopicsData {
                            let subtopicSummary = subtopicData["subtopic_summary"] as? String ?? ""
                            let redditSummary = subtopicData["reddit_summary"] as? String ?? ""
                            subtopics[subtopicKey] = SubtopicReport(
                                subtopicSummary: subtopicSummary,
                                redditSummary: redditSummary
                            )
                        }
                    }
                    
                    // Decode generation stats for this topic
                    var topicGenerationStats: TopicGenerationStats?
                    if let statsData = topicData["generation_stats"] as? [String: Any] {
                        topicGenerationStats = TopicGenerationStats(
                            error: statsData["error"] as? String
                        )
                    }
                    
                    // Create TopicReport
                    let topicReport = TopicReport(
                        topicName: topicKey,
                        pickupLine: topicData["pickup_line"] as? String ?? "",
                        topicSummary: topicData["topic_summary"] as? String ?? "",
                        subtopics: subtopics,
                        generationStats: topicGenerationStats
                    )
                    
                    reports[topicKey] = topicReport
                }
            }
            
            // Create AIFeedResponse
            self.aiFeedData = AIFeedResponse(
                success: true,
                formatVersion: formatVersion,
                generationStats: generationStats,
                generationTimestamp: generationTimestamp,
                language: language,
                refreshTimestamp: refreshTimestamp,
                reports: reports,
                userId: userId
            )
            
            print("Successfully loaded AI Feed data with \(reports.count) reports")
            
            // Also fetch article data for thumbnails
            print("🚀 About to fetch article data for user: \(userId)")
            if let articles = await fetchArticleData(userId: userId) {
                self.articleData = articles
                print("✅ Successfully loaded article data for \(articles.count) topics")
                print("📊 Article data topics: \(Array(articles.keys))")
            } else {
                print("❌ Failed to load article data - fetchArticleData returned nil")
                self.articleData = [:]
            }
            
        } catch {
            // Handle specific Firestore errors
            if let firestoreError = error as NSError? {
                switch firestoreError.code {
                case 7: // Permission denied
                    self.error = "Permissions insuffisantes. Vérifiez les règles de sécurité Firestore."
                    print("Firestore permission denied. Please check security rules for 'aifeed' collection.")
                case 5: // Not found
                    self.error = "Collection AI Feed non trouvée."
                case 14: // Unavailable
                    self.error = "Service Firestore temporairement indisponible."
                default:
                    self.error = "Erreur Firestore: \(firestoreError.localizedDescription)"
                }
            } else {
                self.error = error.localizedDescription
            }
            
            print("Error fetching AI Feed from Firestore: \(error)")
            
            // If it's a decoding error, provide more details
            if let decodingError = error as? DecodingError {
                print("Decoding error details: \(decodingError)")
                self.error = "Erreur de format des données. Les données pourraient être dans un ancien format."
            }
        }
        
        isLoading = false
    }
    
    func refreshArticles(userId: String) async {
        isLoading = true
        error = nil
        
        // Since we're now reading directly from Firestore, we can simply
        // re-fetch the data from the aifeed collection
        print("Refreshing AI Feed data from Firestore for user: \(userId)")
        
        do {
            // Clear current data first
            self.aiFeedData = nil
            
            // Re-fetch from Firestore
            await fetchAIFeedReports(userId: userId)
            
            print("Articles refreshed successfully from Firestore")
            
        } catch {
            self.error = error.localizedDescription
            print("Error refreshing articles: \(error)")
        }
        
        isLoading = false
    }
    
    func generateCompleteReport(userId: String) async {
        isLoading = true
        error = nil
        
        do {
            // First, try to check if there's existing data in Firestore
            print("Checking for existing AI Feed data in Firestore for user: \(userId)")
            
            let document = try await db.collection("aifeed").document(userId).getDocument()
            
            if document.exists {
                // If data exists, just fetch it
                print("Existing AI Feed data found, fetching from Firestore")
                await fetchAIFeedReports(userId: userId)
            } else {
                // If no data exists, try to generate via API endpoint
                print("No existing data found, attempting to generate new report")
                
                guard let url = URL(string: "https://get-complete-report-endpoint-prysmios.cloudfunctions.net") else {
                    throw AIFeedError.invalidURL
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let requestBody = ["user_id": userId]
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIFeedError.invalidResponse
                }
                
                guard httpResponse.statusCode == 200 else {
                    // If API fails, show a more user-friendly message
                    if httpResponse.statusCode == 404 {
                        throw AIFeedError.serviceUnavailable
                    } else {
                        throw AIFeedError.serverError(httpResponse.statusCode)
                    }
                }
                
                print("Complete report generated successfully")
                
                // After generating report, fetch the updated AI feed from Firestore
                await fetchAIFeedReports(userId: userId)
            }
            
        } catch {
            self.error = error.localizedDescription
            print("Error generating complete report: \(error)")
            
            // If generation fails, try to fetch any existing data
            if self.aiFeedData == nil {
                print("Attempting to fetch any existing data from Firestore")
                await fetchAIFeedReports(userId: userId)
            }
        }
        
        isLoading = false
    }
    
    func fetchArticleData(userId: String) async -> [String: [ArticleData]]? {
        do {
            print("📰 Fetching article data directly from Firebase collection 'articles' for user: \(userId)")
            
            // Fetch from Firebase articles collection
            let articleDoc = try await db.collection("articles").document(userId).getDocument()
            
            print("🔍 Document exists: \(articleDoc.exists)")
            if let data = articleDoc.data() {
                print("📊 Document data keys: \(Array(data.keys))")
                print("📊 Document data size: \(data.count) fields")
            } else {
                print("❌ Document data is nil")
            }
            
            guard articleDoc.exists, let data = articleDoc.data() else {
                print("❌ No articles document found for user: \(userId)")
                return nil
            }
            
            print("✅ Found articles document, extracting thumbnails from topics_data")
            
            // Navigate to topics_data structure
            guard let topicsData = data["topics_data"] as? [String: Any] else {
                print("❌ No topics_data found in articles document")
                return nil
            }
            
            var articlesByTopic: [String: [ArticleData]] = [:]
            
            // Parse each topic
            for (topicName, topicInfo) in topicsData {
                print("🔍 Processing topic: \(topicName)")
                
                guard let topicDict = topicInfo as? [String: Any],
                      let topicData = topicDict["data"] as? [String: Any],
                      let subtopics = topicData["subtopics"] as? [String: Any] else {
                    print("⚠️ Invalid structure for topic: \(topicName)")
                    continue
                }
                
                var topicArticles: [ArticleData] = []
                
                // Parse each subtopic
                for (subtopicName, subtopicInfo) in subtopics {
                    guard let subtopicDict = subtopicInfo as? [String: Any] else { continue }
                    
                    print("🔍 Processing subtopic: \(subtopicName) in topic: \(topicName)")
                    
                    // The articles are in subtopicDict[subtopicName] (same name twice)
                    if let articlesArray = subtopicDict[subtopicName] as? [[String: Any]] {
                        print("📄 Found \(articlesArray.count) articles in subtopic '\(subtopicName)' of topic '\(topicName)'")
                        
                        for articleDict in articlesArray {
                            if let title = articleDict["title"] as? String,
                               let source = articleDict["source"] as? String,
                               let link = articleDict["link"] as? String {
                                
                                let article = ArticleData(
                                    title: title,
                                    thumbnail: articleDict["thumbnail"] as? String,
                                    source: source,
                                    link: link,
                                    published: articleDict["published"] as? String
                                )
                                topicArticles.append(article)
                                
                                // Log thumbnail for debugging
                                if let thumbnail = article.thumbnail {
                                    print("🖼️ Article '\(title)' has thumbnail: \(thumbnail)")
                                } else {
                                    print("📝 Article '\(title)' has no thumbnail")
                                }
                            }
                        }
                    }
                    
                    // Also check in queries for additional articles
                    if let queries = subtopicDict["queries"] as? [String: [[String: Any]]] {
                        print("🔍 Found \(queries.count) queries in subtopic '\(subtopicName)'")
                        for (queryName, queryArticles) in queries {
                            print("📄 Processing query '\(queryName)' with \(queryArticles.count) articles")
                            for articleDict in queryArticles {
                                if let title = articleDict["title"] as? String,
                                   let source = articleDict["source"] as? String,
                                   let link = articleDict["link"] as? String {
                                    
                                    let article = ArticleData(
                                        title: title,
                                        thumbnail: articleDict["thumbnail"] as? String,
                                        source: source,
                                        link: link,
                                        published: articleDict["published"] as? String
                                    )
                                    topicArticles.append(article)
                                    
                                    // Log thumbnail for debugging
                                    if let thumbnail = article.thumbnail {
                                        print("🖼️ Query article '\(title)' has thumbnail: \(thumbnail)")
                                    } else {
                                        print("📝 Query article '\(title)' has no thumbnail")
                                    }
                                }
                            }
                        }
                    }
                }
                
                if !topicArticles.isEmpty {
                    // Limit to 6 articles per topic for thumbnail grid
                    articlesByTopic[topicName] = Array(topicArticles.prefix(6))
                    print("✅ Stored \(topicArticles.count) articles for topic '\(topicName)' (displaying \(articlesByTopic[topicName]!.count))")
                } else {
                    print("⚠️ No articles found for topic '\(topicName)'")
                }
            }
            
            print("🎯 Successfully extracted article data for \(articlesByTopic.count) topics")
            print("📊 Topics with articles: \(Array(articlesByTopic.keys))")
            for (topic, articles) in articlesByTopic {
                print("  - \(topic): \(articles.count) articles")
            }
            return articlesByTopic
            
        } catch {
            print("❌ Error fetching article data from Firebase: \(error)")
            return nil
        }
    }
}

enum AIFeedError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError
    case noDataFound
    case invalidData
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .noDataFound:
            return "No AI feed data found for this user"
        case .invalidData:
            return "Invalid data format in database"
        case .serviceUnavailable:
            return "Service unavailable"
        }
    }
} 