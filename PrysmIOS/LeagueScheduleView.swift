import SwiftUI

struct LeagueScheduleView: View {
    let leagueId: String
    @State private var matches: [LeagueMatch] = []
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading matches...")
                    .padding()
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.title)
                    Text("Error loading matches")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else if matches.isEmpty {
                VStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                        .padding()
                    Text("No matches scheduled")
                        .font(.headline)
                }
                .padding()
            } else {
                List {
                    ForEach(matches) { match in
                        MatchRow(match: match)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .onAppear {
            fetchMatches()
        }
    }
    
    private func fetchMatches() {
        isLoading = true
        error = nil
        
        let apiId = LeagueManager.shared.getApiId(for: leagueId)
        TrackerAPIService.shared.fetchLeagueSchedule(leagueId: apiId) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.matches = response.matches ?? []
                    // Sort by date (upcoming first, then recent)
                    self.matches.sort { 
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime]
                        let date1 = formatter.date(from: $0.date ?? "") ?? Date()
                        let date2 = formatter.date(from: $1.date ?? "") ?? Date()
                        return date1 < date2
                    }
                case .failure(let apiError):
                    self.error = apiError.localizedDescription
                }
            }
        }
    }
}

// Response structure for decoding API response
struct LeagueMatchesResponse: Codable {
    let competitionId: String
    let competitionName: String
    let matches: [MatchData]
    
    struct MatchData: Codable {
        let id: String
        let homeTeam: String
        let awayTeam: String
        let date: String
        let status: String
        let homeScore: Int?
        let awayScore: Int?
        let competition: String?
        let matchday: Int?
    }
}

struct MatchRow: View {
    let match: LeagueMatch
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(match.homeTeam ?? "Home")
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                Text(scoreText(for: match))
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 60)
                    .foregroundColor(statusColor(match.status ?? ""))
                
                Text(match.awayTeam ?? "Away")
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack {
                Text(match.displayDateTime)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(match.status ?? "Unknown")
                    .font(.caption)
                    .foregroundColor(statusColor(match.status ?? ""))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "LIVE", "IN_PLAY":
            return .red
        case "FINISHED":
            return .gray
        case "POSTPONED", "CANCELED", "CANCELLED":
            return .orange
        default:
            return .blue
        }
    }
    
    private func scoreText(for match: LeagueMatch) -> String {
        if let homeScore = match.homeScore, let awayScore = match.awayScore {
            return "\(homeScore) - \(awayScore)"
        }
        return "vs"
    }
}

struct LeagueScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LeagueScheduleView(leagueId: "PL")
        }
    }
} 