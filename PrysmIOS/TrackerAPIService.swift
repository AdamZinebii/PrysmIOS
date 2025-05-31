import Foundation
import FirebaseFirestore
import FirebaseAuth

class TrackerAPIService {
    static let shared = TrackerAPIService()
    private init() {}
    
    private let db = Firestore.firestore()
    private let baseUrl = "https://us-central1-prysmios.cloudfunctions.net"
    private let cacheExpirationInterval: TimeInterval = 7200 // 2 hours in seconds

    enum APIError: Error {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case decodingError(Error)
        case noData
        case serverError(statusCode: Int, message: String?)
        case authenticationError
        case cacheMiss
        case cacheExpired
    }
    
    // MARK: - Cache Management
    private func getCacheKey(for type: String, identifier: String) -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: No user ID available for cache key")
            return "\(type)_\(identifier)"
        }
        return "\(userId)_\(type)_\(identifier)"
    }
    
    private func saveToCache<T: Encodable>(_ data: T, type: String, identifier: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: Cannot save to cache - No user ID")
            return
        }

        let cacheRef = Firestore.firestore().collection("trackerCache")
        let documentId = "\(userId)_\(type)_\(identifier)"
        
        do {
            let jsonData = try JSONEncoder().encode(data)
            guard let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("DEBUG: Failed to convert data to dictionary")
                return
            }
            
            var cacheData = jsonDict
            cacheData["type"] = type
            cacheData["identifier"] = identifier
            cacheData["userId"] = userId
            cacheData["timestamp"] = FieldValue.serverTimestamp()
            
            cacheRef.document(documentId).setData(cacheData) { error in
                if let error = error {
                    print("DEBUG: Failed to save to cache: \(error)")
                } else {
                    print("DEBUG: Successfully saved to cache: \(documentId)")
                }
            }
        } catch {
            print("DEBUG: Failed to encode data for cache: \(error)")
        }
    }
    
    private func loadFromCache<T: Decodable>(type: String, identifier: String, completion: @escaping (Result<T, APIError>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: No user ID available for cache")
            completion(.failure(.cacheMiss))
            return
        }

        let cacheRef = Firestore.firestore().collection("trackerCache")
        let documentId = "\(userId)_\(type)_\(identifier)"
        
        cacheRef.document(documentId).getDocument { snapshot, error in
            if let error = error {
                print("DEBUG: Cache read error: \(error)")
                // Instead of failing, treat as cache miss
                completion(.failure(.cacheMiss))
                return
            }
            
            guard let document = snapshot, document.exists,
                  let data = document.data(),
                  let timestamp = data["timestamp"] as? Timestamp else {
                completion(.failure(.cacheMiss))
                return
            }
            
            // Check if cache is expired (older than 5 minutes)
            let cacheAge = Date().timeIntervalSince(timestamp.dateValue())
            if cacheAge > 300 { // 5 minutes in seconds
                print("DEBUG: Cache expired for \(documentId)")
                completion(.failure(.cacheExpired))
                return
            }
            
            do {
                // Remove metadata fields before decoding
                var cleanData = data
                cleanData.removeValue(forKey: "type")
                cleanData.removeValue(forKey: "identifier")
                cleanData.removeValue(forKey: "timestamp")
                cleanData.removeValue(forKey: "userId")
                
                let jsonData = try JSONSerialization.data(withJSONObject: cleanData)
                let decodedData = try JSONDecoder().decode(T.self, from: jsonData)
                completion(.success(decodedData))
            } catch {
                print("DEBUG: Cache decode error: \(error)")
                completion(.failure(.cacheMiss))
            }
        }
    }

    // MARK: - Fetch Match Score
    func fetchMatchScore(matchId: String, completion: @escaping (Result<MatchScoreData, APIError>) -> Void) {
        print("DEBUG: Starting fetchMatchScore for match \(matchId)")
        
        // Try to load from cache first
        loadFromCache(type: "match", identifier: matchId) { (result: Result<MatchScoreData, APIError>) in
            switch result {
            case .success(let cachedData):
                print("DEBUG: Using cached match data")
                completion(.success(cachedData))
            case .failure(let error):
                print("DEBUG: Cache miss or error: \(error)")
                // If cache miss or expired, fetch from API
                guard let url = URL(string: "\(self.baseUrl)/get_match_score?match_id=\(matchId)") else {
                    completion(.failure(.invalidURL))
                    return
                }
                
                self.fetchData(from: url) { (result: Result<MatchScoreData, APIError>) in
                    switch result {
                    case .success(let data):
                        print("DEBUG: API call successful, saving to cache")
                        self.saveToCache(data, type: "match", identifier: matchId)
                        completion(.success(data))
                    case .failure(let error):
                        print("DEBUG: API call failed: \(error)")
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: - Fetch League Standings
    func fetchLeagueStandings(competitionId: String, completion: @escaping (Result<LeagueStandingResponse, APIError>) -> Void) {
        print("DEBUG: Starting fetchLeagueStandings for competition \(competitionId)")
        
        // Try to load from cache first
        loadFromCache(type: "standings", identifier: competitionId) { (result: Result<LeagueStandingResponse, APIError>) in
            switch result {
            case .success(let cachedData):
                print("DEBUG: Using cached standings data")
                completion(.success(cachedData))
            case .failure(let error):
                print("DEBUG: Cache miss or error: \(error)")
                // If cache miss or expired, fetch from API
                guard let url = URL(string: "\(self.baseUrl)/get_standings?competition_id=\(competitionId)") else {
                    completion(.failure(.invalidURL))
                    return
                }
                
                self.fetchData(from: url) { (result: Result<LeagueStandingResponse, APIError>) in
                    switch result {
                    case .success(let data):
                        print("DEBUG: API call successful, saving to cache")
                        self.saveToCache(data, type: "standings", identifier: competitionId)
                        completion(.success(data))
                    case .failure(let error):
                        print("DEBUG: API call failed: \(error)")
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: - Fetch Asset Price
    func fetchAssetPrice(symbol: String, completion: @escaping (Result<AssetPriceData, APIError>) -> Void) {
        print("DEBUG: Starting fetchAssetPrice for symbol \(symbol)")
        
        // Format the symbol: remove any spaces and convert to uppercase
        let formattedSymbol = symbol.trimmingCharacters(in: .whitespaces).uppercased()
        print("DEBUG: Formatted symbol: \(formattedSymbol)")
        
        // Try to load from cache first
        loadFromCache(type: "asset", identifier: formattedSymbol) { (result: Result<AssetPriceData, APIError>) in
            switch result {
            case .success(let cachedData):
                print("DEBUG: Using cached asset data for \(formattedSymbol)")
                completion(.success(cachedData))
            case .failure(let error):
                print("DEBUG: Cache miss or error for \(formattedSymbol): \(error)")
                // If cache miss or expired, fetch from API
                guard let encodedSymbol = formattedSymbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    print("DEBUG: Failed to encode symbol: \(formattedSymbol)")
                    completion(.failure(.invalidURL))
                    return
                }
                
                guard let url = URL(string: "\(self.baseUrl)/get_asset_price?symbol=\(encodedSymbol)") else {
                    print("DEBUG: Failed to create URL for symbol: \(formattedSymbol)")
                    completion(.failure(.invalidURL))
                    return
                }
                
                print("DEBUG: Fetching data from API: \(url.absoluteString)")
                
                self.fetchData(from: url) { (result: Result<AssetPriceData, APIError>) in
                    switch result {
                    case .success(let data):
                        print("DEBUG: API call successful for \(formattedSymbol), saving to cache")
                        self.saveToCache(data, type: "asset", identifier: formattedSymbol)
                        completion(.success(data))
                    case .failure(let error):
                        print("DEBUG: API call failed for \(formattedSymbol): \(error)")
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    // MARK: - Fetch League Schedule
    func fetchLeagueSchedule(leagueId: String, completion: @escaping (Result<LeagueScheduleResponse, APIError>) -> Void) {
        print("DEBUG: Starting fetchLeagueSchedule for league \(leagueId)")
        
        // Get the API ID for this league
        let apiId = LeagueManager.shared.getApiId(for: leagueId)
        
        // Try to load from cache first
        loadFromCache(type: "schedule", identifier: leagueId) { (result: Result<LeagueScheduleResponse, APIError>) in
            switch result {
            case .success(let cachedData):
                print("DEBUG: Using cached schedule data")
                completion(.success(cachedData))
            case .failure(let error):
                print("DEBUG: Cache miss or error: \(error)")
                // If cache miss or expired, fetch from API
                guard let url = URL(string: "\(self.baseUrl)/get_league_matches?competition_id=\(apiId)") else {
                    completion(.failure(.invalidURL))
                    return
                }
                
                self.fetchData(from: url) { (result: Result<LeagueScheduleResponse, APIError>) in
                    switch result {
                    case .success(let data):
                        print("DEBUG: API call successful, saving to cache")
                        self.saveToCache(data, type: "schedule", identifier: leagueId)
                        completion(.success(data))
                    case .failure(let error):
                        print("DEBUG: API call failed: \(error)")
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: - Generic Fetch Helper
    private func fetchData<T: Decodable>(from url: URL, completion: @escaping (Result<T, APIError>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("DEBUG: Fetching data from API: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("DEBUG: Network error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("DEBUG: Invalid response")
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                var errorMessage: String? = nil
                if let data = data, let msg = String(data: data, encoding: .utf8) {
                    errorMessage = msg
                }
                print("DEBUG: Server error: \(httpResponse.statusCode) - \(errorMessage ?? "No message")")
                DispatchQueue.main.async {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: errorMessage)))
                }
                return
            }

            guard let data = data else {
                print("DEBUG: No data received")
                DispatchQueue.main.async {
                    completion(.failure(.noData))
                }
                return
            }

            // Log raw JSON response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("DEBUG: Raw JSON response: \(jsonString)")
            }

            do {
                let decodedData = try JSONDecoder().decode(T.self, from: data)
                print("DEBUG: Successfully decoded API response")
                DispatchQueue.main.async {
                    completion(.success(decodedData))
                }
            } catch let decodingError {
                print("DEBUG: Decoding error: \(decodingError)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError(decodingError)))
                }
            }
        }.resume()
    }
    
    // MARK: - Cache Management Functions
    func clearCache(for type: String, identifier: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: Cannot clear cache - no user ID")
            return
        }
        
        print("DEBUG: Clearing cache for \(type) with identifier \(identifier)")
        
        db.collection("trackerCache").document(getCacheKey(for: type, identifier: identifier)).delete { error in
            if let error = error {
                print("DEBUG: Error clearing cache: \(error)")
            } else {
                print("DEBUG: Successfully cleared cache")
            }
        }
    }
    
    func clearAllCache() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: Cannot clear all cache - no user ID")
            return
        }
        
        print("DEBUG: Clearing all cache for user \(userId)")
        
        db.collection("trackerCache")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("DEBUG: Error getting cache documents: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("DEBUG: No cache documents found")
                    return
                }
                
                print("DEBUG: Found \(documents.count) cache documents to delete")
                
                for document in documents {
                    document.reference.delete { error in
                        if let error = error {
                            print("DEBUG: Error deleting cache document: \(error)")
                        }
                    }
                }
                
                print("DEBUG: Cache clearing completed")
            }
    }
} 