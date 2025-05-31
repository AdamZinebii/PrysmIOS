import Foundation
import FirebaseAuth

class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    @Published var isUpdating = false
    @Published var updateError: String?
    
    private let updateEndpoint = "https://update-endpoint-za2ovv4k4q-uc.a.run.app"
    
    private init() {}
    
    func triggerFirstTimeUpdate(userId: String) async {
        print("🚀 [UpdateService] Starting first time update for user: \(userId)")
        
        await MainActor.run {
            isUpdating = true
            updateError = nil
        }
        
        do {
            guard let url = URL(string: updateEndpoint) else {
                throw UpdateError.invalidURL
            }
            
            let payload: [String: Any] = [
                "user_id": userId
                // Using default values: presenter_name="Alex", language="en", voice_id="cmudN4ihcI42n48urXgc"
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 900 // 15 minutes as specified in docs
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            print("🔍 [UpdateService] Sending request to update endpoint...")
            print("📦 [UpdateService] Payload: \(payload)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UpdateError.invalidResponse
            }
            
            print("📊 [UpdateService] Response status code: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 [UpdateService] Response body: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                // Parse the response to check if it was successful
                let decoder = JSONDecoder()
                let updateResponse = try decoder.decode(UpdateResponse.self, from: data)
                
                if updateResponse.success {
                    print("✅ [UpdateService] Update completed successfully!")
                    print("🎵 [UpdateService] Audio URL: \(updateResponse.podcastResult?.audioUrl ?? "None")")
                    print("📰 [UpdateService] Articles count: \(updateResponse.refreshResult?.totalArticles ?? 0)")
                    
                    await MainActor.run {
                        isUpdating = false
                    }
                } else {
                    print("❌ [UpdateService] Update failed: \(updateResponse.error ?? "Unknown error")")
                    throw UpdateError.updateFailed(updateResponse.error ?? "Unknown error")
                }
            } else {
                print("❌ [UpdateService] HTTP error: \(httpResponse.statusCode)")
                let errorMessage = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw UpdateError.serverError(httpResponse.statusCode, errorMessage)
            }
            
        } catch {
            print("❌ [UpdateService] Error during update: \(error)")
            await MainActor.run {
                updateError = error.localizedDescription
                isUpdating = false
            }
        }
    }
}

// MARK: - Update Response Models

struct UpdateResponse: Codable {
    let success: Bool
    let userId: String
    let pipelineCompleted: Bool
    let refreshResult: RefreshResult?
    let reportResult: ReportResult?
    let podcastResult: PodcastResult?
    let notificationResult: NotificationResult?
    let pipelineTimestamp: String?
    let error: String?
    let message: String?
    let timestamp: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case userId = "user_id"
        case pipelineCompleted = "pipeline_completed"
        case refreshResult = "refresh_result"
        case reportResult = "report_result"
        case podcastResult = "podcast_result"
        case notificationResult = "notification_result"
        case pipelineTimestamp = "pipeline_timestamp"
        case error
        case message
        case timestamp
    }
}

struct RefreshResult: Codable {
    let success: Bool
    let totalArticles: Int
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case totalArticles = "total_articles"
        case timestamp
    }
}

struct ReportResult: Codable {
    let success: Bool
    let reportsCount: Int
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case reportsCount = "reports_count"
        case timestamp
    }
}

struct PodcastResult: Codable {
    let success: Bool
    let audioUrl: String?
    let scriptStorageUrl: String?
    let metadata: PodcastMetadata?
    
    enum CodingKeys: String, CodingKey {
        case success
        case audioUrl = "audio_url"
        case scriptStorageUrl = "script_storage_url"
        case metadata
    }
}

struct PodcastMetadata: Codable {
    let userId: String
    let wordCount: Int
    let estimatedDuration: String
    let audioSizeBytes: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case wordCount = "word_count"
        case estimatedDuration = "estimated_duration"
        case audioSizeBytes = "audio_size_bytes"
    }
}

struct NotificationResult: Codable {
    let success: Bool
    let messageId: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case messageId = "message_id"
    }
}

// MARK: - Errors

enum UpdateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid update endpoint URL"
        case .invalidResponse:
            return "Invalid response from update service"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        }
    }
} 