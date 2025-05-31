import Foundation
import FirebaseAuth

class VideoAPIService {
    static let shared = VideoAPIService()
    private init() {}
    
    private let baseUrl = "https://us-central1-prysmios.cloudfunctions.net"
    
    enum VideoAPIError: Error {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case decodingError(Error)
        case noData
        case serverError(statusCode: Int, message: String?)
        case authenticationError
        case noUserAuthenticated
    }
    
    // MARK: - Get User Video Cache
    func getUserVideoCache(userId: String) async throws -> VideoCacheResponse {
        guard let url = URL(string: "\(baseUrl)/get_user_video_cache?user_id=\(userId)") else {
            throw VideoAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("*", forHTTPHeaderField: "Origin")
        
        // Add authentication if available
        if let user = Auth.auth().currentUser {
            do {
                let token = try await user.getIDToken()
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } catch {
                print("Failed to get ID token: \(error)")
                // Continue without auth - some endpoints might not require it
            }
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw VideoAPIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                do {
                    let videoResponse = try decoder.decode(VideoCacheResponse.self, from: data)
                    return videoResponse
                } catch {
                    print("Decoding error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Response JSON: \(jsonString)")
                    }
                    throw VideoAPIError.decodingError(error)
                }
            } else {
                let errorMessage = String(data: data, encoding: .utf8)
                throw VideoAPIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
        } catch {
            if error is VideoAPIError {
                throw error
            } else {
                throw VideoAPIError.networkError(error)
            }
        }
    }
    
    // MARK: - Generate Article Videos
    func generateArticleVideos(userId: String) async throws -> GenerateVideosResponse {
        guard let url = URL(string: "\(baseUrl)/generate_article_videos") else {
            throw VideoAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 600 // 10 minutes - video generation takes time
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("*", forHTTPHeaderField: "Origin")
        
        // Add authentication if available (optional for public endpoints)
        if let user = Auth.auth().currentUser {
            do {
                let token = try await user.getIDToken()
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } catch {
                print("Failed to get ID token: \(error)")
                // Continue without auth - endpoints are public
            }
        }
        
        let requestBody = GenerateVideosRequest(user_id: userId)
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw VideoAPIError.networkError(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw VideoAPIError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                do {
                    let generateResponse = try decoder.decode(GenerateVideosResponse.self, from: data)
                    return generateResponse
                } catch {
                    print("Decoding error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Response JSON: \(jsonString)")
                    }
                    throw VideoAPIError.decodingError(error)
                }
            } else {
                let errorMessage = String(data: data, encoding: .utf8)
                throw VideoAPIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
        } catch {
            if error is VideoAPIError {
                throw error
            } else {
                throw VideoAPIError.networkError(error)
            }
        }
    }
    
    // MARK: - Clear User Video Cache
    func clearUserVideoCache(userId: String) async throws -> Bool {
        guard let url = URL(string: "\(baseUrl)/clear_user_video_cache") else {
            throw VideoAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("*", forHTTPHeaderField: "Origin")
        
        // Add authentication if available (optional for public endpoints)
        if let user = Auth.auth().currentUser {
            do {
                let token = try await user.getIDToken()
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } catch {
                print("Failed to get ID token: \(error)")
                // Continue without auth - endpoints are public
            }
        }
        
        let requestBody = ["user_id": userId]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw VideoAPIError.networkError(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw VideoAPIError.invalidResponse
            }
            
            return httpResponse.statusCode == 200
        } catch {
            if error is VideoAPIError {
                throw error
            } else {
                throw VideoAPIError.networkError(error)
            }
        }
    }
} 