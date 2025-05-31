import SwiftUI

struct MatchDetailView: View {
    let matchId: String
    @State private var matchData: MatchScoreData?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Loading match details...")
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else if let data = matchData {
                CompetitionHeader(competitionCode: data.competition, matchDate: data.displayDateTime)
                
                HStack(alignment: .center, spacing: 10) {
                    TeamView(name: data.home ?? "Home")
                    ScoreView(scoreHome: data.scoreHome, scoreAway: data.scoreAway, status: data.displayStatus)
                    TeamView(name: data.away ?? "Away")
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .shadow(radius: 3)
                
                if data.status == "IN_PLAY" || data.status == "PAUSED" {
                    Text("Match en cours") // Vous pourriez ajouter la minute ici si disponible
                        .font(.footnote)
                        .foregroundColor(.orange)
                } else if data.status == "FINISHED" {
                    Text("Match terminé")
                        .font(.footnote)
                        .foregroundColor(.green)
                }
                Spacer() // Pour pousser le contenu vers le haut
            } else {
                Text("No match data available.")
            }
        }
        .padding()
        .navigationTitle("Match Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchMatchDetails()
        }
    }

    func fetchMatchDetails() {
        isLoading = true
        errorMessage = nil
        TrackerAPIService.shared.fetchMatchScore(matchId: matchId) { result in
            isLoading = false
            switch result {
            case .success(let data):
                // football-data.org peut retourner null pour les scores si le match n'a pas commencé
                // ou si les scores ne sont pas encore disponibles. Notre struct gère les optionnels.
                self.matchData = data
                if data.home == nil && data.away == nil {
                    // Cela peut arriver si l'ID de match est valide mais les données sont minimales (par ex. match très futur)
                    self.errorMessage = "Match details are not yet fully available."
                }
            case .failure(let error):
                self.errorMessage = "Failed to load match: \(error.localizedDescription)"
                print("Error fetching match details: \(error)")
            }
        }
    }
}

// Sous-vues pour MatchDetailView
struct CompetitionHeader: View {
    let competitionCode: String?
    let matchDate: String
    
    var body: some View {
        VStack {
            Text(competitionName(from: competitionCode) ?? "-") // Affiche le nom complet de la compétition si possible
                .font(.headline)
            Text(matchDate)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.bottom, 10)
    }
    
    // Fonction d'aide pour obtenir un nom de compétition plus lisible à partir du code
    // Vous pouvez étendre cela avec plus de codes de ligue.
    private func competitionName(from code: String?) -> String? {
        guard let code = code else { return nil }
        switch code.uppercased() {
        case "PL": return "Premier League"
        case "BL1": return "Bundesliga"
        case "SA": return "Serie A (Italy)"
        case "PD": return "La Liga (Spain)"
        case "FL1": return "Ligue 1 (France)"
        case "CL": return "Champions League"
        // Ajoutez d'autres codes ici
        default: return code // Retourne le code si non mappé
        }
    }
}

struct TeamView: View {
    let name: String
    // let crestUrl: String? // Pour ajouter le logo de l'équipe plus tard

    var body: some View {
        VStack {
            // AsyncImage(url: URL(string: crestUrl ?? "")) { image in image.resizable() } 
            //     placeholder: { Color.gray.opacity(0.3) }
            //     .frame(width: 50, height: 50)
            //     .clipShape(Circle())
            Text(name)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 100) // Largeur fixe pour aider à l'alignement
    }
}

struct ScoreView: View {
    let scoreHome: Int?
    let scoreAway: Int?
    let status: String

    var body: some View {
        VStack {
            if let sh = scoreHome, let sa = scoreAway {
                Text("\(sh) - \(sa)")
                    .font(.system(size: 36, weight: .bold))
            } else {
                Text("vs") // Ou un tiret, ou rien si le match n'est pas commencé
                    .font(.system(size: 28, weight: .light))
                    .padding(.vertical, 5) // Ajuste pour l'alignement vertical
            }
            Text(status)
                .font(.caption)
                .foregroundColor(statusColor())
        }
        .frame(minWidth: 80) // Donne de l'espace pour le score
    }
    
    private func statusColor() -> Color {
        switch status.lowercased() {
        case "live": return .orange
        case "terminé": return .green
        default: return .gray
        }
    }
}


struct MatchDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MatchDetailView(matchId: "PREVIEW_ID_FINISHED")
        }
        NavigationView {
            MatchDetailView(matchId: "PREVIEW_ID_LIVE")
        }
        NavigationView {
            MatchDetailView(matchId: "PREVIEW_ID_SCHEDULED")
        }
        NavigationView {
            MatchDetailView(matchId: "ERROR_ID") // Pour tester l'erreur
        }
    }
    
    static var mockMatchDataFinished: MatchScoreData {
        MatchScoreData(matchId: "419300", home: "Man City", away: "Chelsea", scoreHome: 1, scoreAway: 0, status: "FINISHED", utcDate: "2024-05-20T15:00:00Z", competition: "PL")
    }
    static var mockMatchDataLive: MatchScoreData {
        MatchScoreData(matchId: "419301", home: "Liverpool", away: "Arsenal", scoreHome: 1, scoreAway: 1, status: "IN_PLAY", utcDate: "2024-05-20T17:00:00Z", competition: "CL")
    }
    static var mockMatchDataScheduled: MatchScoreData {
        MatchScoreData(matchId: "419302", home: "Real Madrid", away: "FC Bayern", scoreHome: nil, scoreAway: nil, status: "SCHEDULED", utcDate: "2024-05-28T19:00:00Z", competition: "CL")
    }
} 