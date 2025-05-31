import SwiftUI
// Add import for TrackerDataModels to use the StandingRow defined there
// You might need to adjust the module name depending on your project structure
import Foundation

struct LeagueStandingView: View {
    let leagueId: String
    @State private var standings: [StandingRow] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var leagueName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(leagueName)
                .font(.headline)
                .padding(.bottom, 4)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            } else if standings.isEmpty {
                Text("No standings available")
                    .foregroundColor(.gray)
                    .font(.caption)
            } else {
                ForEach(standings.prefix(3)) { standing in
                    HStack {
                        Text("\(standing.rank ?? 0).")
                            .frame(width: 25, alignment: .leading)
                        Text(standing.team ?? "Unknown")
                        Spacer()
                        Text("\(standing.points ?? 0) pts")
                            .foregroundColor(.gray)
                    }
                    .font(.caption)
                }
            }
        }
        .onAppear {
            leagueName = LeagueManager.shared.getLeagueName(for: leagueId)
            fetchStandings()
        }
    }
    
    private func fetchStandings() {
        isLoading = true
        error = nil
        
        let apiId = LeagueManager.shared.getApiId(for: leagueId)
        TrackerAPIService.shared.fetchLeagueStandings(competitionId: apiId) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.standings = response.table ?? []
                case .failure(let apiError):
                    self.error = apiError.localizedDescription
                }
            }
        }
    }
}

// Sous-vues pour LeagueStandingView
struct StandingHeaderRow: View {
    var body: some View {
        HStack {
            Text("#").frame(width: 30, alignment: .leading)
            Text("Team").frame(maxWidth: .infinity, alignment: .leading)
            Text("Pl").frame(width: 30, alignment: .trailing)
            Text("Pts").frame(width: 40, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.secondary)
    }
}

struct StandingRowView: View {
    let row: StandingRow

    var body: some View {
        HStack {
            Text("\(row.rank ?? 0)").frame(width: 30, alignment: .leading)
            Text(row.team ?? "N/A").frame(maxWidth: .infinity, alignment: .leading)
            Text("\(row.played ?? 0)").frame(width: 30, alignment: .trailing)
            Text("\(row.points ?? 0)").frame(width: 40, alignment: .trailing).bold()
        }
        .font(.subheadline)
    }
}

struct LeagueStandingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LeagueStandingView(leagueId: "PL") 
        }
        NavigationView {
             LeagueStandingView(leagueId: "CL_NO_DATA") // Test case for no data or error
        }
    }
    
    static var mockStandingsTablePL: [StandingRow] = [
        StandingRow(rank: 1, team: "Liverpool", played: 28, points: 65),
        StandingRow(rank: 2, team: "Man City", played: 27, points: 62),
        StandingRow(rank: 3, team: "Arsenal", played: 28, points: 60),
        StandingRow(rank: 4, team: "Chelsea", played: 28, points: 55),
        StandingRow(rank: 5, team: "Man Utd", played: 27, points: 50)
    ]
} 