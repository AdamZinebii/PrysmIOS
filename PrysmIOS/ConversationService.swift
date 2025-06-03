import Foundation
import Combine
import FirebaseFirestore

// MARK: - Conversation Models
struct ConversationRequest {
    let userId: String?
    let userPreferences: UserConversationPreferences
    let conversationHistory: [ConversationMessage]
    let userMessage: String
}

struct UserConversationPreferences {
    let topics: [String]  // GNews format topics like ["world", "business", "technology"]
    let subtopics: [String: SubtopicDetails]  // New structure with subreddits and queries
    let detailLevel: String
    let language: String
}

struct SubtopicDetails: Codable {
    let subreddits: [String]
    let queries: [String]
}

struct ConversationResponse {
    let success: Bool
    let aiMessage: String?
    let error: String?
    let usage: TokenUsage?
    let conversationId: String?
    let conversationEnding: Bool
    let readyForNews: Bool
}

struct SavePreferencesResponse {
    let success: Bool
    let error: String?
    let userId: String?
}

struct SpecificSubjectsResponse {
    let success: Bool
    let newSubjectsFound: [String]
    let totalSubjects: [String]
    let error: String?
}

struct TokenUsage {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

// MARK: - Conversation Service
class ConversationService: ObservableObject {
    static let shared = ConversationService()
    
    private let baseURL = "https://us-central1-prysmios.cloudfunctions.net"
    private let session = URLSession.shared
    
    @Published var specificSubjects: [String] = []
    @Published var currentUserId: String?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func saveAllPreferencesAtEnd(
        _ preferences: UserConversationPreferences,
        completion: @escaping (Result<SavePreferencesResponse, Error>) -> Void
    ) {
        guard let userId = currentUserId else {
            completion(.failure(ConversationError.invalidResponse))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/save_initial_preferences") else {
            completion(.failure(ConversationError.invalidURL))
            return
        }
        
        print("🔍 [saveAllPreferencesAtEnd] Starting with correct preferences data:")
        print("    Topics: \(preferences.topics)")
        print("    Subtopics with details:")
        for (subtopic, details) in preferences.subtopics {
            print("      '\(subtopic)' -> subreddits: \(details.subreddits), queries: \(details.queries)")
        }
        print("    Specific subjects: \(specificSubjects)")
        
        // Convert to the new nested format: topics -> subtopics -> {subreddits, queries}
        // Use the data that was already correctly prepared in buildSubtopicsWithDetails()
        var nestedPreferences: [String: [String: [String: Any]]] = [:]
        
        // Group subtopics under their parent topics
        for topic in preferences.topics {
            nestedPreferences[topic] = [:]
            
            // Find subtopics that belong to this topic using the mapping
            for (subtopicName, subtopicDetails) in preferences.subtopics {
                if isSubtopicUnderTopic(subtopic: subtopicName, topic: topic) {
                    print("🔍 [saveAllPreferencesAtEnd] Processing subtopic '\(subtopicName)' under topic '\(topic)'")
                    print("    Using prepared queries: \(subtopicDetails.queries)")
                    print("    Using prepared subreddits: \(subtopicDetails.subreddits)")
                    
                    // Use the queries that were already correctly prepared
                    nestedPreferences[topic]![subtopicName] = [
                        "subreddits": subtopicDetails.subreddits,
                        "queries": subtopicDetails.queries  // Use the correct queries!
                    ]
                }
            }
        }
        
        let payload: [String: Any] = [
            "user_id": userId,
            "preferences": nestedPreferences,
            "detail_level": preferences.detailLevel,
            "language": preferences.language
        ]
        
        // Debug logging
        print("🔍 [saveAllPreferencesAtEnd] FINAL nested preferences being sent:")
        for (topic, subtopics) in nestedPreferences {
            print("Topic: \(topic)")
            for (subtopicName, subtopicData) in subtopics {
                let subreddits = subtopicData["subreddits"] as? [String] ?? []
                let queries = subtopicData["queries"] as? [String] ?? []
                print("  \(subtopicName): subreddits=\(subreddits), queries=\(queries)")
            }
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30.0
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            urlRequest.httpBody = jsonData
            
            // Debug: Print the JSON being sent
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🔍 JSON being sent:")
                print(jsonString)
            }
            
            session.dataTask(with: urlRequest) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Network error: \(error)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let data = data else {
                        print("❌ No data received")
                        completion(.failure(ConversationError.noData))
                        return
                    }
                    
                    // Debug: Print the response
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("🔍 Response received:")
                        print(responseString)
                    }
                    
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                        let success = json?["success"] as? Bool ?? false
                        let error = json?["error"] as? String
                        
                        if !success {
                            print("❌ Backend error: \(error ?? "Unknown error")")
                        }
                        
                        let response = SavePreferencesResponse(
                            success: success,
                            error: error,
                            userId: success ? userId : nil
                        )
                        completion(.success(response))
                    } catch {
                        // Handle JSON parsing error
                        print("❌ JSON parsing failed: \(error)")
                        completion(.failure(error))
                    }
                }
            }.resume()
            
        } catch {
            print("❌ JSON serialization failed: \(error)")
            completion(.failure(error))
        }
    }
    
    func saveSchedulingPreferences(
        type: String, // "daily" or "weekly"
        day: String?, // "monday", "tuesday", etc. (or nil for daily)
        localHour: Int, // User's local hour
        localMinute: Int, // User's local minute
        utcHour: Int, // Converted UTC hour
        utcMinute: Int, // Converted UTC minute
        userTimezone: String, // User's timezone identifier
        completion: @escaping (Result<SavePreferencesResponse, Error>) -> Void
    ) {
        print("🔍 [saveSchedulingPreferences] Function called with parameters:")
        print("  - type: \(type)")
        print("  - day: \(day ?? "nil")")
        print("  - localTime: \(String(format: "%02d:%02d", localHour, localMinute))")
        print("  - utcTime: \(String(format: "%02d:%02d", utcHour, utcMinute))")
        print("  - userTimezone: \(userTimezone)")
        print("  - currentUserId: \(currentUserId ?? "nil")")
        
        guard let userId = currentUserId else {
            print("❌ [saveSchedulingPreferences] No userId found, aborting")
            completion(.failure(ConversationError.invalidResponse))
            return
        }
        
        // Format time strings
        let localTimeString = String(format: "%02d:%02d", localHour, localMinute)
        let utcTimeString = String(format: "%02d:%02d", utcHour, utcMinute)
        
        var schedulingData: [String: Any] = [
            "type": type,
            // Local time information (for display/user reference)
            "local_time": localTimeString,
            "local_hour": localHour,
            "local_minute": localMinute,
            "user_timezone": userTimezone,
            // UTC time information (for server-side scheduling)
            "utc_time": utcTimeString,
            "utc_hour": utcHour,
            "utc_minute": utcMinute,
            "updated_at": Date(),
            // Legacy fields for backward compatibility
            "time": utcTimeString, // Use UTC for legacy 'time' field
            "hour": utcHour, // Use UTC for legacy 'hour' field
            "minute": utcMinute // Use UTC for legacy 'minute' field
        ]
        
        // Add day only if it's weekly
        if type == "weekly", let day = day {
            schedulingData["day"] = day
        }
        
        print("🔍 [saveSchedulingPreferences] Saving timezone-aware data to Firestore:")
        print("  - User ID: \(userId)")
        print("  - Type: \(type)")
        print("  - Day: \(day ?? "None")")
        print("  - Local Time: \(localTimeString) (\(userTimezone))")
        print("  - UTC Time: \(utcTimeString)")
        print("  - Full data keys: \(schedulingData.keys.sorted())")
        
        // Save directly to Firestore
        let db = Firestore.firestore()
        print("🔍 [saveSchedulingPreferences] Firestore instance created")
        print("🔍 [saveSchedulingPreferences] About to write to: scheduling_preferences/\(userId)")
        
        db.collection("scheduling_preferences").document(userId).setData(schedulingData, merge: true) { error in
            print("🔍 [saveSchedulingPreferences] Firestore write callback executed")
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [saveSchedulingPreferences] Firestore error: \(error)")
                    print("❌ [saveSchedulingPreferences] Error code: \(error._code)")
                    print("❌ [saveSchedulingPreferences] Error domain: \(error._domain)")
                    completion(.failure(error))
                } else {
                    print("✅ [saveSchedulingPreferences] Successfully saved timezone-aware data to Firestore!")
                    print("✅ [saveSchedulingPreferences] Document path: scheduling_preferences/\(userId)")
                    let response = SavePreferencesResponse(
                        success: true,
                        error: nil,
                        userId: userId
                    )
                    completion(.success(response))
                }
            }
        }
    }
    
    // Helper function to determine which topic a subtopic belongs to
    private func isSubtopicUnderTopic(subtopic: String, topic: String) -> Bool {
        // STEP 1: Check if this subtopic is actually a topic fallback
        // If the subtopic name matches a topic from TopicsCatalog, it's a fallback
        for (categoryKey, topicMeta) in TopicsCatalog.catalog {
            if topicMeta.title == subtopic {
                // This is a topic fallback, check if it matches the current topic
                let mappedTopic = mapCategoryToGNews(categoryKey)
                let isMatch = mappedTopic == topic
                
                print("🔍 Topic fallback mapping: '\(subtopic)' (category: '\(categoryKey)') -> GNews topic '\(mappedTopic)' (looking for '\(topic)') = \(isMatch)")
                
                return isMatch
            }
        }
        
        // STEP 2: Regular subtopic mapping (existing logic)
        // Use the actual SubtopicsCatalog to find which category a subtopic belongs to
        for (categoryName, subtopics) in SubtopicsCatalog.catalog {
            if subtopics.contains(where: { $0.title == subtopic }) {
                // Map category names to GNews topics
                let mappedTopic = mapCategoryToGNews(categoryName)
                let isMatch = mappedTopic == topic
                
                print("🔍 Subtopic mapping: '\(subtopic)' found in category '\(categoryName)' -> GNews topic '\(mappedTopic)' (looking for '\(topic)') = \(isMatch)")
                
                return isMatch
            }
        }
        
        print("⚠️ Subtopic '\(subtopic)' not found in any catalog category or topic fallback")
        return false
    }
    
    // Helper function to map category names to GNews format
    private func mapCategoryToGNews(_ categoryName: String) -> String {
        let lowercased = categoryName.lowercased()
        
        switch lowercased {
        case "general", "général":
            return "general"
        case "nation", "nacional", "وطني":
            return "nation"
        case "technology", "technologie", "tecnología", "تكنولوجيا":
            return "technology"
        case "business", "affaires", "negocios", "أعمال":
            return "business"
        case "sports", "deportes", "رياضة":
            return "sports"
        case "science", "ciencia", "علوم":
            return "science"
        case "health", "santé", "salud", "صحة":
            return "health"
        case "entertainment", "divertissement", "entretenimiento", "ترفيه":
            return "entertainment"
        case "world", "monde", "mundo", "عالم":
            return "world"
        default:
            return "general"
        }
    }
    
    func startConversation(
        with preferences: UserConversationPreferences,
        completion: @escaping (Result<ConversationResponse, Error>) -> Void
    ) {
        // Start with a proper first message to get AI's first proactive message
        let languageCode = preferences.language
        let firstMessage: String
        
        switch languageCode {
        case "fr":
            firstMessage = "Bonjour ! Je viens de configurer mes préférences d'actualités. Pouvez-vous m'aider à découvrir des sujets spécifiques qui m'intéressent ?"
        case "es":
            firstMessage = "¡Hola! Acabo de configurar mis preferencias de noticias. ¿Puedes ayudarme a descubrir temas específicos que me interesen?"
        case "ar":
            firstMessage = "مرحباً! لقد قمت للتو بتكوين تفضيلات الأخبار الخاصة بي. هل يمكنك مساعدتي في اكتشاف مواضيع محددة تهمني؟"
        default:
            firstMessage = "Hello! I just set up my news preferences. Can you help me discover specific topics that interest me?"
        }
        
        let request = ConversationRequest(
            userId: currentUserId,
            userPreferences: preferences,
            conversationHistory: [],
            userMessage: firstMessage
        )
        
        sendConversationRequest(request, completion: completion)
    }
    
    func continueConversation(
        with request: ConversationRequest,
        completion: @escaping (Result<ConversationResponse, Error>) -> Void
    ) {
        sendConversationRequest(request, completion: completion)
    }
    
    func pollSpecificSubjects(
        completion: @escaping (Result<SpecificSubjectsResponse, Error>) -> Void
    ) {
        guard let userId = currentUserId else {
            completion(.failure(ConversationError.invalidResponse))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/update_specific_subjects") else {
            completion(.failure(ConversationError.invalidURL))
            return
        }
        
        let payload: [String: Any] = [
            "user_id": userId,
            "action": "get"
        ]
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 10.0
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            urlRequest.httpBody = jsonData
            
            session.dataTask(with: urlRequest) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        // Silently fail for polling - don't spam errors
                        let mockResponse = SpecificSubjectsResponse(
                            success: true,
                            newSubjectsFound: [],
                            totalSubjects: self.specificSubjects,
                            error: nil
                        )
                        completion(.success(mockResponse))
                        return
                    }
                    
                    guard let data = data else {
                        let mockResponse = SpecificSubjectsResponse(
                            success: true,
                            newSubjectsFound: [],
                            totalSubjects: self.specificSubjects,
                            error: nil
                        )
                        completion(.success(mockResponse))
                        return
                    }
                    
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                        let success = json?["success"] as? Bool ?? false
                        let subjects = json?["specific_subjects"] as? [String] ?? []
                        let error = json?["error"] as? String
                        
                        let currentSubjects = Set(self.specificSubjects)
                        let newSubjects = Set(subjects)
                        let addedSubjects = Array(newSubjects.subtracting(currentSubjects))
                        
                        let response = SpecificSubjectsResponse(
                            success: success,
                            newSubjectsFound: addedSubjects,
                            totalSubjects: subjects,
                            error: error
                        )
                        completion(.success(response))
                    } catch {
                        // Silently fail for polling
                        let mockResponse = SpecificSubjectsResponse(
                            success: true,
                            newSubjectsFound: [],
                            totalSubjects: self.specificSubjects,
                            error: nil
                        )
                        completion(.success(mockResponse))
                    }
                }
            }.resume()
            
        } catch {
            let mockResponse = SpecificSubjectsResponse(
                success: true,
                newSubjectsFound: [],
                totalSubjects: specificSubjects,
                error: nil
            )
            completion(.success(mockResponse))
        }
    }
    
    func loadExistingPreferences(
        completion: @escaping (Result<UserConversationPreferences?, Error>) -> Void
    ) {
        guard let userId = currentUserId else {
            completion(.failure(ConversationError.invalidResponse))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/get_user_preferences") else {
            completion(.failure(ConversationError.invalidURL))
            return
        }
        
        let payload: [String: Any] = [
            "user_id": userId
        ]
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30.0
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            urlRequest.httpBody = jsonData
            
            print("🔍 Loading existing preferences for user: \(userId)")
            
            session.dataTask(with: urlRequest) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Network error loading preferences: \(error)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let data = data else {
                        print("❌ No data received when loading preferences")
                        completion(.failure(ConversationError.noData))
                        return
                    }
                    
                    // Debug: Print the response
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("🔍 Preferences response received:")
                        print(responseString)
                    }
                    
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                        let success = json?["success"] as? Bool ?? false
                        
                        print("🔍 Parsed JSON response:")
                        print("  - Success: \(success)")
                        print("  - JSON keys: \(json?.keys.sorted() ?? [])")
                        
                        if success {
                            if let preferencesData = json?["preferences"] as? [String: Any] {
                                print("🔍 Found preferences data:")
                                print("  - Preferences data keys: \(preferencesData.keys.sorted())")
                                print("  - Format version: \(preferencesData["format_version"] as? String ?? "unknown")")
                                
                                // Check if this is the new nested format or old format
                                if let nestedPrefs = preferencesData["preferences"] as? [String: [String: [String: Any]]] {
                                    print("🔍 Processing new nested format (v3.0)")
                                    print("  - Nested preferences keys: \(nestedPrefs.keys.sorted())")
                                    
                                    // New nested format: topics -> subtopics -> {subreddits, queries}
                                    var topics: [String] = []
                                    var subtopics: [String: SubtopicDetails] = [:]
                                    
                                    for (topic, topicSubtopics) in nestedPrefs {
                                        topics.append(topic)
                                        print("  - Processing topic: \(topic) with \(topicSubtopics.count) subtopics")
                                        
                                        for (subtopicName, subtopicData) in topicSubtopics {
                                            let subreddits = subtopicData["subreddits"] as? [String] ?? []
                                            let queries = subtopicData["queries"] as? [String] ?? []
                                            subtopics[subtopicName] = SubtopicDetails(
                                                subreddits: subreddits,
                                                queries: queries
                                            )
                                            print("    - Subtopic: \(subtopicName), subreddits: \(subreddits.count), queries: \(queries.count)")
                                        }
                                    }
                                    
                                    let detailLevel = preferencesData["detail_level"] as? String ?? "Medium"
                                    let language = preferencesData["language"] as? String ?? "en"
                                    let specificSubjects = preferencesData["specific_subjects"] as? [String] ?? []
                                    
                                    // Update the specific subjects in the service
                                    self.specificSubjects = specificSubjects
                                    
                                    let userPreferences = UserConversationPreferences(
                                        topics: topics,
                                        subtopics: subtopics,
                                        detailLevel: detailLevel,
                                        language: language
                                    )
                                    
                                    print("✅ Successfully loaded existing preferences (new nested format):")
                                    print("  - Topics: \(topics)")
                                    print("  - Subtopics: \(subtopics.keys.sorted())")
                                    print("  - Specific subjects: \(specificSubjects)")
                                    print("  - Detail level: \(detailLevel)")
                                    print("  - Language: \(language)")
                                    
                                    completion(.success(userPreferences))
                                    
                                } else {
                                    print("🔍 Processing legacy format (v2.0 or older)")
                                    // Old format: parse the old way for backward compatibility
                                    let topics = preferencesData["topics"] as? [String] ?? []
                                    let subtopicsData = preferencesData["subtopics"] as? [String: [String: Any]] ?? [:]
                                    let detailLevel = preferencesData["detail_level"] as? String ?? "Medium"
                                    let language = preferencesData["language"] as? String ?? "en"
                                    let specificSubjects = preferencesData["specific_subjects"] as? [String] ?? []
                                    
                                    print("  - Legacy topics: \(topics)")
                                    print("  - Legacy subtopics keys: \(subtopicsData.keys.sorted())")
                                    
                                    // Convert subtopics data to SubtopicDetails
                                    var subtopics: [String: SubtopicDetails] = [:]
                                    for (subtopicName, subtopicData) in subtopicsData {
                                        let subreddits = subtopicData["subreddits"] as? [String] ?? []
                                        let queries = subtopicData["queries"] as? [String] ?? []
                                        subtopics[subtopicName] = SubtopicDetails(
                                            subreddits: subreddits,
                                            queries: queries
                                        )
                                    }
                                    
                                    // Update the specific subjects in the service
                                    self.specificSubjects = specificSubjects
                                    
                                    let userPreferences = UserConversationPreferences(
                                        topics: topics,
                                        subtopics: subtopics,
                                        detailLevel: detailLevel,
                                        language: language
                                    )
                                    
                                    print("✅ Successfully loaded existing preferences (old format):")
                                    print("  - Topics: \(topics)")
                                    print("  - Subtopics: \(subtopics.keys.sorted())")
                                    print("  - Specific subjects: \(specificSubjects)")
                                    print("  - Detail level: \(detailLevel)")
                                    print("  - Language: \(language)")
                                    
                                    completion(.success(userPreferences))
                                }
                            } else {
                                // No existing preferences found
                                print("ℹ️ No existing preferences found for user")
                                print("🔍 JSON response did not contain 'preferences' key")
                                completion(.success(nil))
                            }
                        } else {
                            let error = json?["error"] as? String ?? "Unknown error"
                            print("❌ Backend error loading preferences: \(error)")
                            completion(.failure(ConversationError.invalidResponse))
                        }
                    } catch {
                        print("❌ JSON parsing failed when loading preferences: \(error)")
                        completion(.failure(error))
                    }
                }
            }.resume()
            
        } catch {
            print("❌ JSON serialization failed when loading preferences: \(error)")
            completion(.failure(error))
        }
    }
    
    // MARK: - Private Methods
    
    private func sendConversationRequest(
        _ request: ConversationRequest,
        completion: @escaping (Result<ConversationResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/answer") else {
            completion(.failure(ConversationError.invalidURL))
            return
        }
        
        // Build payload
        let userPreferences: [String: Any] = [
            "topics": request.userPreferences.topics,
            "subtopics": request.userPreferences.subtopics,
            "detail_level": request.userPreferences.detailLevel,
            "language": request.userPreferences.language
        ]
        
        let conversationHistory = request.conversationHistory.map { message in
            [
                "role": message.isFromUser ? "user" : "assistant",
                "content": message.content
            ]
        }
        
        var payload: [String: Any] = [
            "user_preferences": userPreferences,
            "conversation_history": conversationHistory,
            "user_message": request.userMessage
        ]
        
        // Add user_id if available for specific subjects tracking
        if let userId = request.userId {
            payload["user_id"] = userId
        }
        
        // Create request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30.0
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            urlRequest.httpBody = jsonData
            
            session.dataTask(with: urlRequest) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    guard let data = data else {
                        completion(.failure(ConversationError.noData))
                        return
                    }
                    
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                        let response = self.parseConversationResponse(json)
                        completion(.success(response))
                    } catch {
                        // Handle JSON parsing error
                        print("JSON parsing failed: \(error)")
                        completion(.failure(error))
                    }
                }
            }.resume()
            
        } catch {
            completion(.failure(error))
        }
    }
    
    private func parseConversationResponse(_ json: [String: Any]?) -> ConversationResponse {
        guard let json = json else {
            return ConversationResponse(
                success: false,
                aiMessage: nil,
                error: "Invalid response format",
                usage: nil,
                conversationId: nil,
                conversationEnding: false,
                readyForNews: false
            )
        }
        
        let success = json["success"] as? Bool ?? false
        let aiMessage = json["ai_message"] as? String
        let error = json["error"] as? String
        let conversationId = json["conversation_id"] as? String
        let conversationEnding = json["conversation_ending"] as? Bool ?? false
        let readyForNews = json["ready_for_news"] as? Bool ?? false
        
        // Parse usage information
        var usage: TokenUsage? = nil
        if let usageData = json["usage"] as? [String: Any] {
            usage = TokenUsage(
                promptTokens: usageData["prompt_tokens"] as? Int ?? 0,
                completionTokens: usageData["completion_tokens"] as? Int ?? 0,
                totalTokens: usageData["total_tokens"] as? Int ?? 0
            )
        }
        
        return ConversationResponse(
            success: success,
            aiMessage: aiMessage,
            error: error,
            usage: usage,
            conversationId: conversationId,
            conversationEnding: conversationEnding,
            readyForNews: readyForNews
        )
    }
    
    private func getInitialMessage(for languageCode: String) -> String {
        switch languageCode {
        case "fr":
            return "Bonjour ! Je suis prêt à vous aider avec des actualités personnalisées selon vos préférences."
        case "es":
            return "¡Hola! Estoy listo para ayudarte con noticias personalizadas según tus preferencias."
        case "ar":
            return "مرحباً! أنا جاهز لمساعدتك في الأخبار المخصصة حسب تفضيلاتك."
        default:
            return "Hello! I'm ready to help you with personalized news based on your preferences."
        }
    }
    
    private func getSimulatedAIResponse(for userMessage: String, language: String) -> String {
        let isFirstMessage = userMessage.contains("Commencer") || userMessage.contains("Start") || userMessage.contains("Comenzar")
        
        if isFirstMessage {
            // Proactive first message
            switch language {
            case "fr":
                return "Bonjour ! Je vois que vous vous intéressez à la technologie et au sport. Pour la technologie, êtes-vous intéressé par Apple, Tesla ou OpenAI ? Et pour le sport, souhaitez-vous suivre le PSG, Mbappé ou les résultats de tennis ?"
            case "es":
                return "¡Hola! Veo que te interesa la tecnología y el deporte. Para tecnología, ¿te interesa Apple, Tesla u OpenAI? Y para deportes, ¿quieres seguir al PSG, Mbappé o resultados de tenis?"
            case "ar":
                return "مرحباً! أرى أنك مهتم بالتكنولوجيا والرياضة. بالنسبة للتكنولوجيا، هل تهتم بـ Apple أو Tesla أو OpenAI؟ وللرياضة، هل تريد متابعة PSG أو Mbappé أو نتائج التنس؟"
            default:
                return "Hello! I see you're interested in technology and sports. For technology, are you interested in Apple, Tesla, or OpenAI? And for sports, would you like to follow PSG, Mbappé, or tennis results?"
            }
        } else {
            // Regular conversation response
            switch language {
            case "fr":
                return "C'est très intéressant ! Je note vos préférences. Y a-t-il d'autres sujets spécifiques qui vous intéressent ?"
            case "es":
                return "¡Muy interesante! Tomo nota de tus preferencias. ¿Hay otros temas específicos que te interesen?"
            case "ar":
                return "هذا مثير للاهتمام جداً! سأسجل تفضيلاتك. هل هناك مواضيع أخرى محددة تهمك؟"
            default:
                return "That's very interesting! I'm noting your preferences. Are there any other specific topics that interest you?"
            }
        }
    }
    
    // Helper function to determine if a subject and subtopic are related
    private func areRelatedTopics(subject: String, subtopic: String) -> Bool {
        // Define some common relationships
        let relationships: [String: [String]] = [
            "ai": ["openai", "chatgpt", "artificial intelligence", "machine learning", "gpt", "claude", "gemini"],
            "finance": ["bitcoin", "cryptocurrency", "stocks", "trading", "investment", "market", "economy"],
            "gadgets": ["iphone", "android", "smartphone", "tablet", "laptop", "apple", "samsung", "google"],
            "sports": ["football", "basketball", "tennis", "soccer", "nfl", "nba", "fifa", "olympics"],
            "health": ["medicine", "fitness", "nutrition", "wellness", "covid", "vaccine", "mental health"],
            "science": ["space", "nasa", "research", "discovery", "climate", "physics", "chemistry", "biology"]
        ]
        
        // Check if the subject matches any keywords for the subtopic
        if let keywords = relationships[subtopic] {
            return keywords.contains { keyword in
                subject.contains(keyword) || keyword.contains(subject)
            }
        }
        
        return false
    }
    
    private func getLanguageCode(from language: String) -> String {
        switch language {
        case "English": return "en"
        case "Français": return "fr"
        case "Español": return "es"
        case "العربية": return "ar"
        default: return "en"
        }
    }
    
    // MARK: - Timezone Helper Functions
    
    /// Converts UTC time to user's local time for display purposes
    func convertUTCToLocalTime(utcHour: Int, utcMinute: Int, userTimezone: String) -> (hour: Int, minute: Int) {
        guard let timeZone = TimeZone(identifier: userTimezone) else {
            print("⚠️ Invalid timezone identifier: \(userTimezone), using current timezone")
            return convertUTCToLocalTime(utcHour: utcHour, utcMinute: utcMinute, timeZone: TimeZone.current)
        }
        
        return convertUTCToLocalTime(utcHour: utcHour, utcMinute: utcMinute, timeZone: timeZone)
    }
    
    /// Converts UTC time to specified timezone
    private func convertUTCToLocalTime(utcHour: Int, utcMinute: Int, timeZone: TimeZone) -> (hour: Int, minute: Int) {
        // Create a date for today with the UTC time
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = utcHour
        dateComponents.minute = utcMinute
        dateComponents.timeZone = TimeZone(identifier: "UTC")
        
        guard let utcDate = calendar.date(from: dateComponents) else {
            print("⚠️ Failed to create UTC date, returning original time")
            return (hour: utcHour, minute: utcMinute)
        }
        
        // Convert to local timezone
        let localFormatter = DateFormatter()
        localFormatter.timeZone = timeZone
        localFormatter.dateFormat = "HH:mm"
        
        let localTimeString = localFormatter.string(from: utcDate)
        let localComponents = localTimeString.split(separator: ":").map { Int($0) ?? 0 }
        
        return (hour: localComponents[0], minute: localComponents[1])
    }
    
    /// Get formatted display string for scheduling preferences
    func getScheduleDisplayString(type: String, day: String?, localHour: Int, localMinute: Int, userTimezone: String) -> String {
        let timeString = String(format: "%02d:%02d", localHour, localMinute)
        let timezoneName = TimeZone(identifier: userTimezone)?.localizedName(for: .standard, locale: .current) ?? userTimezone
        
        if type == "weekly", let day = day {
            let dayCapitalized = day.capitalized
            return "\(dayCapitalized)s at \(timeString) (\(timezoneName))"
        } else {
            return "Daily at \(timeString) (\(timezoneName))"
        }
    }
}

// MARK: - Error Types
enum ConversationError: LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .invalidResponse:
            return "Invalid response format"
        }
    }
}

// MARK: - Helper Extensions
extension UserPreferences {
    func toConversationPreferences() -> UserConversationPreferences {
        let languageCode = getLanguageCode(from: self.language)
        
        // Convert selected categories to GNews format
        let gnewsTopics = convertCategoriesToGNewsFormat()
        
        // Build subtopics dictionary with subreddits and queries
        let subtopicsDict = buildSubtopicsWithDetails()
        
        return UserConversationPreferences(
            topics: gnewsTopics,
            subtopics: subtopicsDict,
            detailLevel: self.detailLevel.rawValue,
            language: languageCode
        )
    }
    
    private func convertCategoriesToGNewsFormat() -> [String] {
        var gnewsTopics: [String] = []
        
        for categoryName in self.selectedCategories {
            // Map localized category names to GNews format
            let gnewsCategory = mapCategoryToGNews(categoryName)
            if !gnewsTopics.contains(gnewsCategory) {
                gnewsTopics.append(gnewsCategory)
            }
        }
        
        return gnewsTopics
    }
    
    private func mapCategoryToGNews(_ categoryName: String) -> String {
        let lowercased = categoryName.lowercased()
        
        switch lowercased {
        case "general", "général":
            return "general"
        case "nation", "nacional", "وطني":
            return "nation"
        case "technology", "technologie", "tecnología", "تكنولوجيا":
            return "technology"
        case "business", "affaires", "negocios", "أعمال":
            return "business"
        case "sports", "deportes", "رياضة":
            return "sports"
        case "science", "ciencia", "علوم":
            return "science"
        case "health", "santé", "salud", "صحة":
            return "health"
        case "entertainment", "divertissement", "entretenimiento", "ترفيه":
            return "entertainment"
        case "world", "monde", "mundo", "عالم":
            return "world"
        default:
            return "general"
        }
    }
    
    private func getLanguageCode(from language: String) -> String {
        switch language {
        case "English": return "en"
        case "Français": return "fr"
        case "Español": return "es"
        case "العربية": return "ar"
        default: return "en"
        }
    }
    
    private func buildSubtopicsWithDetails() -> [String: SubtopicDetails] {
        var subtopicsDict: [String: SubtopicDetails] = [:]
        
        print("🔍 [buildSubtopicsWithDetails] Starting to build subtopics...")
        print("🔍 Selected categories: \(selectedCategories)")
        print("🔍 Selected subcategories: \(selectedSubcategories)")
        print("🔍 Subtopic trends mapping: \(subtopicTrends)")
        print("🔍 Custom topics (backward compatibility): \(customTopics)")
        
        // STEP 1: Check for topics without subtopics and add topic fallback
        for categoryName in selectedCategories {
            let categoryKey = mapCategoryNameToKey(categoryName)
            print("🔍 [buildSubtopicsWithDetails] Checking category: '\(categoryName)' (key: '\(categoryKey)')")
            
            // Get all possible subtopics for this category
            let availableSubtopics = SubtopicsCatalog.getSubtopicTitles(for: categoryKey)
            
            // Check if user selected any subtopics from this category
            let selectedSubtopicsForCategory = selectedSubcategories.filter { selectedSubtopic in
                availableSubtopics.contains(selectedSubtopic)
            }
            
            print("    Available subtopics: \(availableSubtopics)")
            print("    Selected subtopics for this category: \(selectedSubtopicsForCategory)")
            
            // If no subtopics selected for this category, add the topic itself as a subtopic
            if selectedSubtopicsForCategory.isEmpty {
                print("    ⚠️ No subtopics selected for '\(categoryName)', adding topic itself as fallback")
                
                if let topicMeta = TopicsCatalog.getTopicMeta(for: categoryKey) {
                    subtopicsDict[topicMeta.title] = SubtopicDetails(
                        subreddits: topicMeta.subreddits,
                        queries: [topicMeta.query]
                    )
                    print("    ✅ Added topic fallback: '\(topicMeta.title)' with query: '\(topicMeta.query)' and subreddits: \(topicMeta.subreddits)")
                } else {
                    print("    ❌ No topic metadata found for '\(categoryKey)' - this shouldn't happen")
                }
            }
        }
        
        // STEP 2: Process selected subtopics (existing logic)
        for subtopicName in selectedSubcategories {
            print("🔍 [buildSubtopicsWithDetails] Processing subtopic: '\(subtopicName)'")
            
            // Search for subtopic in catalog using global method
            var foundSubtopic: SubtopicMeta? = nil
            for (categoryKey, subtopics) in SubtopicsCatalog.catalog {
                if let found = subtopics.first(where: { $0.title == subtopicName }) {
                    foundSubtopic = found
                    print("    Found in category '\(categoryKey)': query='\(found.query)', subreddits=\(found.subreddits)")
                    break
                }
            }
            
            if let subtopicMeta = foundSubtopic {
                let subreddits = subtopicMeta.subreddits
                
                // Use trends directly from the mapping if available
                let queries: [String]
                if let trends = subtopicTrends[subtopicName], !trends.isEmpty {
                    // Use the selected trends as queries
                    queries = trends
                    print("    ✅ Using selected trends as queries: \(trends)")
                    print("    ✅ Subreddits: \(subreddits)")
                } else {
                    // Keep queries empty if no trends are selected
                    queries = []
                    print("    ℹ️ No trends selected for '\(subtopicName)', keeping queries empty")
                    print("    ✅ Subreddits: \(subreddits)")
                }
                
                let subtopicDetails = SubtopicDetails(
                    subreddits: subreddits,
                    queries: queries
                )
                
                subtopicsDict[subtopicName] = subtopicDetails
                print("    📋 Final SubtopicDetails for '\(subtopicName)': subreddits=\(subreddits), queries=\(queries)")
            } else {
                print("    ❌ Subtopic '\(subtopicName)' not found in catalog")
                // Create a default subtopic with empty queries if no trends selected
                let queries: [String]
                if let trends = subtopicTrends[subtopicName], !trends.isEmpty {
                    queries = trends
                    print("    ✅ Using selected trends as queries: \(trends)")
                } else {
                    queries = []
                    print("    ℹ️ No trends selected, keeping queries empty")
                }
                
                let subtopicDetails = SubtopicDetails(
                    subreddits: ["worldnews", "news"], // Default subreddits
                    queries: queries
                )
                
                subtopicsDict[subtopicName] = subtopicDetails
                print("    🔧 Created default SubtopicDetails for '\(subtopicName)': subreddits=['worldnews', 'news'], queries=\(queries)")
            }
        }
        
        print("🔍 [buildSubtopicsWithDetails] FINAL RESULT:")
        for (subtopic, details) in subtopicsDict {
            print("    '\(subtopic)' -> subreddits: \(details.subreddits), queries: \(details.queries)")
        }
        
        return subtopicsDict
    }
    
    // Helper method to map category name to key
    private func mapCategoryNameToKey(_ categoryName: String) -> String {
        let lowercased = categoryName.lowercased()
        
        switch lowercased {
        case "nation", "nacional", "وطني":
            return "nation"
        case "technology", "technologie", "tecnología", "تكنولوجيا":
            return "technology"
        case "business", "affaires", "negocios", "أعمال":
            return "business"
        case "sports", "deportes", "رياضة":
            return "sports"
        case "science", "ciencia", "علوم":
            return "science"
        case "health", "santé", "salud", "صحة":
            return "health"
        case "entertainment", "divertissement", "entretenimiento", "ترفيه":
            return "entertainment"
        case "world", "monde", "mundo", "عالم":
            return "world"
        default:
            return "technology" // fallback
        }
    }
}
