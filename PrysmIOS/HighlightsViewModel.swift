import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class HighlightsViewModel: ObservableObject {
    @Published var newsArticles: [NewsArticle] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    private let cacheExpirationInterval: TimeInterval = 21600 // 6 hours in seconds
    
    init() {
        // Remove cache loading from init since highlights use different data structure
    }
    
    func fetchHighlights(userId: String, language: String? = nil) async {
        // Start loading immediately without checking cache since highlights use different API
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            var components = URLComponents(string: "https://us-central1-prysmios.cloudfunctions.net/get_news_vision")
            var queryItems = [URLQueryItem(name: "user_id", value: userId)]
            if let language = language {
                // S'assurer que le paramètre de langue est correctement encodé
                let encodedLanguage = language.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? language
                queryItems.append(URLQueryItem(name: "language", value: encodedLanguage))
            }
            
            components?.queryItems = queryItems
            
            guard let url = components?.url else {
                DispatchQueue.main.async {
                    self.error = "Invalid URL"
                    self.isLoading = false
                }
                return
            }
            
            print("DEBUG: Fetching highlights from API with URL: \(url)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 290
            request.setValue("*", forHTTPHeaderField: "Origin")
            request.setValue("Bearer anonymous", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let responseText = String(data: data, encoding: .utf8) ?? "No response body"
                DispatchQueue.main.async {
                    self.error = "Failed to load highlights: \(responseText)"
                    self.isLoading = false
                }
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(NewsArticleResponse.self, from: data)
            
            print("DEBUG: Successfully fetched \(result.articles.count) articles from API")
            
            DispatchQueue.main.async {
                self.newsArticles = result.articles
                self.isLoading = false
            }
        } catch {
            print("DEBUG: Error in fetchHighlights: \(error)")
            DispatchQueue.main.async {
                self.error = "Error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
