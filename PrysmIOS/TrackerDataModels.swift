import Foundation

// MARK: - Match Score Data
struct MatchScoreData: Codable, Identifiable {
    let id = UUID() // For Identifiable in SwiftUI lists, not from API directly for this struct
    var matchId: String? // Reflects the ID used to fetch
    var home: String?
    var away: String?
    var scoreHome: Int?
    var scoreAway: Int?
    var status: String?      // e.g., "IN_PLAY", "FINISHED", "TIMED", "SCHEDULED"
    var utcDate: String?     // ISO8601 date string
    var competition: String? // e.g., "PL" (League Code)
    
    // Computed property for displayable date/time
    var displayDateTime: String {
        guard let dateStr = utcDate else { return "N/A" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // Handle optional fractional seconds
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        } else {
            // Fallback for slightly different ISO formats if needed
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateStr) {
                 let displayFormatter = DateFormatter()
                 displayFormatter.dateStyle = .medium
                 displayFormatter.timeStyle = .short
                 return displayFormatter.string(from: date)
            }
        }
        return dateStr // Fallback to raw string if parsing fails
    }
    
    var displayStatus: String {
        guard let status = status else { return "-" }
        switch status {
        case "IN_PLAY": return "Live"
        case "PAUSED": return "HT"
        case "FINISHED": return "Terminé"
        case "TIMED", "SCHEDULED": return displayDateTime
        default: return status.capitalized
        }
    }
}

// MARK: - League Standing Data
struct LeagueStandingResponse: Codable {
    let competitionId: String?
    let table: [StandingRow]?
}

struct StandingRow: Codable, Identifiable, Hashable {
    // football-data.org returns id in team object, but if table rows don't have unique IDs, 
    // we might need to rely on team name or rank for Hashable/Identifiable in some contexts.
    // For now, assuming team.id will be sufficient if we make team identifiable or use rank.
    // Let's use rank as id for simplicity in the list, assuming it's unique per table.
    var id: Int { rank ?? Int.random(in: 0...10000) } // Use rank as ID, fallback for safety
    
    let rank: Int?
    let team: String? // Team short name or name
    let played: Int?
    let points: Int?
    // Add more fields as needed: wins, draws, losses, goalDifference, teamId (if provided by backend)
    // let teamId: Int? // If your backend can provide team ID for linking or fetching crest
}

// MARK: - Asset Price Data
struct AssetPriceData: Codable, Identifiable {
    let id = UUID() // For Identifiable in SwiftUI lists
    var symbol: String?
    var currentPrice: Double?
    var priceChange: Double?
    var lastUpdated: String?
    var historicalData: [AssetPriceHistoryPoint]?
    
    // Computed property to maintain compatibility with existing code
    var latest: Double? {
        return currentPrice
    }
    
    // Computed property to maintain compatibility with existing code
    var history: [AssetPriceHistoryPoint]? {
        return historicalData
    }
}

struct AssetPriceHistoryPoint: Codable, Identifiable, Hashable {
    let id = UUID() // For Identifiable in SwiftUI lists (if directly listed)
    var date: String // Format "YYYY-MM-DD"
    var price: Double
    var volume: Int
    
    // Add CodingKeys to ensure exact JSON field mapping
    enum CodingKeys: String, CodingKey {
        case date
        case price
        case volume
    }
    
    // To conform to Plottable for Charts if needed (requires date conversion)
    var plottableDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date) ?? Date()
    }
    
    // Conform to Hashable manually because UUID makes it unique always
    // For chart previews or unique identification in sets, date is better.
    static func == (lhs: AssetPriceHistoryPoint, rhs: AssetPriceHistoryPoint) -> Bool {
        lhs.date == rhs.date && lhs.price == rhs.price
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(date)
        hasher.combine(price)
    }
}

// MARK: - League Schedule Data
struct LeagueMatch: Codable, Identifiable {
    let id: String
    let date: String?  // Changed from utcDate to date to match API response
    let status: String?
    let matchday: Int?
    let homeTeam: String?
    let awayTeam: String?
    let homeScore: Int?
    let awayScore: Int?
    
    var displayDateTime: String {
        guard let dateStr = date else { return "N/A" }  // Changed from utcDate to date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateStr
    }
}

struct LeagueScheduleResponse: Codable {
    let competitionName: String?
    let matches: [LeagueMatch]?
} 