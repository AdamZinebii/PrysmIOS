import SwiftUI
import FirebaseAuth

// --- API Response Structures ---

// For Alpha Vantage SYMBOL_SEARCH
struct AlphaVantageSearchResponse: Codable {
    let bestMatches: [AlphaVantageMatch]?
}

struct AlphaVantageMatch: Codable, Hashable {
    let symbol: String?       // "1. symbol"
    let name: String?         // "2. name"
    let type: String?         // "3. type"
    let region: String?       // "4. region"
    let marketOpen: String?   // "5. marketOpen"
    let marketClose: String?  // "6. marketClose"
    let timezone: String?     // "7. timezone"
    let currency: String?     // "8. currency"
    let matchScore: String?   // "9. matchScore"

    // Map JSON keys with numbers and spaces to struct properties
    enum CodingKeys: String, CodingKey {
        case symbol = "1. symbol"
        case name = "2. name"
        case type = "3. type"
        case region = "4. region"
        case marketOpen = "5. marketOpen"
        case marketClose = "6. marketClose"
        case timezone = "7. timezone"
        case currency = "8. currency"
        case matchScore = "9. matchScore"
    }
}

// For football-data.org /competitions
struct FootballDataCompetitionResponse: Codable {
    let competitions: [FootballDataCompetition]?
    let count: Int?
}

struct FootballDataCompetition: Codable, Hashable, Identifiable {
    let id: Int
    let name: String?
    let code: String?
    let emblem: String?
    let area: FootballDataArea?
    let currentSeason: FootballDataSeason?
}

struct FootballDataArea: Codable, Hashable {
    let id: Int?
    let name: String?
    let code: String?
    let flag: String?
}

struct FootballDataSeason: Codable, Hashable {
    let id: Int?
    let startDate: String?
    let endDate: String?
    let currentMatchday: Int?
    let winner: FootballDataTeam?
}

struct FootballDataTeamResponse: Codable {
    let teams: [FootballDataTeam]?
    let count: Int?
}

struct FootballDataTeam: Codable, Hashable, Identifiable {
    let id: Int
    let name: String?
    let shortName: String?
    let tla: String?
    let crest: String?
    let address: String?
    let website: String?
    let founded: Int?
    let venue: String?
    let area: FootballDataArea?
}

struct SearchResultItem: Identifiable, Hashable {
    let id: String
    let name: String
}

struct ResearchTopicsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    
    // Passed from NewsSubjectsView
    let newsSubjects: [String]
    let newsDetailLevels: [String]
    
    @State private var researchTopicsInternal: [String]
    @State private var researchDetailLevelsInternal: [String]
    
    // States for new structured tracked items
    @State private var structuredItems: [TrackedItem] = []
    
    // State to control dismissal of the entire preferences flow
    @State private var shouldDismissToNewsFeed = false
    @State private var selectedNewItemType: TrackedItem.TrackedItemType = .leagueSchedule
    @State private var newItemIdentifier: String = ""
    @State private var showAddItemFields: Bool = false

    // States for API Search
    @State private var searchQuery: String = ""
    @State private var searchResults: [SearchResultItem] = []
    @State private var isSearching: Bool = false
    @State private var searchErrorMessage: String? = nil
    @State private var selectedSearchResultTempName: String?

    @State private var isSaving: Bool = false
    @State private var localErrorMessage: String? = nil
    @State private var navigateToFrequencyView: Bool = false
    
    let maxTopics = 2
    let maxStructuredItems = 3
    let detailOptions = ["Light", "Medium", "Detailed"]
    let detailLabels = ["Light": "Quick overview", "Medium": "Key details", "Detailed": "In-depth"]

    // --- TEMPORARY: Hardcoded API Keys for Local Testing ONLY --- 
    // REMOVE BEFORE PRODUCTION
    private let TEMP_ALPHA_VANTAGE_KEY = "GLYKWNBXZHOR5UNJ"
    private let TEMP_FOOTBALL_DATA_KEY = "de2014f5e5f94a4b85a625282b53d135"
    // --- END OF TEMPORARY KEYS ---

    // Initialiseur explicite
    init(newsSubjects: [String], newsDetailLevels: [String]) {
        self.newsSubjects = newsSubjects
        self.newsDetailLevels = newsDetailLevels
        
        // Initialize states for free-form research topics
        self._researchTopicsInternal = State(initialValue: Array(repeating: "", count: 1))
        self._researchDetailLevelsInternal = State(initialValue: Array(repeating: "Medium", count: 1))
        
        // Initialize structuredItems (will be populated in .onAppear if profile exists)
        self._structuredItems = State(initialValue: [])
    }

    var body: some View {
        // No NavigationView needed if this is pushed onto NewsSubjectsView's stack
        Form {
            Section(header: Text("News Subjects")) { // Modified header
                if newsSubjects.isEmpty {
                    Text("No news subjects carried over.").foregroundColor(.gray)
                } else {
                    ForEach(newsSubjects.indices, id: \.self) { index in
                        HStack {
                            Text(newsSubjects[index])
                            Spacer()
                            Text("Detail: \(newsDetailLevels[index])")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            Section(header: Text("Research Topics").font(.headline),
                    footer: Text("Add up to \(maxTopics) specific questions or topics.")) { // Modified footer
                
                ForEach(researchTopicsInternal.indices, id: \.self) { index in
                    VStack(alignment: .leading) {
                        HStack {
                            TextField("Enter research topic \(index + 1)", text: $researchTopicsInternal[index])
                            if researchTopicsInternal.count > 1 {
                                Button {
                                    removeTopic(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        Picker("Detail Level", selection: $researchDetailLevelsInternal[index]) {
                            ForEach(detailOptions, id: \.self) { option in
                                Text(detailLabels[option] ?? option).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.top, 5)
                    }
                    .padding(.vertical, 5)
                }
                
                if researchTopicsInternal.count < maxTopics {
                    Button("➕ Add Topic") {
                        addTopic()
                    }
                }
            }
            
            // --- Section for Structured Tracked Items ---
            Section(header: Text("Trackers").font(.headline),
                    footer: Text("Track up to \(maxStructuredItems) items like scores or prices.")) { // Modified footer
                
                ForEach($structuredItems) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.type.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Text(item.identifier)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Button(action: {
                                print("DEBUG: Removing tracker: \(item.type.rawValue) - \(item.identifier)")
                                if let index = structuredItems.firstIndex(where: { $0.id == item.id }) {
                                    structuredItems.remove(at: index)
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        switch item.type {
                        case .leagueSchedule:
                            LeagueScheduleView(leagueId: item.identifier)
                        case .leagueStanding:
                            LeagueStandingView(leagueId: item.identifier)
                        case .assetPrice:
                            AssetPriceView(symbol: item.identifier)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: removeStructuredItem)

                if structuredItems.count < maxStructuredItems {
                    HStack(spacing: 12) {
                        // League Standings Button
                        TrackerButton(
                            title: "League Standings",
                            icon: "list.bullet",
                            isDisabled: structuredItems.count >= maxStructuredItems
                        ) {
                            print("DEBUG: League Standings button tapped")
                            selectedNewItemType = .leagueStanding
                            showAddItemFields = true
                                resetSearchAndSelectionFields(keepType: true) 
                            }
                        .id("leagueStanding")  // Force unique identity
                        
                        Spacer().frame(width: 4)  // Force spacing
                        
                        // League Matches Button
                        TrackerButton(
                            title: "League Matches",
                            icon: "sportscourt",
                            isDisabled: structuredItems.count >= maxStructuredItems
                        ) {
                            print("DEBUG: League Matches button tapped")
                            selectedNewItemType = .leagueSchedule
                            showAddItemFields = true
                            resetSearchAndSelectionFields(keepType: true)
                                }
                        .id("leagueSchedule")  // Force unique identity
                        
                        Spacer().frame(width: 4)  // Force spacing
                        
                        // Asset Price Button
                        TrackerButton(
                            title: "Asset Price",
                            icon: "chart.line.uptrend.xyaxis",
                            isDisabled: structuredItems.count >= maxStructuredItems
                        ) {
                            print("DEBUG: Asset Price button tapped")
                            selectedNewItemType = .assetPrice
                            showAddItemFields = true
                            resetSearchAndSelectionFields(keepType: true)
                        }
                        .id("assetPrice")  // Force unique identity
                    }
                                        .padding(.vertical, 8)
                }
            }
            // --- End of Structured Tracked Items Section ---
            
            if let localErrorMessage = localErrorMessage {
                Text(localErrorMessage).foregroundColor(.red).font(.caption)
            }
            if let authError = authService.errorMessage {
                Text(authError).foregroundColor(.red).font(.caption)
            }
            
            Section {
                Button(action: { navigateToFrequencyView = true }) {
                    HStack {
                        if isSaving {
                            ProgressView().padding(.trailing, 5)
                                .tint(Color.white)
                        }
                        Text("Next: Update Schedule")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
        .navigationTitle("Research Topics")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: shouldDismissToNewsFeed) { newValue in
            if newValue {
                // Notify parent views that they should dismiss too
                NotificationCenter.default.post(name: Notification.Name("DismissToNewsFeed"), object: nil)
                
                // Dismiss this view to go back to the previous screen
                self.presentationMode.wrappedValue.dismiss()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    // This will pop back to the previous view (settings)
                    print("DEBUG: ResearchTopicsView - Cancel button tapped")
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .sheet(isPresented: $showAddItemFields) {
            TrackerSearchView(
                trackerType: selectedNewItemType,
                isPresented: $showAddItemFields,
                searchQuery: $searchQuery,
                isSearching: $isSearching,
                searchResults: $searchResults,
                searchErrorMessage: $searchErrorMessage,
                selectedItemName: $selectedSearchResultTempName,
                selectedItemId: $newItemIdentifier,
                onSearch: performSearch,
                onSelect: selectSearchResult,
                onAdd: addStructuredItemFromSelection
            )
        }
        .onAppear {
            // Load existing research preferences if available
            if let profile = authService.userProfile {
                if !profile.original_research_topics.isEmpty {
                    self.researchTopicsInternal = profile.original_research_topics
                    self.researchDetailLevelsInternal = profile.research_detail_levels ?? Array(repeating: "Medium", count: profile.original_research_topics.count)
                } else if researchTopicsInternal.isEmpty { // Ensure at least one empty field if no profile data
                    researchTopicsInternal.append("")
                    researchDetailLevelsInternal.append("Medium")
                }
                // Load structured items
                self.structuredItems = profile.structuredTrackedItems
            } else if researchTopicsInternal.isEmpty { // For new users with no profile yet
                researchTopicsInternal.append("")
                researchDetailLevelsInternal.append("Medium")
            }
        }
        // Add NavigationLink for the new view
        .background(
            NavigationLink(destination: UpdateFrequencyView(
                                newsSubjects: newsSubjects.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                                newsDetailLevels: newsDetailLevels.enumerated().filter { newsSubjects[$0.offset].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.map { $0.element },
                                researchTopics: researchTopicsInternal.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                                researchDetailLevels: researchDetailLevelsInternal.enumerated().filter { researchTopicsInternal[$0.offset].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.map { $0.element },
                                structuredTrackers: structuredItems.map { item -> [String: String] in
                                    [
                                        "type": item.type.rawValue,
                                        "identifier": item.identifier,
                                        "competitionName": item.competitionName ?? ""
                                    ]
                                },
                                onPreferencesSaved: {
                                    // Set flag to dismiss the entire preferences flow
                                    self.shouldDismissToNewsFeed = true
                                    
                                    // Dismiss the current view (UpdateFrequencyView)
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                           ),
                           isActive: $navigateToFrequencyView) {
                EmptyView()
            }
        )
    }
    
    func addTopic() {
        if researchTopicsInternal.count < maxTopics {
            researchTopicsInternal.append("")
            researchDetailLevelsInternal.append("Medium")
        }
    }
    
    func removeTopic(at index: Int) {
        if researchTopicsInternal.count > 1 {
            researchTopicsInternal.remove(at: index)
            researchDetailLevelsInternal.remove(at: index)
        } else if researchTopicsInternal.count == 1 { // If only one, clear it instead of removing row
            researchTopicsInternal[0] = ""
            researchDetailLevelsInternal[0] = "Medium"
        }
    }
    
    // --- Functions for Structured Tracked Items ---
    func addStructuredItem() {
        let identifier = newItemIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !identifier.isEmpty else {
            localErrorMessage = "Identifier cannot be empty for a tracker."
            return
        }
        guard structuredItems.count < maxStructuredItems else {
            localErrorMessage = "Maximum number of specific trackers reached."
            return
        }
        // Optional: Add validation for identifier format if needed

        let newItem = TrackedItem(type: selectedNewItemType, identifier: identifier)
        structuredItems.append(newItem)
        resetNewItemFields()
        showAddItemFields = false // Hide fields after adding
        localErrorMessage = nil
    }

    func removeStructuredItem(at offsets: IndexSet) {
        structuredItems.remove(atOffsets: offsets)
    }
    
    func resetNewItemFields() {
        selectedNewItemType = .leagueSchedule // Default to league schedule
        newItemIdentifier = ""
        localErrorMessage = nil
    }
    // --- End of Functions for Structured Tracked Items ---

    // --- Functions for API Search ---
    func resetSearchAndSelectionFields(keepType: Bool = false, keepQuery: Bool = false) {
        print("DEBUG: Resetting search fields - Keep type: \(keepType), Keep query: \(keepQuery)")
        if !keepType { selectedNewItemType = .leagueSchedule }
        if !keepQuery { 
            searchQuery = ""
            newItemIdentifier = ""
            selectedSearchResultTempName = nil
        }
        searchResults = []
        searchErrorMessage = nil
        isSearching = false
        print("DEBUG: After reset - newItemIdentifier: \(newItemIdentifier)")
    }

    func performSearch() {
        print("DEBUG: Performing search for type: \(selectedNewItemType.rawValue), query: \(searchQuery)")
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchErrorMessage = "Please enter a search term."
            searchResults = []
            return
        }
        
        // Try to get keys from AuthService, fall back to temporary hardcoded keys for testing
        let footballApiKeyFromService = authService.apiKeys?["FOOTBALL_DATA_API_KEY"]
        let alphaVantageApiKeyFromService = authService.apiKeys?["ALPHA_VANTAGE_API_KEY"]

        // Use service key if available, otherwise use temporary hardcoded key
        let finalFootballKey = footballApiKeyFromService ?? TEMP_FOOTBALL_DATA_KEY
        let finalAlphaVantageKey = alphaVantageApiKeyFromService ?? TEMP_ALPHA_VANTAGE_KEY

        // Check if keys are still nil/empty (e.g. if hardcoded ones were also empty or removed)
        // This check is primarily for the final keys after fallback.
        var missingKeysMessage = ""
        if selectedNewItemType == .leagueSchedule || selectedNewItemType == .leagueStanding {
            if finalFootballKey.isEmpty {
                 missingKeysMessage += "Football API Key is missing. "
            }
        }
        if selectedNewItemType == .assetPrice {
            if finalAlphaVantageKey.isEmpty {
                missingKeysMessage += "Financial API Key is missing. "
            }
        }

        if !missingKeysMessage.isEmpty {
            searchErrorMessage = missingKeysMessage + "(Using temp keys if service fetch failed)."
            return
        }

        searchErrorMessage = nil
        isSearching = true
        // Don't reset selection when performing a new search
        // selectedSearchResultTempName = nil
        // newItemIdentifier = ""

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch selectedNewItemType {
        case .leagueSchedule, .leagueStanding:
            guard !finalFootballKey.isEmpty else {
                finishSearch(error: "Football API key missing (after fallback).")
                return
            }
            searchFootballLeagues(query: query, apiKey: finalFootballKey)
        case .assetPrice:
            guard !finalAlphaVantageKey.isEmpty else {
                finishSearch(error: "Financial API key missing (after fallback).")
                return
            }
            searchAssets(query: query, apiKey: finalAlphaVantageKey)
        }
    }
    
    func finishSearch(items: [SearchResultItem]? = nil, error: String? = nil) {
        DispatchQueue.main.async {
            self.isSearching = false
            if let error = error {
                self.searchErrorMessage = error
                self.searchResults = []
            } else if let items = items {
                self.searchResults = items
                if items.isEmpty {
                    self.searchErrorMessage = "No results found for your query."
                }
            }
        }
    }

    func selectSearchResult(_ result: SearchResultItem) {
        print("DEBUG: Selected search result - ID: \(result.id), Name: \(result.name)")
        newItemIdentifier = result.id
        selectedSearchResultTempName = result.name
        searchQuery = result.name
        searchResults = []
        searchErrorMessage = nil
        print("DEBUG: After selection - newItemIdentifier: \(newItemIdentifier)")
    }

    func addStructuredItemFromSelection() {
        print("DEBUG: Adding structured item from selection - Type: \(selectedNewItemType.rawValue), ID: \(newItemIdentifier)")
        guard !newItemIdentifier.isEmpty else {
            print("DEBUG: Failed to add - Empty identifier")
            localErrorMessage = "No item selected from search to add."
            return
        }
        guard structuredItems.count < maxStructuredItems else {
            print("DEBUG: Failed to add - Max items reached (\(maxStructuredItems))")
            localErrorMessage = "Maximum number of specific trackers reached."
            return
        }

        let newItem = TrackedItem(type: selectedNewItemType, identifier: newItemIdentifier, competitionName: selectedSearchResultTempName)
        structuredItems.append(newItem)
        print("DEBUG: Added new structured item - Total items now: \(structuredItems.count)")
        print("DEBUG: Current structured items: \(structuredItems)")
        
        // Fetch and cache initial data for the new item
        switch newItem.type {
        case .leagueSchedule:
            TrackerAPIService.shared.fetchLeagueSchedule(leagueId: newItem.identifier) { result in
                if case .success(let data) = result {
                    print("DEBUG: Successfully fetched and cached initial league schedule data")
                }
            }
        case .leagueStanding:
            TrackerAPIService.shared.fetchLeagueStandings(competitionId: newItem.identifier) { result in
                if case .success(let data) = result {
                    print("DEBUG: Successfully fetched and cached initial league standings data")
                }
            }
        case .assetPrice:
            TrackerAPIService.shared.fetchAssetPrice(symbol: newItem.identifier) { result in
                if case .success(let data) = result {
                    print("DEBUG: Successfully fetched and cached initial asset price data")
                }
            }
        }
        
        resetSearchAndSelectionFields()
        showAddItemFields = false
        localErrorMessage = nil
    }

    func searchFootballLeagues(query: String, apiKey: String) {
        let urlString = "https://api.football-data.org/v4/competitions"
        guard let components = URLComponents(string: urlString) else {
            finishSearch(error: "Invalid competitions URL")
            return
        }
        // football-data.org /competitions doesn't have a direct name search query param.
        // We fetch all (or those available by plan) and filter client-side.
        // Add plan filter if you have a specific tier, e.g., components.queryItems = [URLQueryItem(name: "plan", value: "TIER_ONE")]
        
        guard let url = components.url else {
            finishSearch(error: "Failed to construct competitions URL")
            return
        }

        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-Auth-Token")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                finishSearch(error: "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                finishSearch(error: "Football API error: Status \(statusCode)")
                return
            }
            guard let data = data else {
                finishSearch(error: "No data from Football API")
                return
            }

            do {
                let decodedResponse = try JSONDecoder().decode(FootballDataCompetitionResponse.self, from: data)
                let allCompetitions = decodedResponse.competitions ?? []
                
                // Client-side filtering by name (case-insensitive)
                let filtered = allCompetitions.filter {
                    ($0.name?.localizedCaseInsensitiveContains(query) ?? false) || 
                    ($0.code?.localizedCaseInsensitiveContains(query) ?? false)
                }
                
                let results = filtered.map { SearchResultItem(id: String($0.id), name: $0.name ?? "Unknown League") }
                finishSearch(items: results)
            } catch {
                finishSearch(error: "Failed to parse football competitions: \(error.localizedDescription)")
            }
        }.resume()
    }

    func searchAssets(query: String, apiKey: String) {
        var mutableComponents = URLComponents(string: "https://www.alphavantage.co/query")
        mutableComponents?.queryItems = [
            URLQueryItem(name: "function", value: "SYMBOL_SEARCH"),
            URLQueryItem(name: "keywords", value: query),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        guard let url = mutableComponents?.url else {
            finishSearch(error: "Invalid Alpha Vantage URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                finishSearch(error: "Network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                var detailError = "Status \(statusCode)"
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let note = json["Note"] as? String {
                    detailError += ". Info: \(note)" 
                } else if let data = data, let errStr = String(data: data, encoding: .utf8) {
                    detailError += ". Body: \(errStr.prefix(100))"
                }
                finishSearch(error: "Alpha Vantage API error: \(detailError)")
                return
            }
            guard let data = data else {
                finishSearch(error: "No data from Alpha Vantage")
                return
            }

            do {
                let decodedResponse = try JSONDecoder().decode(AlphaVantageSearchResponse.self, from: data)
                if let matches = decodedResponse.bestMatches {
                    let filteredResults = matches.compactMap { match -> SearchResultItem? in
                        guard let symbol = match.symbol, 
                              let name = match.name,
                              let type = match.type, 
                              let region = match.region, 
                              let matchScoreStr = match.matchScore,
                              let score = Double(matchScoreStr) else { return nil }
                        
                        // Prioritize equities from primary stock exchanges (e.g., US)
                        // Vous pouvez ajuster ces filtres selon vos besoins.
                        // Par exemple, ne garder que les "Equity" et celles d'une certaine région.
                        // Et filtrer par score de pertinence.
                        if type == "Equity" && score > 0.3 { // Seuil de score, à ajuster
                            // Pour Oracle (ORCL), on veut éviter "Oracle Financial Services Software Ltd."
                            // Une heuristique simple : si la query est courte et en majuscules (comme un symbole), 
                            // on peut être plus strict sur la correspondance du symbole.
                            if query.uppercased() == query && query.count <= 5 && symbol.uppercased() != query.uppercased() && !name.lowercased().contains(query.lowercased()) {
                                // Si la recherche ressemble à un symbole mais ne correspond pas au symbole retourné, et que le nom ne contient pas la query,
                                // on peut le considérer moins pertinent dans ce cas précis.
                                // Cela peut aider à filtrer "ORC" d'Oracle Corp si on cherchait "ORCL"
                                // Mais c'est une logique délicate à généraliser.
                                // Pour l'instant, on se concentre sur type et score.
                                 return SearchResultItem(id: symbol, name: "\(name) (\(symbol))") // Inclure le symbole dans le nom pour clarté
                            }
                             return SearchResultItem(id: symbol, name: "\(name) (\(symbol))")
                        }
                        return nil
                    }
                    .sorted { (item1, item2) -> Bool in
                        // Optionnel : trier par une combinaison de score et pertinence du nom si AlphaVantage ne le fait pas déjà bien
                        // Pour l'instant, l'ordre d'AlphaVantage est souvent bon.
                        return true // Pas de tri supplémentaire pour l'instant, on se fie à l'ordre d'AlphaVantage
                    }
                    
                    finishSearch(items: filteredResults)
                } else {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let note = json["Note"] as? String {
                         finishSearch(error: "Alpha Vantage: \(note)")
                    } else {
                         finishSearch(items: [])
                    }
                }
            } catch {
                finishSearch(error: "Failed to parse Alpha Vantage response: \(error.localizedDescription)")
            }
        }.resume()
    }
}

// Bouton personnalisé pour les trackers
struct TrackerButton: View {
    let title: String
    let icon: String
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDisabled ? Color.gray.opacity(0.3) : Color.blue.opacity(0.1))
            )
            .foregroundColor(isDisabled ? .gray : .blue)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDisabled ? Color.gray.opacity(0.3) : Color.blue.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(ScaledButtonStyle())
        .disabled(isDisabled)
    }
}

// Style de bouton personnalisé pour améliorer le retour visuel
struct ScaledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Vue modale pour la recherche de trackers
struct TrackerSearchView: View {
    let trackerType: TrackedItem.TrackedItemType
    @Binding var isPresented: Bool
    @Binding var searchQuery: String
    @Binding var isSearching: Bool
    @Binding var searchResults: [SearchResultItem]
    @Binding var searchErrorMessage: String?
    @Binding var selectedItemName: String?
    @Binding var selectedItemId: String
    
    let onSearch: () -> Void
    let onSelect: (SearchResultItem) -> Void
    let onAdd: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Champ de recherche
                HStack {
                    TextField("Search for \(trackerType.rawValue.lowercased())...", text: $searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocorrectionDisabled()
                        .onSubmit {
                            onSearch()
                        }
                    
                    if isSearching {
                        ProgressView()
                            .padding(.leading, 5)
                    } else {
                        Button(action: onSearch) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.blue)
                        }
                        .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal)
                
                // Résultats de la recherche
                if let selectedName = selectedItemName, !selectedItemId.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Selected: \(selectedName)")
                                .font(.headline)
                            Spacer()
                            Button("Clear") {
                                selectedItemName = nil
                                selectedItemId = ""
                            }
                            .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                        
                        Button(action: {
                            onAdd()
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add to Trackers")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                } else if !searchResults.isEmpty {
                    List {
                        ForEach(searchResults) { result in
                            Button(action: {
                                onSelect(result)
                            }) {
                                HStack {
                                    Text(result.name)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(PlainListStyle())
                } else if let errorMsg = searchErrorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .padding()
                        Text(errorMsg)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding()
                        Text("Search for \(trackerType.rawValue)")
                            .foregroundColor(.gray)
                        Text("Enter keywords to begin search.") // Modified text
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                }
                
                Spacer()
            }
            .navigationTitle("Add \(trackerType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct ResearchTopicsView_Previews: PreviewProvider {
    static var previews: some View {
        ResearchTopicsView(newsSubjects: ["AI", "SpaceX"], newsDetailLevels: ["Medium", "Detailed"])
            .environmentObject(AuthService.shared)
    }
} 