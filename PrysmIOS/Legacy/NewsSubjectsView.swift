import SwiftUI

// Structure pour décoder la réponse de la fonction Cloud
struct TrendingSubtopicsResponse: Codable {
    let subtopics: [String]?
    let error: String?
}

// Struct pour chaque élément affichable dans la grille
struct DisplayableGridItem: Identifiable, Hashable {
    let id: UUID
    let name: String       // e.g., "Technology" or "AI Chatbots"
    let level: Int         // Depth: 0 for predefined, 1 for their subtopics, etc.
    let parentId: UUID?    // ID of the parent item, nil for top-level items.
    let path: String       // Full hierarchical path e.g. "Sports > Football > Premier League"
    
    // Default initializer with auto-generated UUID
    init(name: String, level: Int, parentId: UUID?, path: String) {
        self.id = UUID()
        self.name = name
        self.level = level
        self.parentId = parentId
        self.path = path
    }
    
    // Custom initializer to reuse an existing ID
    init(id: UUID, name: String, level: Int, parentId: UUID?, path: String) {
        self.id = id
        self.name = name
        self.level = level
        self.parentId = parentId
        self.path = path
    }

    // Conformance for Hashable
    static func == (lhs: DisplayableGridItem, rhs: DisplayableGridItem) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct NewsSubjectsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var userSelectedSubjects: [String] = []
    @State private var userSelectedDetailLevels: [String] = []
    @State private var manualSubjectInput: String = ""
    @State private var navigateToResearchTopics = false
    @State private var shouldDismissToNewsFeed = false

    // Nouveaux états pour la grille unifiée
    @State private var gridDisplayItems: [DisplayableGridItem] = []
    @State private var expandedItemIDs: Set<UUID> = [] // Replaces expandedCategories
    @State private var subtopicsCache: [String: [String]] = [:] // Cache pour les sous-thèmes (key = hierarchical path)
    
    @State private var isLoadingSubtopicsForItem: UUID? = nil // Replaces isLoadingSubtopicsForCategory (ID of item being loaded)
    @State private var subtopicErrorForItem: [UUID: String] = [:] // Replaces subtopicErrorForCategory (Error for itemID)
    @State private var generalUserMessage: String? = nil // For general messages/errors

    // Add a dictionary to track item IDs by name
    @State private var itemIDsByName: [String: UUID] = [:]

    let maxTotalSubjects = 5
    // --- Dynamic Topics by Country ---
    var predefinedMainCategories: [String] {
        let country = authService.userProfile?.country.lowercased() ?? ""
        if country.contains("france") || country == "fr" {
            return [
                "Économie", "Sciences et technologies", "Divertissement", "Films", "Musique", "Télévision", "Livres", "Arts et design", "People", "Sports", "Santé", "Actualités nationales", "Politique", "Environnement", "Voyages"
            ].sorted()
        } else {
            return [
                "Business", "Economy", "Markets", "Jobs", "Personal finance", "Entrepreneurship", "Technology", "Mobile", "Gadgets", "Internet", "Virtual reality", "Artificial intelligence", "Computing", "Entertainment", "Movies", "Music", "TV", "Books", "Arts & design", "Celebrities", "Sports", "NFL", "NBA", "MLB", "NHL", "NCAA Football", "NCAA Basketball", "Soccer", "NASCAR", "Golf", "Tennis", "WNBA", "Science", "Environment", "Space", "Physics", "Genetics"
            ].sorted()
        }
    }

    var level1Topics: [String: [String]] {
        let country = authService.userProfile?.country.lowercased() ?? ""
        if country.contains("france") || country == "fr" {
            return [
                "Économie": [],
                "Sciences et technologies": [],
                "Divertissement": ["Films", "Musique", "Télévision", "Livres"],
                "Arts et design": [],
                "People": [],
                "Sports": [],
                "Santé": [],
                "Actualités nationales": [],
                "Politique": [],
                "Environnement": [],
                "Voyages": []
            ]
        } else {
            return [
                "Business": ["Economy", "Markets", "Jobs", "Personal finance", "Entrepreneurship"],
                "Technology": ["Mobile", "Gadgets", "Internet", "Virtual reality", "Artificial intelligence", "Computing"],
                "Entertainment": ["Movies", "Music", "TV", "Books", "Arts & design", "Celebrities"],
                "Sports": ["NFL", "NBA", "MLB", "NHL", "NCAA Football", "NCAA Basketball", "Soccer", "NASCAR", "Golf", "Tennis", "WNBA"],
                "Science": ["Environment", "Space", "Physics", "Genetics"]
            ]
        }
    }

    var level2Topics: [String: [String]] {
        let country = authService.userProfile?.country.lowercased() ?? ""
        if country.contains("france") || country == "fr" {
            return [
                "Films": ["Cinéma français", "Cinéma international"],
                "Musique": ["Pop", "Rock", "Rap", "Classique"],
                "Télévision": ["Séries", "Actualités TV"],
                "Livres": ["Romans", "Essais", "Bandes dessinées"]
            ]
        } else {
            return [
                "Business": ["Economy", "Markets", "Jobs", "Personal finance", "Entrepreneurship"],
                "Technology": ["Mobile", "Gadgets", "Internet", "Virtual reality", "AI", "Computing"],
                "Entertainment": ["Movies", "Music", "TV", "Books", "Arts & design", "Celebrities"],
                "Sports": ["NFL", "NBA", "MLB", "NHL", "NCAA Football", "Soccer", "Golf", "Tennis"],
                "Science": ["Environment", "Space", "Physics", "Genetics"]
            ]
        }
    }

    // --- buildGridItems utilise maintenant les bons topics dynamiques ---

    // Adaptive grid layout: as many columns as fit with min width 130
    let gridLayout: [GridItem] = [GridItem(.adaptive(minimum: 130), spacing: 12)]

    // Common abbreviations for display
    let ABBREVIATIONS: [String:String] = [
        "Artificial Intelligence": "AI",
        "Information Technology": "IT",
        "Virtual Reality": "VR",
        "Augmented Reality": "AR",
        "International Relations": "IR",
        "Research & Innovation": "R&D",
        "United States": "US",
        "European Union": "EU"
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SelectedTopicsHeaderView(selectedSubjects: $userSelectedSubjects,
                                         selectedDetailLevels: $userSelectedDetailLevels,
                                         maxSubjects: maxTotalSubjects)
                Form {
                    Section(header: Text("Explore & Select Interests").font(.system(size: 16, weight: .semibold))) {
                        FlexibleView(data: gridDisplayItems, spacing: 10, alignment: .leading) { item in
                            VStack(alignment: .leading, spacing: 0) {
                                let disp = ABBREVIATIONS[item.name] ?? item.name
                                TopicBubble(
                                    itemName: disp,
                                    level: item.level,
                                    isSelected: userSelectedSubjects.contains(item.name),
                                    isExpanded: expandedItemIDs.contains(item.id),
                                    isLoading: isLoadingSubtopicsForItem == item.id,
                                    hasError: subtopicErrorForItem[item.id] != nil,
                                    action: { handleItemTap(item: item) }
                                )
                                if let errorText = subtopicErrorForItem[item.id] {
                                    Text("Error: \(errorText)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 8)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        
                        if let message = generalUserMessage {
                            Text(message)
                                .foregroundColor(.black)
                                .font(.caption)
                                .padding(.top, 5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    Section(header: Text("Custom Topic").font(.system(size: 16, weight: .semibold))) {
                        HStack {
                            TextField("Enter custom topic...", text: $manualSubjectInput)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(8)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                            Button("Add") {
                                addManualSubject()
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .disabled(manualSubjectInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || userSelectedSubjects.count >= maxTotalSubjects)
                        }
                        .padding(.vertical, 5)
                    }
                    
                    Section {
                        NavigationLink(
                            destination: ResearchTopicsView(
                                newsSubjects: userSelectedSubjects.filter { !$0.isEmpty },
                                newsDetailLevels: userSelectedDetailLevels.enumerated().compactMap {
                                    index, level -> String? in
                                    if index < userSelectedSubjects.count && !userSelectedSubjects[index].isEmpty {
                                        return level
                                    } else {
                                        return nil
                                    }
                                }
                            )
                            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DismissToNewsFeed"))) { _ in
                                // Set the flag to dismiss this view
                                self.shouldDismissToNewsFeed = true
                            },
                            isActive: $navigateToResearchTopics
                        ) {
                            Text("Next: Research & Details (\(userSelectedSubjects.filter { !$0.isEmpty }.count)/\(maxTotalSubjects) topics)")
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(userSelectedSubjects.filter { !$0.isEmpty }.isEmpty ? Color.gray : Color.black)
                                .cornerRadius(6)
                        }
                        .disabled(userSelectedSubjects.filter { !$0.isEmpty }.isEmpty)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("News Interests")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: shouldDismissToNewsFeed) { newValue in
                if newValue {
                    // Dismiss this view to go back to the news feed
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // This will pop back to the previous view (settings)
                        print("DEBUG: NewsSubjectsView - Cancel button tapped")
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear(perform: setupInitialView)
        }
        .accentColor(Color.black)
    }

    func setupInitialView() {
        loadInitialPreferences()
        buildGridItems() // Construire la grille initiale
        authService.errorMessage = nil
    }

    func loadInitialPreferences() {
        if let profile = authService.userProfile, !profile.original_news_subjects.isEmpty {
            self.userSelectedSubjects = profile.original_news_subjects
            self.userSelectedDetailLevels = profile.news_detail_levels
            // TODO: Potentially load and restore expandedItemIDs and subtopicsCache if saved
        } else {
             self.userSelectedSubjects = []
             self.userSelectedDetailLevels = []
             self.expandedItemIDs = []
             self.subtopicsCache = [:]
        }
    }

    func buildGridItems() {
        print("🔄 Starting buildGridItems()")
        
        var rootNames = Array(level1Topics.keys).sorted()
        var newRootItems: [DisplayableGridItem] = rootNames.map { categoryName in
            // Check if we already have an ID for this category name
            if let existingID = itemIDsByName[categoryName] {
                print("♻️ Reusing existing ID for \(categoryName): \(existingID)")
                return DisplayableGridItem(id: existingID, name: categoryName, level: 0, parentId: nil, path: categoryName)
            } else {
                // Create new item with new ID
                let newItem = DisplayableGridItem(name: categoryName, level: 0, parentId: nil, path: categoryName)
                itemIDsByName[categoryName] = newItem.id
                print("🆕 Created new ID for \(categoryName): \(newItem.id)")
                return newItem
            }
        }
        
        var finalDisplayItems: [DisplayableGridItem] = []
        
        func addItemsRecursively(items: [DisplayableGridItem]) {
            for item in items {
                finalDisplayItems.append(item) // Add current item
                
                // Check if this item is expanded and has subtopics in the cache
                if expandedItemIDs.contains(item.id), let childrenNames = subtopicsCache[item.path] {
                    print("🔍 Found \(childrenNames.count) children for expanded item: \(item.name), ID: \(item.id)")
                    
                    // Create child items, preserving existing IDs when possible
                    let childDisplayItems = childrenNames.map { childName -> DisplayableGridItem in
                        // Construct a key that identifies this child uniquely based on its parent
                        let childKey = "\(item.path):\(childName)"
                        
                        if let existingID = itemIDsByName[childKey] {
                            print("♻️ Reusing existing ID for subtopic \(childName): \(existingID)")
                            return DisplayableGridItem(id: existingID, name: childName, level: item.level + 1, parentId: item.id, path: "\(item.path) > \(childName)")
                        } else {
                            // Create new item with new ID
                            let newItem = DisplayableGridItem(name: childName, level: item.level + 1, parentId: item.id, path: "\(item.path) > \(childName)")
                            itemIDsByName[childKey] = newItem.id
                            print("🆕 Created new ID for subtopic \(childName): \(newItem.id)")
                            return newItem
                        }
                    }
                    
                    if !childDisplayItems.isEmpty { // Only recurse if there are children to add
                        print("➕ Adding \(childDisplayItems.count) child items for parent: \(item.name)")
                        addItemsRecursively(items: childDisplayItems)
                    }
                } else if expandedItemIDs.contains(item.id) {
                    print("🔍 Item \(item.name) (ID: \(item.id)) is expanded but has no children in cache")
                    print("📊 expandedItemIDs: \(expandedItemIDs)")
                    print("📊 subtopicsCache keys: \(Array(subtopicsCache.keys))")
                }
            }
        }
        
        addItemsRecursively(items: newRootItems)
        print("📊 Final display items count: \(finalDisplayItems.count)")
        self.gridDisplayItems = finalDisplayItems
    }

    func handleItemTap(item: DisplayableGridItem) {
        print("👆 Item tapped: \(item.name), level: \(item.level)")
        generalUserMessage = nil
        subtopicErrorForItem[item.id] = nil

        // First, toggle the expansion state
        if expandedItemIDs.contains(item.id) {
            print("🔼 Collapsing item: \(item.name)")
            expandedItemIDs.remove(item.id)
            isLoadingSubtopicsForItem = nil // Stop loading if it was for this item
        } else {
            print("🔽 Expanding item: \(item.name)")
            expandedItemIDs.insert(item.id)
            // Check cache first. If subtopics for item.name are not cached, then fetch.
            if subtopicsCache[item.path] == nil {
                // Check hard-coded dictionaries first
                if item.level == 0, let hard = level1Topics[item.name] {
                    subtopicsCache[item.path] = hard
                    print("📚 Using hard-coded level-1 subtopics for \(item.name)")
                } else if item.level == 1, let hard2 = level2Topics[item.name] {
                    subtopicsCache[item.path] = hard2
                    print("📚 Using hard-coded level-2 subtopics for \(item.name)")
                } else {
                    print("🔄 No cache/hardcoded list for \(item.name), calling backend")
                    fetchTrendingSubtopics(forTopic: item.name, path: item.path, forItemID: item.id)
                }
            } else {
                print("📦 Using cached subtopics for \(item.name): \(subtopicsCache[item.path]!)")
            }
        }
        
        // Also select the topic when tapped
        toggleSubjectSelection(item.name)
        
        print("🏗️ Rebuilding grid after item tap")
        buildGridItems() // Rebuild the grid to show/hide children or reflect loading state change
    }
    
    func toggleSubjectSelection(_ subjectName: String) {
        generalUserMessage = nil
        
        if let index = userSelectedSubjects.firstIndex(of: subjectName) {
            userSelectedSubjects.remove(at: index)
            if index < userSelectedDetailLevels.count { // Ensure index is valid
                userSelectedDetailLevels.remove(at: index)
            }
        } else {
            if userSelectedSubjects.count < maxTotalSubjects {
                userSelectedSubjects.append(subjectName)
                userSelectedDetailLevels.append("Medium") // Default detail level
            } else {
                generalUserMessage = "Maximum \(maxTotalSubjects) interests reached. Please remove one to add '\(subjectName)'."
            }
        }
        // No need to call buildGridItems() here, selection is a state reflected by TopicBubble via isSelected prop.
        // However, if selection *should* affect expansion or structure, then call it.
        // For now, assume selection and expansion are orthogonal.
    }

    func addManualSubject() {
        generalUserMessage = nil
        let topic = manualSubjectInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty else {
            generalUserMessage = "Custom topic cannot be empty."
            return
        }
        guard !userSelectedSubjects.contains(topic) else {
            generalUserMessage = "'\(topic)' is already in your interests."
            return
        }
        
        if userSelectedSubjects.count < maxTotalSubjects {
            userSelectedSubjects.append(topic)
            userSelectedDetailLevels.append("Medium")
            manualSubjectInput = ""
            // If adding a manual subject could match a predefined category and should auto-expand,
            // then call buildGridItems(). For now, it's just added to selected list.
        } else {
            generalUserMessage = "Maximum \(maxTotalSubjects) interests reached. Cannot add '\(topic)'."
        }
    }

    func fetchTrendingSubtopics(forTopic topicName: String, path itemPath: String, forItemID itemID: UUID) {
        isLoadingSubtopicsForItem = itemID
        subtopicErrorForItem[itemID] = nil
        generalUserMessage = nil
        
        print("⬇️ STARTING API CALL - Fetching trending subtopics for item ID: \(itemID), path: \(itemPath)")
        let encodedPath = itemPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://us-central1-prysmios.cloudfunctions.net/get_trending_subtopics?topic=\(encodedPath)"
        print("📡 URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ ERROR: Invalid URL")
            subtopicErrorForItem[itemID] = "Invalid URL"
            isLoadingSubtopicsForItem = nil
            buildGridItems() // Rebuild to show error or remove loading
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Add Authorization header if your Cloud Function requires it
        // authService.getIDToken { token, error in
        //     if let token = token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        //     ... proceed with dataTask ...
        // }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingSubtopicsForItem = nil // Stop loading for this item specifically
                
                if let error = error {
                    print("❌ NETWORK ERROR: \(error.localizedDescription)")
                    subtopicErrorForItem[itemID] = "Network: \(error.localizedDescription)"
                    buildGridItems()
                    return
                }
                
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("📊 Response status code: \(statusCode)")
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let sc = (response as? HTTPURLResponse)?.statusCode ?? 0
                    var responseBody = "Unknown server error"
                    if let data = data, let rbString = String(data: data, encoding: .utf8), !rbString.isEmpty {
                        responseBody = rbString
                        print("📄 Error response body: \(responseBody)")
                    }
                    print("❌ SERVER ERROR: HTTP \(sc)")
                    subtopicErrorForItem[itemID] = "Server error (\(sc)): \(responseBody)"
                    buildGridItems()
                    return
                }
                
                guard let data = data else {
                    print("❌ ERROR: No data received")
                    subtopicErrorForItem[itemID] = "No data received."
                    buildGridItems()
                    return
                }
                
                // Print raw response for debugging
                if let rawString = String(data: data, encoding: .utf8) {
                    print("📦 Raw response data: \(rawString)")
                }
                
                do {
                    let decodedResponse = try JSONDecoder().decode(TrendingSubtopicsResponse.self, from: data)
                    
                    if let fetchedSubtopics = decodedResponse.subtopics {
                        print("✅ Successfully decoded subtopics: \(fetchedSubtopics)")
                        print("📊 Number of subtopics: \(fetchedSubtopics.count)")
                        subtopicsCache[itemPath] = fetchedSubtopics
                        subtopicErrorForItem[itemID] = nil // Clear error on success
                    } else if let apiError = decodedResponse.error {
                        print("❌ API ERROR: \(apiError)")
                        subtopicErrorForItem[itemID] = "API Error: \(apiError)"
                        subtopicsCache[itemPath] = [] // Cache empty to prevent refetch on non-retryable API error
                    } else {
                        // No subtopics and no error means an empty list, cache it
                        print("ℹ️ No subtopics found and no error")
                        subtopicsCache[itemPath] = []
                        subtopicErrorForItem[itemID] = nil
                    }
                    
                    print("🏗️ Rebuilding grid with updated data")
                    print("📊 Current subtopicsCache: \(self.subtopicsCache)")
                    print("📊 Current expandedItemIDs: \(self.expandedItemIDs)")
                    buildGridItems() // Rebuild grid with new subtopics or error state
                    print("🔄 Grid rebuilt - Item count: \(self.gridDisplayItems.count)")
                } catch {
                    print("❌ DECODE ERROR: \(error.localizedDescription)")
                    subtopicErrorForItem[itemID] = "Decode fail: \(error.localizedDescription)"
                    subtopicsCache[itemPath] = [] // Cache empty on decode failure
                    buildGridItems()
                }
            }
        }.resume()
    }
}

// --- Helper Views for Bubbles & Layout ---

// Unified TopicBubble (replaces CategoryBubble and SubtopicBubble)
struct TopicBubble: View {
    let itemName: String
    let level: Int
    let isSelected: Bool
    let isExpanded: Bool
    let isLoading: Bool
    let hasError: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(itemName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if isExpanded {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                } else {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.black : Color(UIColor.systemGray6))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .foregroundColor(isSelected ? .white : .black)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.black : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SelectedTopicsHeaderView: View {
    @Binding var selectedSubjects: [String]
    @Binding var selectedDetailLevels: [String] // Ajout pour la suppression synchronisée
    let maxSubjects: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Interests (\(selectedSubjects.count)/\(maxSubjects))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.black)
                .padding([.top, .leading])
            
            if selectedSubjects.isEmpty {
                Text("Tap categories or subtopics below, or add a custom topic.")
                    .font(.caption)
                    .foregroundColor(.black)
                    .padding([.leading, .bottom])
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedSubjects.indices, id: \.self) { index in
                            HStack(spacing: 4) {
                                Text(selectedSubjects[index])
                                    .font(.caption)
                                    .lineLimit(1)
                                Button(action: {
                                    // Supprimer le sujet et son niveau de détail
                                    selectedSubjects.remove(at: index)
                                    if index < selectedDetailLevels.count { // S'assurer que l'index est valide
                                        selectedDetailLevels.remove(at: index)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color(UIColor.systemGray3))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(16)
                        }
                    }
                    .padding([.leading, .trailing, .bottom])
                }
            }
            Divider()
        }
        .frame(maxWidth: .infinity) // Pour que le header prenne toute la largeur
    }
}

// Extension pour foncer une couleur (optionnel, pour le style des bulles)
extension Color {
    func darker(by percentage: CGFloat = 30.0) -> Color {
        return self.adjust(by: -abs(percentage) / 100)
    }
    
    func adjust(by percentage: CGFloat = 30.0) -> Color {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return Color(UIColor(red: min(red + percentage/100, 1.0),
                               green: min(green + percentage/100, 1.0),
                               blue: min(blue + percentage/100, 1.0),
                               alpha: alpha))
        }
        return self
    }
}

// FlexibleView et helpers de taille (comme avant, vérifiez qu'ils sont bien présents)
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: Alignment(horizontal: alignment, vertical: .center)) {
            Color.clear
                .frame(height: 1)
                .readSize { size in
                    availableWidth = size.width
                }

            _FlexibleView(data: data, spacing: spacing, alignment: alignment, availableWidth: availableWidth, content: content)
        }
    }
}

struct _FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let availableWidth: CGFloat
    let content: (Data.Element) -> Content
    @State var elementsSize: [Data.Element: CGSize] = [:]

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            ForEach(computeRows(), id: \.self) { rowElements in
                HStack(spacing: spacing) {
                    ForEach(rowElements, id: \.self) { element in
                        content(element)
                            .fixedSize()
                            .readSize { size in
                                elementsSize[element] = size
                            }
                    }
                }
            }
        }
    }

    func computeRows() -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentRow = 0
        var remainingWidth = availableWidth

        for element in data {
            let elementSize = elementsSize[element, default: CGSize(width: availableWidth, height: 1)]

            if remainingWidth - (elementSize.width + spacing) >= 0 {
                rows[currentRow].append(element)
            } else {
                currentRow += 1
                rows.append([element])
                remainingWidth = availableWidth
            }
            remainingWidth -= (elementSize.width + spacing)
        }
        return rows
    }
}

extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader {
                Color.clear.preference(key: SizePreferenceKey.self, value: $0.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

struct NewsSubjectsView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock AuthService for preview if necessary
        let mockAuth = AuthService.shared
        // Optionally, set up a mock user profile
        // mockAuth.userProfile = UserProfile(id: "previewUser", email: "preview@example.com", ...)
        
        return NewsSubjectsView().environmentObject(mockAuth)
    }
} 
