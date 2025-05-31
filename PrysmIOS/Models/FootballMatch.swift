import Foundation

struct FootballMatch: Identifiable {
    let id: String
    let homeTeam: String
    let awayTeam: String
    let date: String
    let status: String
    let homeScore: Int?
    let awayScore: Int?
    
    // For upcoming matches where score isn't available yet
    init(id: String, homeTeam: String, awayTeam: String, date: String, status: String = "SCHEDULED") {
        self.id = id
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.date = date
        self.status = status
        self.homeScore = nil
        self.awayScore = nil
    }
    
    // For matches with scores
    init(id: String, homeTeam: String, awayTeam: String, date: String, status: String, homeScore: Int, awayScore: Int) {
        self.id = id
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.date = date
        self.status = status
        self.homeScore = homeScore
        self.awayScore = awayScore
    }
    
    var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        if let date = dateFormatter.date(from: date) {
            dateFormatter.dateFormat = "MMM d, h:mm a"
            return dateFormatter.string(from: date)
        }
        return date
    }
    
    var scoreText: String {
        if let homeScore = homeScore, let awayScore = awayScore {
            return "\(homeScore) - \(awayScore)"
        }
        return "vs"
    }
    
    var statusText: String {
        switch status {
        case "SCHEDULED": return "Upcoming"
        case "LIVE", "IN_PLAY": return "LIVE"
        case "FINISHED": return "FT"
        case "POSTPONED": return "Postponed"
        case "CANCELED", "CANCELLED": return "Canceled"
        default: return status
        }
    }
} 