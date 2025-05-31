import Foundation

struct LeagueInfo {
    let id: String
    let name: String
    let country: String
    let apiId: String  // ID utilisé par l'API football-data.org
}

class LeagueManager {
    static let shared = LeagueManager()
    
    private let leagues: [LeagueInfo] = [
        // Top 5 Leagues
        LeagueInfo(id: "PL", name: "Premier League", country: "England", apiId: "2021"),
        LeagueInfo(id: "BL1", name: "Bundesliga", country: "Germany", apiId: "2002"),
        LeagueInfo(id: "SA", name: "Serie A", country: "Italy", apiId: "2019"),
        LeagueInfo(id: "PD", name: "La Liga", country: "Spain", apiId: "2014"),
        LeagueInfo(id: "FL1", name: "Ligue 1", country: "France", apiId: "2015"),
        
        // European Competitions
        LeagueInfo(id: "CL", name: "Champions League", country: "Europe", apiId: "2001"),
        LeagueInfo(id: "EL", name: "Europa League", country: "Europe", apiId: "2000"),
        LeagueInfo(id: "ECL", name: "Europa Conference League", country: "Europe", apiId: "2007"),
        
        // International Competitions
        LeagueInfo(id: "WC", name: "World Cup", country: "International", apiId: "2000"),
        LeagueInfo(id: "EC", name: "European Championship", country: "Europe", apiId: "2018"),
        LeagueInfo(id: "NLC", name: "Nations League", country: "Europe", apiId: "2019"),
        
        // Other Major Leagues
        LeagueInfo(id: "PPL", name: "Primeira Liga", country: "Portugal", apiId: "2017"),
        LeagueInfo(id: "DED", name: "Eredivisie", country: "Netherlands", apiId: "2003"),
        LeagueInfo(id: "BSA", name: "Brasileirão", country: "Brazil", apiId: "2013"),
        LeagueInfo(id: "CLI", name: "Copa Libertadores", country: "South America", apiId: "2152"),
        LeagueInfo(id: "CLO", name: "Copa Sudamericana", country: "South America", apiId: "2151"),
        LeagueInfo(id: "CLD", name: "Copa del Rey", country: "Spain", apiId: "2014"),
        LeagueInfo(id: "FAC", name: "FA Cup", country: "England", apiId: "2021"),
        LeagueInfo(id: "DFB", name: "DFB Pokal", country: "Germany", apiId: "2002"),
        LeagueInfo(id: "CDR", name: "Coppa Italia", country: "Italy", apiId: "2019"),
        LeagueInfo(id: "FRA", name: "Coupe de France", country: "France", apiId: "2015")
    ]
    
    func getLeagueName(for id: String) -> String {
        return leagues.first(where: { $0.id == id })?.name ?? id
    }
    
    func getLeagueInfo(for id: String) -> LeagueInfo? {
        return leagues.first(where: { $0.id == id })
    }
    
    func getApiId(for id: String) -> String {
        return leagues.first(where: { $0.id == id })?.apiId ?? id
    }
    
    func getAllLeagues() -> [LeagueInfo] {
        return leagues
    }
    
    func getLeaguesByCountry(_ country: String) -> [LeagueInfo] {
        return leagues.filter { $0.country == country }
    }
} 