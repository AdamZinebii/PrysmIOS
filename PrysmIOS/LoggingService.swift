import Foundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

// MARK: - Event Types
enum UserEvent: String, CaseIterable {
    case appEntered = "app_entered"
    case topicSummaryViewed = "topic_summary_viewed"
    case subtopicSummaryViewed = "subtopic_summary_viewed"
    case redditSummaryViewed = "reddit_summary_viewed"
    case podcastPlayed = "podcast_played"
    case podcastPaused = "podcast_paused"
    case podcastSeeked = "podcast_seeked"
    case settingsOpened = "settings_opened"
    case preferencesOpened = "preferences_opened"
    case refreshTriggered = "refresh_triggered"
}

// MARK: - Log Entry
struct LogEntry {
    let timestamp: Date
    let event: UserEvent
    let details: [String: Any]?
    
    func formatForFile() -> String {
        // UTC timestamp
        let utcFormatter = DateFormatter()
        utcFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        utcFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let utcTimestamp = utcFormatter.string(from: timestamp)
        
        // Local timestamp
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        localFormatter.timeZone = TimeZone.current
        let localTimestamp = localFormatter.string(from: timestamp)
        let localTZ = TimeZone.current.abbreviation() ?? "LOCAL"
        
        var logLine = "[\(utcTimestamp) UTC | \(localTimestamp) \(localTZ)] \(event.rawValue)"
        
        if let details = details, !details.isEmpty {
            let detailsData = try? JSONSerialization.data(withJSONObject: details)
            if let detailsData = detailsData,
               let detailsString = String(data: detailsData, encoding: .utf8) {
                logLine += " | \(detailsString)"
            }
        }
        
        return logLine
    }
}

// MARK: - Logging Service
class LoggingService: ObservableObject {
    static let shared = LoggingService()
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private var pendingLogs: [LogEntry] = []
    private var isUploading = false
    
    private init() {
        // Start periodic upload
        setupPeriodicUpload()
    }
    
    // MARK: - Public Logging Methods
    
    /// Log when user enters the app
    func logAppEntered() {
        logEvent(.appEntered, details: [
            "session_start": Date().timeIntervalSince1970
        ])
    }
    
    /// Log when user views a topic summary
    func logTopicSummaryViewed(topicName: String, topicId: String? = nil) {
        logEvent(.topicSummaryViewed, details: [
            "topic_name": topicName,
            "topic_id": topicId as Any
        ])
    }
    
    /// Log when user views a subtopic summary
    func logSubtopicSummaryViewed(subtopicName: String, parentTopic: String? = nil) {
        logEvent(.subtopicSummaryViewed, details: [
            "subtopic_name": subtopicName,
            "parent_topic": parentTopic as Any
        ])
    }
    
    /// Log when user views reddit summary
    func logRedditSummaryViewed(subtopicName: String, parentTopic: String? = nil) {
        logEvent(.redditSummaryViewed, details: [
            "subtopic_name": subtopicName,
            "parent_topic": parentTopic as Any
        ])
    }
    
    /// Log when user plays podcast
    func logPodcastPlayed(podcastUrl: String? = nil, duration: Double? = nil) {
        logEvent(.podcastPlayed, details: [
            "podcast_url": podcastUrl as Any,
            "duration_seconds": duration as Any
        ])
    }
    
    /// Log when user pauses podcast
    func logPodcastPaused(currentTime: Double? = nil, totalDuration: Double? = nil) {
        logEvent(.podcastPaused, details: [
            "current_time_seconds": currentTime as Any,
            "total_duration_seconds": totalDuration as Any
        ])
    }
    
    /// Log when user seeks in podcast
    func logPodcastSeeked(fromTime: Double, toTime: Double) {
        logEvent(.podcastSeeked, details: [
            "from_time_seconds": fromTime,
            "to_time_seconds": toTime,
            "seek_delta": toTime - fromTime
        ])
    }
    
    /// Log when user opens settings
    func logSettingsOpened() {
        logEvent(.settingsOpened)
    }
    
    /// Log when user opens preferences
    func logPreferencesOpened() {
        logEvent(.preferencesOpened)
    }
    
    /// Log when user triggers refresh
    func logRefreshTriggered(context: String? = nil) {
        logEvent(.refreshTriggered, details: [
            "context": context as Any
        ])
    }
    
    // MARK: - Private Methods
    
    private func logEvent(_ event: UserEvent, details: [String: Any]? = nil) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ LoggingService: Cannot log event - no authenticated user")
            return
        }
        
        let logEntry = LogEntry(
            timestamp: Date(),
            event: event,
            details: details
        )
        
        print("📝 LoggingService: \(event.rawValue) - \(details?.description ?? "no details")")
        
        // Add to pending logs
        pendingLogs.append(logEntry)
        
        // Try to upload if not already uploading
        if !isUploading {
            uploadPendingLogs()
        }
    }
    
    private func setupPeriodicUpload() {
        // Upload logs every 30 seconds if there are pending logs
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            if !self.pendingLogs.isEmpty && !self.isUploading {
                self.uploadPendingLogs()
            }
        }
    }
    
    private func uploadPendingLogs() {
        guard let userId = Auth.auth().currentUser?.uid,
              !pendingLogs.isEmpty else {
            return
        }
        
        isUploading = true
        let logsToUpload = pendingLogs
        
        Task {
            do {
                try await uploadLogs(userId: userId, logs: logsToUpload)
                
                await MainActor.run {
                    // Remove uploaded logs from pending
                    self.pendingLogs.removeFirst(logsToUpload.count)
                    self.isUploading = false
                    
                    print("✅ LoggingService: Successfully uploaded \(logsToUpload.count) log entries")
                }
            } catch {
                await MainActor.run {
                    self.isUploading = false
                    print("❌ LoggingService: Failed to upload logs: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func uploadLogs(userId: String, logs: [LogEntry]) async throws {
        // Create log content
        let logLines = logs.map { $0.formatForFile() }
        let logContent = logLines.joined(separator: "\n")
        
        // Get reference to user's log file
        let logFileName = "\(userId).txt"
        let storageRef = storage.reference().child("logging").child(logFileName)
        
        // Download existing content if it exists
        var existingContent = ""
        do {
            let existingData = try await storageRef.data(maxSize: 10 * 1024 * 1024) // 10MB max
            existingContent = String(data: existingData, encoding: .utf8) ?? ""
            if !existingContent.isEmpty {
                existingContent += "\n"
            }
        } catch {
            // File doesn't exist yet, that's fine
            print("📝 LoggingService: Creating new log file for user \(userId)")
        }
        
        // Append new logs
        let updatedContent = existingContent + logContent
        guard let data = updatedContent.data(using: .utf8) else {
            throw NSError(domain: "LoggingService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to encode log content"])
        }
        
        // Upload updated content
        let metadata = StorageMetadata()
        metadata.contentType = "text/plain"
        metadata.customMetadata = [
            "user_id": userId,
            "last_updated": ISO8601DateFormatter().string(from: Date()),
            "entries_count": String(logs.count)
        ]
        
        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        
        // Also update a summary in Firestore for quick access
        try await updateLogSummary(userId: userId, newEntriesCount: logs.count)
    }
    
    private func updateLogSummary(userId: String, newEntriesCount: Int) async throws {
        let logSummaryRef = db.collection("logging_summary").document(userId)
        
        try await db.runTransaction { transaction, errorPointer in
            do {
                let summaryDoc = try transaction.getDocument(logSummaryRef)
                
                let currentCount = summaryDoc.data()?["total_entries"] as? Int ?? 0
                let lastUpdated = Timestamp()
                
                transaction.setData([
                    "user_id": userId,
                    "total_entries": currentCount + newEntriesCount,
                    "last_updated": lastUpdated,
                    "latest_entries_count": newEntriesCount
                ], forDocument: logSummaryRef)
                
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    // MARK: - Public Utility Methods
    
    /// Force upload any pending logs immediately
    func flushLogs() async {
        guard !pendingLogs.isEmpty else { return }
        
        while !pendingLogs.isEmpty && isUploading {
            // Wait for current upload to finish
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        if !pendingLogs.isEmpty {
            uploadPendingLogs()
        }
    }
    
    /// Get log summary for current user
    func getLogSummary() async -> [String: Any]? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }
        
        do {
            let doc = try await db.collection("logging_summary").document(userId).getDocument()
            return doc.data()
        } catch {
            print("❌ LoggingService: Failed to get log summary: \(error.localizedDescription)")
            return nil
        }
    }
} 