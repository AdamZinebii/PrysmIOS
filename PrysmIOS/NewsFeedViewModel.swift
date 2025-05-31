import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class NewsFeedViewModel: ObservableObject {
    @Published var newsSections: [NewsSection] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var globalAudioSummaryUrl: String? = nil
    
    private let db = Firestore.firestore()
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour in seconds
    private var currentLanguage: String?
    
    init() {
        loadCachedNews()
    }
    
    private func loadCachedNews() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("newsCache").document(userId).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading cached news: \(error)")
                return
            }
            
            if let document = document,
               let data = document.data(),
               let timestamp = data["timestamp"] as? Timestamp,
               let sectionsData = data["sections"] as? [[String: Any]],
               let cachedLanguage = data["language"] as? String,
               let globalAudioUrlFromCache = data["global_audio_summary_url"] as? String? {
                
                // Check if cache is expired
                let currentTime = Timestamp(date: Date())
                if currentTime.seconds - timestamp.seconds > Int64(self.cacheExpirationInterval) {
                    return
                }
                
                // Decode sections
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: sectionsData)
                    let sections = try JSONDecoder().decode([NewsSection].self, from: jsonData)
                    DispatchQueue.main.async {
                        self.newsSections = sections
                        self.currentLanguage = cachedLanguage
                        self.globalAudioSummaryUrl = globalAudioUrlFromCache
                    }
                } catch {
                    print("Error decoding cached news: \(error)")
                }
            }
        }
    }
    
    private func saveNewsToCache(_ sections: [NewsSection], language: String?, audioUrl: String?) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: Cannot save to cache - no user ID")
            return
        }
        
        print("DEBUG: Attempting to save \(sections.count) sections to cache for user \(userId) with audio URL: \(audioUrl ?? "nil")")
        
        do {
            let sectionsData = try sections.map { section -> [String: Any] in
                let jsonData = try JSONEncoder().encode(section)
                guard let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert section to dictionary"])
                }
                return dict
            }
            
            let cacheData: [String: Any] = [
                "sections": sectionsData,
                "timestamp": Timestamp(date: Date()),
                "language": language ?? "English",
                "global_audio_summary_url": audioUrl as Any
            ]
            
            print("DEBUG: Prepared cache data, saving to Firestore...")
            
            db.collection("newsCache").document(userId).setData(cacheData) { error in
                if let error = error {
                    print("DEBUG: Error saving news cache: \(error)")
                } else {
                    print("DEBUG: Successfully saved news cache to Firestore")
                }
            }
        } catch {
            print("DEBUG: Error preparing news cache: \(error)")
        }
    }
    
    private func shouldFetchNewData(language: String?) async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return true }
        
        let document = try await db.collection("newsCache").document(userId).getDocument()
        guard let data = document.data(),
              let timestamp = data["timestamp"] as? Timestamp,
              let cachedLanguage = data["language"] as? String,
              let _ = data["global_audio_summary_url"] as? String? else {
            return true
        }
        
        // Check if cache is expired or language has changed
        let currentTime = Timestamp(date: Date())
        let isExpired = (currentTime.seconds - timestamp.seconds) > Int64(cacheExpirationInterval)
        let languageChanged = language != cachedLanguage
        
        return isExpired || languageChanged
    }
    
    private func loadCachedNews(userId: String) async -> Bool {
        do {
            let document = try await db.collection("newsCache").document(userId).getDocument()
            
            // Log pour vérifier si le document existe
            if !document.exists {
                print("DEBUG: loadCachedNews - Cache document DOES NOT EXIST for user \(userId)")
                return false
            }

            guard let data = document.data() else {
                print("DEBUG: loadCachedNews - Cache document data is NIL for user \(userId)")
                return false
            }
            
            // Log individuel pour chaque champ
            let timestamp = data["timestamp"] as? Timestamp
            if timestamp == nil { print("DEBUG: loadCachedNews - timestamp is nil or wrong type") }
            
            let sectionsData = data["sections"] as? [[String: Any]]
            if sectionsData == nil { print("DEBUG: loadCachedNews - sectionsData is nil or wrong type") }
            
            let cachedLanguage = data["language"] as? String
            if cachedLanguage == nil { print("DEBUG: loadCachedNews - cachedLanguage is nil or wrong type") }
            
            // Vérification spécifique pour global_audio_summary_url
            var globalAudioUrlFromCache: String?? = nil // Optional<Optional<String>> pour différencier clé absente de valeur nil
            if data.keys.contains("global_audio_summary_url") { // La clé existe-t-elle ?
                globalAudioUrlFromCache = data["global_audio_summary_url"] as? String? 
                if globalAudioUrlFromCache == nil && !(data["global_audio_summary_url"] is NSNull) {
                     // La clé existe, mais n'est pas une String? (et n'est pas NSNull, ce qui serait casté en nil par as? String?)
                     print("DEBUG: loadCachedNews - global_audio_summary_url exists but is not String? or NSNull. Actual type: \(type(of: data["global_audio_summary_url"])))")
                } else if globalAudioUrlFromCache != nil {
                     print("DEBUG: loadCachedNews - global_audio_summary_url successfully cast to String?: \(globalAudioUrlFromCache!!)") // Devrait être Optional(String)
                } else {
                     print("DEBUG: loadCachedNews - global_audio_summary_url is present as nil or NSNull and cast to nil.")
                }
            } else {
                print("DEBUG: loadCachedNews - global_audio_summary_url KEY IS MISSING from cache data.")
            }

            guard timestamp != nil,
                  sectionsData != nil,
                  cachedLanguage != nil,
                  data.keys.contains("global_audio_summary_url") // S'assurer que la clé existe, même si la valeur est nil
            else {
                print("DEBUG: loadCachedNews - One of the essential cache fields (timestamp, sections, language, or global_audio_summary_url key) is missing or of wrong type for user \(userId)")
                return false // Cache invalide ou incomplet
            }
            
            // À ce stade, tous les champs requis sont présents, globalAudioUrlFromCache peut être nil
            let finalGlobalAudioUrl = globalAudioUrlFromCache ?? nil // Déballer l'optionnel externe

            let currentTime = Timestamp(date: Date())
            // Assurer que timestamp (qui est Timestamp?) est bien déballé avant usage
            if let validTimestamp = timestamp { // DEBALLAGE AJOUTÉ
                if currentTime.seconds - validTimestamp.seconds > Int64(self.cacheExpirationInterval) {
                    print("DEBUG: loadCachedNews - Cache expired for user \(userId)")
                    return false // Cache expiré
                }
            } else {
                // Ce cas ne devrait pas être atteint si le guard plus haut est correct,
                // mais c'est une sécurité supplémentaire.
                print("DEBUG: loadCachedNews - validTimestamp is unexpectedly nil before expiration check. Cache is invalid.")
                return false 
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: sectionsData!)
            let sections = try JSONDecoder().decode([NewsSection].self, from: jsonData)
            
            DispatchQueue.main.async {
                self.newsSections = sections
                self.currentLanguage = cachedLanguage! // Déballage forcé car vérifié par guard
                self.globalAudioSummaryUrl = finalGlobalAudioUrl 
                print("DEBUG: loadCachedNews - Successfully loaded \(sections.count) sections and audio URL from cache for user \(userId)")
            }
            return true // Données valides chargées depuis le cache
            
        } catch {
            print("DEBUG: loadCachedNews - Error loading or decoding cached news for user \(userId): \(error)")
            return false // Erreur lors du chargement/décodage
        }
    }
    
    func fetchNews(userId: String, language: String? = nil) async {
        print("DEBUG: Starting fetchNews for user \(userId) with language: \(language ?? "default")")
        
        // 1. Essayer de charger depuis le cache
        let loadedFromCache = await loadCachedNews(userId: userId)
        
        // 2. Déterminer si un fetch réseau est nécessaire
        var needsNetworkFetch = true
        if loadedFromCache {
            // Si chargé depuis le cache, vérifier si la langue a changé
            if self.currentLanguage == language {
                print("DEBUG: fetchNews - Valid cache found and language matches. Skipping network fetch.")
                needsNetworkFetch = false
            } else {
                print("DEBUG: fetchNews - Cache loaded, but language changed (cached: \(self.currentLanguage ?? "nil"), requested: \(language ?? "nil")). Will fetch from network.")
            }
        } else {
            print("DEBUG: fetchNews - No valid data loaded from cache. Will fetch from network.")
        }
        
        if !needsNetworkFetch {
            // Si le cache est bon et la langue correspond, s'assurer que isLoading est false et sortir
            if self.isLoading { // Si isLoading était true à cause d'un appel précédent
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = nil // Effacer toute erreur précédente
                }
            }
            return
        }

        // Si on arrive ici, un fetch réseau est nécessaire
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            var components = URLComponents(string: "https://us-central1-prysmios.cloudfunctions.net/get_news_summary")
            var queryItems = [URLQueryItem(name: "user_id", value: userId)]
            if let language = language {
                // Ensure the language parameter is properly encoded
                let encodedLanguage = language.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? language
                queryItems.append(URLQueryItem(name: "language", value: encodedLanguage))
                print("DEBUG: Original language: \(language), Encoded language: \(encodedLanguage)")
            }
            components?.queryItems = queryItems
            
            guard let url = components?.url else {
                DispatchQueue.main.async {
                    self.error = "Invalid URL"
                    self.isLoading = false
                }
                return
            }
            
            print("DEBUG: Fetching news from API with URL: \(url)")
            
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
                    self.error = "Failed to load news: \(responseText)"
                    self.isLoading = false
                }
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(StructuredNewsSummaryResponse.self, from: data)
            
            print("DEBUG: Successfully fetched \(result.sections.count) sections from API. Audio URL: \(result.globalAudioSummaryUrl ?? "nil")")
            // ---- START DEBUG DUMP ----
            for section in result.sections {
                print("DEBUG VM: Section Title: [\(section.title)], Type: [\(section.type)]")
                if let sources = section.sources {
                    print("DEBUG VM: Section [\(section.title)] has \(sources.count) sources.")
                    for source in sources {
                        let title = source.title ?? "N/A"
                        let link = source.link ?? "NO LINK"
                        let sourceName = source.sourceName ?? "N/A"
                        let thumb = source.thumbnail ?? "nil"
                        let thumbSmall = source.thumbnailSmall ?? "nil"
                        print("DEBUG VM: Source for [\(section.title)]: Title='\(title)', Link='\(link)', SourceName='\(sourceName)', Thumb='\(thumb)', ThumbSmall='\(thumbSmall)'")
                    }
                } else {
                    print("DEBUG VM: Section [\(section.title)] has NIL sources.")
                }
                if let subtopics = section.subtopics {
                    print("DEBUG VM: Section [\(section.title)] has \(subtopics.count) subtopics.")
                    for subtopic in subtopics {
                        print("DEBUG VM: Subtopic Title: \(subtopic.title) for Section [\(section.title)]")
                        if let subtopicSources = subtopic.sources {
                            print("DEBUG VM: Subtopic [\(subtopic.title)] has \(subtopicSources.count) string sources.")
                            for subSourceString in subtopicSources {
                                print("DEBUG VM: Sub-Source String: \(subSourceString)")
                            }
                        } else {
                            print("DEBUG VM: Subtopic [\(subtopic.title)] has NIL sources.")
                        }
                    }
                }
            }
            // ---- END DEBUG DUMP ----
            
            DispatchQueue.main.async {
                self.newsSections = result.sections
                self.currentLanguage = language
                self.globalAudioSummaryUrl = result.globalAudioSummaryUrl
                self.isLoading = false
                print("DEBUG: About to save to cache with audio URL: \(result.globalAudioSummaryUrl ?? "nil")")
                self.saveNewsToCache(result.sections, language: language, audioUrl: result.globalAudioSummaryUrl)
            }
        } catch {
            print("DEBUG: Error in fetchNews: \(error)")
            DispatchQueue.main.async {
                self.error = "Error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func forceRefresh(userId: String) async {
        // Clear cache and fetch new data
        do {
            try await db.collection("newsCache").document(userId).delete()
            await fetchNews(userId: userId, language: currentLanguage)
        } catch {
            print("Error clearing cache: \(error)")
        }
    }
} 