import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Models
struct ConversationMessage: Identifiable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

struct NewsCategory: Identifiable, Hashable {
    let id = UUID()
    let nameKey: String // Store the key instead of the localized string
    let icon: String
    let subcategoryKeys: [String] // Store keys instead of localized strings
    let gnewsCategory: String // Universal category for Google News API
    var isSelected: Bool = false
    
    // Computed property to get localized name
    func localizedName(using languageManager: LanguageManager) -> String {
        return languageManager.localizedString(nameKey)
    }
    
    // Computed property to get localized subcategories
    func localizedSubcategories(using languageManager: LanguageManager) -> [String] {
        return subcategoryKeys.map { languageManager.localizedString($0) }
    }
    
    static let allCategories = [
        NewsCategory(nameKey: "category.world", icon: "globe", subcategoryKeys: [
            "subcategory.europe",
            "subcategory.asia",
            "subcategory.americas",
            "subcategory.africa",
            "subcategory.middle_east"
        ], gnewsCategory: "world"),
        NewsCategory(nameKey: "category.nation", icon: "flag", subcategoryKeys: [
            "subcategory.politics",
            "subcategory.government",
            "subcategory.elections",
            "subcategory.policy"
        ], gnewsCategory: "nation"),
        NewsCategory(nameKey: "category.business", icon: "chart.line.uptrend.xyaxis", subcategoryKeys: [
            "subcategory.markets",
            "subcategory.economy",
            "subcategory.finance",
            "subcategory.startups",
            "subcategory.cryptocurrency"
        ], gnewsCategory: "business"),
        NewsCategory(nameKey: "category.technology", icon: "laptopcomputer", subcategoryKeys: [
            "subcategory.ai",
            "subcategory.mobile",
            "subcategory.software",
            "subcategory.gadgets",
            "subcategory.cybersecurity"
        ], gnewsCategory: "technology"),
        NewsCategory(nameKey: "category.entertainment", icon: "tv", subcategoryKeys: [
            "subcategory.movies",
            "subcategory.music",
            "subcategory.tv_shows",
            "subcategory.celebrities",
            "subcategory.gaming"
        ], gnewsCategory: "entertainment"),
        NewsCategory(nameKey: "category.sports", icon: "sportscourt", subcategoryKeys: [
            "subcategory.football",
            "subcategory.basketball",
            "subcategory.soccer",
            "subcategory.tennis",
            "subcategory.olympics"
        ], gnewsCategory: "sports"),
        NewsCategory(nameKey: "category.science", icon: "atom", subcategoryKeys: [
            "subcategory.space",
            "subcategory.environment",
            "subcategory.research",
            "subcategory.innovation",
            "subcategory.climate"
        ], gnewsCategory: "science"),
        NewsCategory(nameKey: "category.health", icon: "heart.fill", subcategoryKeys: [
            "subcategory.medicine",
            "subcategory.fitness",
            "subcategory.mental_health",
            "subcategory.nutrition",
            "subcategory.pandemic"
        ], gnewsCategory: "health")
    ]
}

struct UserPreferences {
    var selectedCategories: [String] = []
    var selectedSubcategories: [String] = []
    var language: String = "English"
    var country: String = ""
    var updateFrequency: UpdateFrequency = .daily
    var detailLevel: DetailLevel = .medium
    var customTopics: [String] = [] // Kept for backward compatibility
    var subtopicTrends: [String: [String]] = [:] // NEW: Maps subtopic names to their selected trends
    
    // Scheduling preferences
    var dailyTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    var weeklyDay: Int = 1 // Monday
    var weeklyTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
}

// Mapping structure for Google News categories
struct CategoryMapping {
    static let subcategoryToGNewsMapping: [String: String] = [
        // World
        "subcategory.europe": "world-europe",
        "subcategory.asia": "world-asia",
        "subcategory.americas": "world-americas", 
        "subcategory.africa": "world-africa",
        "subcategory.middle_east": "world-middle-east",
        
        // Nation
        "subcategory.politics": "politics",
        "subcategory.government": "politics-government",
        "subcategory.elections": "politics-elections",
        "subcategory.policy": "politics-policy",
        
        // Business
        "subcategory.markets": "business-markets",
        "subcategory.economy": "business-economy",
        "subcategory.finance": "business-finance",
        "subcategory.startups": "business-startups",
        "subcategory.cryptocurrency": "business-crypto",
        
        // Technology
        "subcategory.ai": "technology-ai",
        "subcategory.mobile": "technology-mobile",
        "subcategory.software": "technology-software",
        "subcategory.gadgets": "technology-gadgets",
        "subcategory.cybersecurity": "technology-security",
        
        // Entertainment
        "subcategory.movies": "entertainment-movies",
        "subcategory.music": "entertainment-music",
        "subcategory.tv_shows": "entertainment-tv",
        "subcategory.celebrities": "entertainment-celebrities",
        "subcategory.gaming": "entertainment-gaming",
        
        // Sports
        "subcategory.football": "sports-football",
        "subcategory.basketball": "sports-basketball",
        "subcategory.soccer": "sports-soccer",
        "subcategory.tennis": "sports-tennis",
        "subcategory.olympics": "sports-olympics",
        
        // Science
        "subcategory.space": "science-space",
        "subcategory.environment": "science-environment",
        "subcategory.research": "science-research",
        "subcategory.innovation": "science-innovation",
        "subcategory.climate": "science-climate",
        
        // Health
        "subcategory.medicine": "health-medicine",
        "subcategory.fitness": "health-fitness",
        "subcategory.mental_health": "health-mental",
        "subcategory.nutrition": "health-nutrition",
        "subcategory.pandemic": "health-pandemic"
    ]
    
    static func getGNewsCategory(for localizedCategoryName: String, using languageManager: LanguageManager) -> String? {
        // Find the category that matches the localized name
        for category in NewsCategory.allCategories {
            if category.localizedName(using: languageManager) == localizedCategoryName {
                return category.gnewsCategory
            }
        }
        return nil
    }
    
    static func getGNewsSubcategory(for localizedSubcategoryName: String, using languageManager: LanguageManager) -> String? {
        // Find the subcategory key that matches the localized name
        for category in NewsCategory.allCategories {
            let localizedSubcategories = category.localizedSubcategories(using: languageManager)
            if let index = localizedSubcategories.firstIndex(of: localizedSubcategoryName) {
                let subcategoryKey = category.subcategoryKeys[index]
                return subcategoryToGNewsMapping[subcategoryKey]
            }
        }
        return nil
    }
}

// MARK: - NewsCategory Extension for Category Key Mapping
extension NewsCategory {
    func getCategoryKey(using languageManager: LanguageManager) -> String {
        let categoryName = self.localizedName(using: languageManager).lowercased()
        
        // Map localized category names to catalog keys
        switch categoryName {
        case "nation", "national", "nación", "أمة":
            return "nation"
        case "technology", "technologie", "tecnología", "تكنولوجيا":
            return "technology"
        case "business", "affaires", "negocios", "أعمال":
            return "business"
        case "science", "ciencia", "علوم":
            return "science"
        case "health", "santé", "salud", "صحة":
            return "health"
        case "sports", "deportes", "رياضة":
            return "sports"
        case "entertainment", "divertissement", "entretenimiento", "ترفيه":
            return "entertainment"
        case "world", "monde", "mundo", "عالم":
            return "world"
        default:
            return "technology" // fallback
        }
    }
}

enum UpdateFrequency: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    
    var description: String {
        switch self {
        case .daily: return "Once per day"
        case .weekly: return "Once per week"
        }
    }
}

enum DetailLevel: String, CaseIterable {
    case light = "Light"
    case medium = "Medium"
    case detailed = "Detailed"
    
    var description: String {
        switch self {
        case .light: return "Quick summaries"
        case .medium: return "Balanced coverage"
        case .detailed: return "In-depth analysis"
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "⚡"
        case .medium: return "📰"
        case .detailed: return "📚"
        }
    }
}

// MARK: - Main Preferences View
struct PreferencesView: View {
    @Binding var isPresented: Bool
    let startAtScheduling: Bool // Nouveau paramètre pour démarrer directement au scheduling
    @StateObject private var authService = AuthService.shared
    @StateObject private var conversationService = ConversationService.shared
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var preferences = UserPreferences()
    @State private var currentStep: PreferenceStep = .languageCountry
    @State private var categories = NewsCategory.allCategories
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingConversation = false
    
    // Initializer par défaut
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self.startAtScheduling = false
    }
    
    // Initializer avec option de démarrer au scheduling
    init(isPresented: Binding<Bool>, startAtScheduling: Bool) {
        self._isPresented = isPresented
        self.startAtScheduling = startAtScheduling
    }
    
    enum PreferenceStep: Int, CaseIterable {
        case languageCountry = 0
        case categories = 1
        case subcategories = 2
        case trendingTopics = 3
        case settings = 4
        
        func title(using languageManager: LanguageManager) -> String {
            switch self {
            case .languageCountry: return languageManager.localizedString("preferences.language_country")
            case .categories: return languageManager.localizedString("preferences.choose_interests")
            case .subcategories: return languageManager.localizedString("preferences.refine_selection")
            case .trendingTopics: return languageManager.localizedString("preferences.trending_topics")
            case .settings: return languageManager.localizedString("preferences.final_settings")
            }
        }
        
        func subtitle(using languageManager: LanguageManager) -> String {
            switch self {
            case .languageCountry: return languageManager.localizedString("preferences.setup_language_country")
            case .categories: return languageManager.localizedString("preferences.select_topics")
            case .subcategories: return languageManager.localizedString("preferences.pick_areas")
            case .trendingTopics: return languageManager.localizedString("preferences.select_trending")
            case .settings: return languageManager.localizedString("preferences.configure_frequency")
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Bar
                ProgressBar(currentStep: currentStep.rawValue, totalSteps: PreferenceStep.allCases.count)
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        headerView
                        
                        switch currentStep {
                        case .languageCountry:
                            LanguageCountryStepView(preferences: $preferences)
                        case .categories:
                            CategoriesStepView(
                                categories: categories,
                                preferences: $preferences
                            )
                        case .subcategories:
                            UpdatedSubcategoriesStepView(
                                categories: categories,
                                preferences: $preferences
                            )
                        case .trendingTopics:
                            TrendingTopicsStepView(
                                categories: categories,
                                preferences: $preferences
                            )
                        case .settings:
                            SettingsStepView(preferences: $preferences)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for bottom buttons
                }
                
                Spacer()
                
                // Bottom Navigation
                bottomNavigationView
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemBackground))
        }
        .onAppear {
            loadExistingPreferences()
            
            // Si on doit démarrer directement au scheduling, aller à l'étape settings
            if startAtScheduling {
                currentStep = .settings
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text(currentStep.title(using: languageManager))
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(currentStep.subtitle(using: languageManager))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    private var bottomNavigationView: some View {
        VStack(spacing: 16) {
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 16) {
                if currentStep.rawValue > 0 {
                    Button(languageManager.localizedString("preferences.back")) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = PreferenceStep(rawValue: currentStep.rawValue - 1) ?? .categories
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                
                Button(currentStep == .settings ? languageManager.localizedString("preferences.save") : languageManager.localizedString("preferences.continue")) {
                    if currentStep == .settings {
                        savePreferencesAndNavigateToNewsFeed()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = PreferenceStep(rawValue: currentStep.rawValue + 1) ?? .settings
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canProceed || isSaving)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 34) // Safe area
        .background(Color(UIColor.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .languageCountry:
            return !preferences.language.isEmpty && !preferences.country.isEmpty
        case .categories:
            return !preferences.selectedCategories.isEmpty
        case .subcategories:
            return true // Optional step - user can proceed without selecting subcategories
        case .trendingTopics:
            return true // Optional step - user can proceed without selecting trending topics
        case .settings:
            return !preferences.country.isEmpty
        }
    }
    
    private func loadExistingPreferences() {
        guard let profile = authService.userProfile else { 
            print("❌ No user profile found")
            return 
        }
        
        // Load basic settings from profile
        preferences.language = profile.preferredLanguage
        preferences.country = profile.country
        
        // Load existing preferences from backend
        if let uid = authService.user?.uid {
            conversationService.currentUserId = uid
            
            print("🔍 Loading existing preferences for user update...")
            print("🔍 User ID: \(uid)")
            print("🔍 User profile language: \(profile.preferredLanguage)")
            print("🔍 User profile country: \(profile.country)")
            
            conversationService.loadExistingPreferences { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let existingPreferences):
                        if let existingPreferences = existingPreferences {
                            print("✅ Found existing preferences, populating UI...")
                            print("🔍 Existing preferences details:")
                            print("  - Topics: \(existingPreferences.topics)")
                            print("  - Subtopics count: \(existingPreferences.subtopics.count)")
                            print("  - Subtopics keys: \(Array(existingPreferences.subtopics.keys))")
                            print("  - Detail level: \(existingPreferences.detailLevel)")
                            print("  - Language: \(existingPreferences.language)")
                            
                            // Convert GNews topics back to localized category names and select them
                            self.populateTopicsFromGNews(existingPreferences.topics)
                            
                            // Convert subtopics back to UI selections
                            self.populateSubtopicsFromPreferences(existingPreferences.subtopics)
                            
                            // Load detail level
                            if let detailLevel = DetailLevel(rawValue: existingPreferences.detailLevel) {
                                self.preferences.detailLevel = detailLevel
                            }
                            
                            // Load trending topics (specific subjects)
                            self.preferences.customTopics = self.conversationService.specificSubjects
                            
                            print("🔍 Populated UI with existing preferences:")
                            print("  - Selected categories: \(self.preferences.selectedCategories)")
                            print("  - Selected subcategories: \(self.preferences.selectedSubcategories)")
                            print("  - Custom topics: \(self.preferences.customTopics)")
                            
                        } else {
                            print("ℹ️ No existing preferences found, starting fresh")
                            print("🔍 This means the backend returned success but with nil preferences")
                        }
                    case .failure(let error):
                        print("❌ Error loading existing preferences: \(error)")
                        print("🔍 This means there was a network or parsing error")
                        // Continue with empty preferences - user can start fresh
                    }
                }
            }
        } else {
            print("❌ No user UID found")
        }
    }
    
    private func populateTopicsFromGNews(_ gnewsTopics: [String]) {
        // Convert GNews format topics back to localized category names
        var selectedCategories: [String] = []
        
        for gnewsTopic in gnewsTopics {
            // Find the corresponding localized category name
            for category in NewsCategory.allCategories {
                if category.gnewsCategory == gnewsTopic {
                    let localizedName = category.localizedName(using: languageManager)
                    selectedCategories.append(localizedName)
                    break
                }
            }
        }
        
        preferences.selectedCategories = selectedCategories
        print("🔍 Converted GNews topics \(gnewsTopics) to categories \(selectedCategories)")
    }
    
    private func populateSubtopicsFromPreferences(_ subtopicsDict: [String: SubtopicDetails]) {
        // Extract subtopic names from the dictionary keys
        preferences.selectedSubcategories = Array(subtopicsDict.keys)
        print("🔍 Populated subcategories: \(preferences.selectedSubcategories)")
    }
    
    private func updateSchedulingPreferences(times: [Date], frequency: DailySchedulingView.ScheduleFrequency) {
        // Mettre à jour les préférences de scheduling basées sur les sélections de l'utilisateur
        switch frequency {
        case .daily:
            preferences.updateFrequency = .daily
            if !times.isEmpty {
                preferences.dailyTime = times[0]
            }
        case .weekly:
            preferences.updateFrequency = .weekly
            if !times.isEmpty {
                preferences.weeklyTime = times[0]
            }
        }
    }
    
    private func savePreferences() {
        guard let uid = authService.user?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        // Récupérer les sujets spécifiques existants pour éviter de les écraser
        getExistingSpecificSubjects { existingSubjects in
            // Combiner les sujets existants avec les nouveaux sujets personnalisés
            let allSpecificSubjects = existingSubjects + self.preferences.customTopics
            
            // Créer les préférences de conversation avec tous les sujets
            let conversationPreferences = self.preferences.toConversationPreferences()
            
            // Utiliser le même service backend que ConversationView
            let conversationService = ConversationService.shared
            
            // Mettre à jour les sujets spécifiques dans le service avant de sauvegarder
            conversationService.specificSubjects = allSpecificSubjects
            
            conversationService.saveAllPreferencesAtEnd(conversationPreferences) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        if response.success {
                            // Sauvegarder les paramètres de scheduling séparément
                            self.saveSchedulingPreferences(uid: uid) {
                                // Mettre à jour le profil local
                                self.authService.updateLocalProfileForPrefCompletion(
                                    originalNews: self.preferences.selectedCategories,
                                    refinedNews: self.preferences.selectedCategories,
                                    originalResearch: [],
                                    refinedResearch: [],
                                    newsDetails: Array(repeating: self.preferences.detailLevel.rawValue, count: self.preferences.selectedCategories.count),
                                    researchDetails: []
                                )
                                
                                self.authService.markNewsPreferencesComplete()
                                self.isSaving = false
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        } else {
                            self.errorMessage = "Failed to save preferences: \(response.error ?? "unknown error")"
                            self.isSaving = false
                        }
                    case .failure(let error):
                        self.errorMessage = "Failed to save preferences: \(error.localizedDescription)"
                        self.isSaving = false
                    }
                }
            }
        }
    }
    
    private func getExistingSpecificSubjects(completion: @escaping ([String]) -> Void) {
        guard let uid = authService.user?.uid else {
            completion([])
            return
        }
        
        let db = Firestore.firestore()
        db.collection("preferences").document(uid).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                let existingSubjects = data?["specific_subjects"] as? [String] ?? []
                completion(existingSubjects)
            } else {
                completion([])
            }
        }
    }
    
    private func saveSchedulingPreferences(uid: String, completion: @escaping () -> Void) {
        // Extract scheduling data from preferences
        let type = preferences.updateFrequency.rawValue.lowercased() // "daily" or "weekly"
        
        var day: String? = nil
        var hour: Int
        var minute: Int
        
        // Get hour, minute and day based on frequency type
        switch preferences.updateFrequency {
        case .daily:
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: preferences.dailyTime)
            hour = components.hour ?? 9
            minute = components.minute ?? 0
            day = nil // No day for daily
        case .weekly:
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: preferences.weeklyTime)
            hour = components.hour ?? 9
            minute = components.minute ?? 0
            
            // Convert weeklyDay (1-7) to day name
            let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            if preferences.weeklyDay >= 1 && preferences.weeklyDay <= 7 {
                day = dayNames[preferences.weeklyDay - 1]
            } else {
                day = "monday" // Default fallback
            }
        }
        
        // Use ConversationService to save scheduling preferences
        ConversationService.shared.saveSchedulingPreferences(
            type: type,
            day: day,
            hour: hour,
            minute: minute
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        print("✅ Scheduling preferences saved successfully")
                    } else {
                        print("❌ Failed to save scheduling preferences: \(response.error ?? "Unknown error")")
                    }
                case .failure(let error):
                    print("❌ Error saving scheduling preferences: \(error.localizedDescription)")
                }
                
                // Call completion regardless of success/failure
                completion()
            }
        }
    }
    
    private func getLanguageCode(from language: String) -> String {
        switch language {
        case "Français": return "fr"
        case "العربية": return "ar"
        case "Español": return "es"
        default: return "en"
        }
    }
    
    private func savePreferencesAndNavigateToNewsFeed() {
        guard let uid = authService.user?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        print("🔍 [savePreferencesAndNavigateToNewsFeed] Starting save process")
        print("🔍 Current preferences state:")
        print("    selectedCategories: \(preferences.selectedCategories)")
        print("    selectedSubcategories: \(preferences.selectedSubcategories)")
        print("    customTopics: \(preferences.customTopics)")
        print("    subtopicTrends: \(preferences.subtopicTrends)")
        print("    detailLevel: \(preferences.detailLevel)")
        print("    language: \(preferences.language)")
        
        // Récupérer les sujets spécifiques existants pour éviter de les écraser
        getExistingSpecificSubjects { existingSubjects in
            // Combiner les sujets existants avec les nouveaux sujets personnalisés
            let allSpecificSubjects = existingSubjects + self.preferences.customTopics
            
            print("🔍 [savePreferencesAndNavigateToNewsFeed] Combined specific subjects:")
            print("    existingSubjects: \(existingSubjects)")
            print("    new customTopics: \(self.preferences.customTopics)")
            print("    allSpecificSubjects: \(allSpecificSubjects)")
            
            // Créer les préférences de conversation avec tous les sujets
            let conversationPreferences = self.preferences.toConversationPreferences()
            
            print("🔍 [savePreferencesAndNavigateToNewsFeed] Generated conversation preferences:")
            print("    topics: \(conversationPreferences.topics)")
            print("    subtopics keys: \(conversationPreferences.subtopics.keys.sorted())")
            for (subtopic, details) in conversationPreferences.subtopics {
                print("      '\(subtopic)' -> subreddits: \(details.subreddits), queries: \(details.queries)")
            }
            print("    detailLevel: \(conversationPreferences.detailLevel)")
            print("    language: \(conversationPreferences.language)")
            
            // Utiliser le même service backend que ConversationView
            let conversationService = ConversationService.shared
            conversationService.currentUserId = uid
            
            // Mettre à jour les sujets spécifiques dans le service avant de sauvegarder
            conversationService.specificSubjects = allSpecificSubjects
            
            print("🔍 [savePreferencesAndNavigateToNewsFeed] Saving conversation preferences")
            conversationService.saveAllPreferencesAtEnd(conversationPreferences) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        if response.success {
                            print("🔍 [savePreferencesAndNavigateToNewsFeed] Conversation preferences saved successfully")
                
                            // Sauvegarder les paramètres de scheduling
                            print("🔍 [savePreferencesAndNavigateToNewsFeed] Saving scheduling preferences")
                            self.saveSchedulingPreferences(uid: uid) {
                                print("🔍 [savePreferencesAndNavigateToNewsFeed] Scheduling preferences saved")
                                
                                // Mettre à jour le profil local
                                self.authService.updateLocalProfileForPrefCompletion(
                                    originalNews: self.preferences.selectedCategories,
                                    refinedNews: self.preferences.selectedCategories,
                                    originalResearch: [],
                                    refinedResearch: [],
                                    newsDetails: Array(repeating: self.preferences.detailLevel.rawValue, count: self.preferences.selectedCategories.count),
                                    researchDetails: []
                                )
                                
                                // IMPORTANT: Marquer les préférences comme complètes AVANT de mettre à jour le profil
                                print("🔍 [savePreferencesAndNavigateToNewsFeed] Marking preferences as complete")
                                self.authService.markNewsPreferencesComplete()
                                
                                // Attendre un peu pour s'assurer que markNewsPreferencesComplete est terminé
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    // Maintenant mettre à jour le profil avec langue et pays
                                    if !self.preferences.language.isEmpty && !self.preferences.country.isEmpty {
                                        print("🔍 [savePreferencesAndNavigateToNewsFeed] Updating user profile with language and country")
                                        self.authService.updateUserProfile(
                                            firstName: self.authService.userProfile?.firstName ?? "",
                                            surname: self.authService.userProfile?.surname ?? "",
                                            age: self.authService.userProfile?.age,
                                            country: self.preferences.country,
                                            preferredLanguage: self.preferences.language
                                        )
                                    }
                                    
                                    // Attendre encore un peu pour s'assurer que tout est sauvegardé
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        print("🔍 [savePreferencesAndNavigateToNewsFeed] All operations complete, dismissing preferences")
                                        self.isSaving = false
                                        
                                        // Fermer PreferencesView pour retourner au NewsFeedView
                                        self.presentationMode.wrappedValue.dismiss()
                                    }
                                }
                            }
                        } else {
                            self.errorMessage = "Failed to save preferences: \(response.error ?? "unknown error")"
                            self.isSaving = false
                        }
                    case .failure(let error):
                        self.errorMessage = "Failed to save preferences: \(error.localizedDescription)"
                        self.isSaving = false
                    }
                }
            }
        }
    }
}

// MARK: - Step Views
struct CategoriesStepView: View {
    let categories: [NewsCategory]
    @Binding var preferences: UserPreferences
    @EnvironmentObject var languageManager: LanguageManager
    
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(categories.indices, id: \.self) { index in
                CategoryCard(
                    category: categories[index],
                    isSelected: preferences.selectedCategories.contains(categories[index].localizedName(using: languageManager)),
                    languageManager: languageManager
                ) {
                    toggleCategory(at: index)
                }
            }
        }
    }
    
    private func toggleCategory(at index: Int) {
        let categoryName = categories[index].localizedName(using: languageManager)
        
        if preferences.selectedCategories.contains(categoryName) {
            preferences.selectedCategories.removeAll { $0 == categoryName }
            // Also remove related subcategories
            let subcategories = categories[index].localizedSubcategories(using: languageManager)
            preferences.selectedSubcategories.removeAll { subcategories.contains($0) }
        } else {
            preferences.selectedCategories.append(categoryName)
        }
    }
}

struct UpdatedSubcategoriesStepView: View {
    let categories: [NewsCategory]
    @Binding var preferences: UserPreferences
    @EnvironmentObject var languageManager: LanguageManager
    
    var selectedCategories: [NewsCategory] {
        categories.filter { preferences.selectedCategories.contains($0.localizedName(using: languageManager)) }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if selectedCategories.isEmpty {
                // Message si aucune catégorie n'est sélectionnée
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text(languageManager.localizedString("preferences.no_categories_selected"))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(languageManager.localizedString("preferences.go_back_select_categories"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                // Instructions pour l'utilisateur
                VStack(alignment: .leading, spacing: 8) {
                    Text(languageManager.localizedString("preferences.subcategories_instruction"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(languageManager.localizedString("preferences.subcategories_optional"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Catégories et sous-catégories
                ForEach(selectedCategories, id: \.id) { category in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.localizedName(using: languageManager))
                                    .font(.headline)
                                
                                let selectedCount = getSelectedSubtopicsCount(for: category)
                                Text(String(format: languageManager.localizedString("preferences.selected_count"), selectedCount))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Bouton pour tout sélectionner/désélectionner
                            Button(allSubtopicsSelected(for: category) ? 
                                   languageManager.localizedString("preferences.deselect_all") : 
                                   languageManager.localizedString("preferences.select_all")) {
                                toggleAllSubtopics(for: category)
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        // Hardcoded subtopics from catalog
                        let categoryKey = getCategoryKey(for: category)
                        let hardcodedSubtopics = SubtopicsCatalog.getSubtopicTitles(for: categoryKey)
                        
                        if !hardcodedSubtopics.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                                ForEach(hardcodedSubtopics, id: \.self) { subtopic in
                                SubcategoryChip(
                                        name: subtopic,
                                        isSelected: preferences.selectedSubcategories.contains(subtopic),
                                        isHardcoded: true
                                ) {
                                        toggleSubtopic(subtopic)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func getCategoryKey(for category: NewsCategory) -> String {
        return category.getCategoryKey(using: languageManager)
    }
    
    private func getSelectedSubtopicsCount(for category: NewsCategory) -> Int {
        let categoryKey = category.getCategoryKey(using: languageManager)
        let hardcodedSubtopics = SubtopicsCatalog.getSubtopicTitles(for: categoryKey)
        
        return hardcodedSubtopics.filter { preferences.selectedSubcategories.contains($0) }.count
    }
    
    private func toggleSubtopic(_ subtopic: String) {
        if preferences.selectedSubcategories.contains(subtopic) {
            preferences.selectedSubcategories.removeAll { $0 == subtopic }
        } else {
            preferences.selectedSubcategories.append(subtopic)
        }
    }
    
    private func allSubtopicsSelected(for category: NewsCategory) -> Bool {
        let categoryKey = category.getCategoryKey(using: languageManager)
        let hardcodedSubtopics = SubtopicsCatalog.getSubtopicTitles(for: categoryKey)
        
        return hardcodedSubtopics.allSatisfy { preferences.selectedSubcategories.contains($0) }
    }
    
    private func toggleAllSubtopics(for category: NewsCategory) {
        let categoryKey = category.getCategoryKey(using: languageManager)
        let hardcodedSubtopics = SubtopicsCatalog.getSubtopicTitles(for: categoryKey)
        
        if allSubtopicsSelected(for: category) {
            // Désélectionner toutes les sous-catégories de cette catégorie
            preferences.selectedSubcategories.removeAll { hardcodedSubtopics.contains($0) }
        } else {
            // Sélectionner toutes les sous-catégories de cette catégorie
            for subtopic in hardcodedSubtopics {
                if !preferences.selectedSubcategories.contains(subtopic) {
                    preferences.selectedSubcategories.append(subtopic)
                }
            }
        }
    }
}

struct TrendingTopicsStepView: View {
    let categories: [NewsCategory]
    @Binding var preferences: UserPreferences
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var trendingService = TrendingSubtopicsService.shared
    @State private var trendingTopics: [String: [String]] = [:]
    @State private var loadingTrending: Set<String> = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var lastSelectedSubtopics: [String] = [] // Track last selected subtopics
    
    var selectedCategories: [NewsCategory] {
        categories.filter { preferences.selectedCategories.contains($0.localizedName(using: languageManager)) }
    }
    
    var selectedSubtopics: [SubtopicMeta] {
        var allSubtopics: [SubtopicMeta] = []
        
        for category in selectedCategories {
            let categoryKey = category.getCategoryKey(using: languageManager)
            let categorySubtopics = SubtopicsCatalog.getAllSubtopics(for: categoryKey)
            let selectedCategorySubtopics = categorySubtopics.filter { 
                preferences.selectedSubcategories.contains($0.title) 
            }
            allSubtopics.append(contentsOf: selectedCategorySubtopics)
        }
        
        return allSubtopics
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if selectedSubtopics.isEmpty {
                // Message si aucune sous-catégorie n'est sélectionnée
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text(languageManager.localizedString("preferences.no_subtopics_selected"))
                    .font(.headline)
                        .multilineTextAlignment(.center)
                
                    Text(languageManager.localizedString("preferences.go_back_select_subtopics"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text(languageManager.localizedString("preferences.trending_instruction"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                    Text(languageManager.localizedString("preferences.trending_optional"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                if isLoading {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text(languageManager.localizedString("preferences.loading_trending_topics"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(languageManager.localizedString("preferences.analyzing_subtopics"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if hasLoaded {
                    // Show trending topics grouped by subtopic
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(selectedSubtopics, id: \.title) { subtopic in
                                if let trending = trendingTopics[subtopic.title], !trending.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                            Image(systemName: "flame.fill")
                                                .foregroundColor(.orange)
                                                .font(.title3)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(subtopic.title)
                                                    .font(.headline)
                                                    .fontWeight(.semibold)
                                                
                                                let selectedCount = trending.filter { preferences.customTopics.contains($0) }.count
                                                Text(String(format: languageManager.localizedString("preferences.selected_count"), selectedCount))
                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            // Select all/deselect all button
                                            Button(allTrendingSelected(for: subtopic.title) ? 
                                                   languageManager.localizedString("preferences.deselect_all") : 
                                                   languageManager.localizedString("preferences.select_all")) {
                                                toggleAllTrending(for: subtopic.title)
                                            }
                                    .font(.caption)
                                            .foregroundColor(.orange)
                                        }
                                        
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                                            ForEach(trending, id: \.self) { trendingTopic in
                                                TrendingTopicChip(
                                                    name: trendingTopic,
                                                    isSelected: isTrendingSelected(trendingTopic, for: subtopic.title)
                                                ) {
                                                    toggleTrendingTopic(trendingTopic, for: subtopic.title)
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Summary section
                            let totalSelectedTrends = preferences.subtopicTrends.values.flatMap { $0 }.count
                            if totalSelectedTrends > 0 {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title3)
                                        
                                        Text(languageManager.localizedString("preferences.selected_trending"))
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                        
                                Spacer()
                                        
                                        Text("\(totalSelectedTrends)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                    
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                                        ForEach(preferences.subtopicTrends.values.flatMap { $0 }, id: \.self) { topic in
                                            TrendingTopicChip(
                                                name: topic,
                                                isSelected: true
                                            ) {
                                                // Find which subtopic this trend belongs to and remove it
                                                for (subtopic, trends) in preferences.subtopicTrends {
                                                    if trends.contains(topic) {
                                                        toggleTrendingTopic(topic, for: subtopic)
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.green.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
                } else {
                    // Initial state - show button to load trending
                    VStack(spacing: 16) {
                        Image(systemName: "flame")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text(languageManager.localizedString("preferences.discover_trending"))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text(languageManager.localizedString("preferences.trending_description"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(languageManager.localizedString("preferences.load_trending")) {
                            loadTrendingTopics()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 200)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
            }
        }
        .onAppear {
            checkForSubtopicChanges()
            
            // Auto-load if we have selected subtopics and haven't loaded yet
            if !selectedSubtopics.isEmpty && !hasLoaded && !isLoading {
                loadTrendingTopics()
            }
        }
        .onChange(of: selectedSubtopics.map { $0.title }) { newSubtopics in
            checkForSubtopicChanges()
        }
    }
    
    private func checkForSubtopicChanges() {
        let currentSubtopicTitles = selectedSubtopics.map { $0.title }
        
        // Check if subtopics have changed
        if currentSubtopicTitles != lastSelectedSubtopics {
            print("DEBUG: [TrendingTopicsStepView] Subtopics changed from \(lastSelectedSubtopics) to \(currentSubtopicTitles)")
            
            // Clean up trending topics that no longer correspond to selected subtopics
            cleanupObsoleteTrendingTopics(currentSubtopics: currentSubtopicTitles)
            
            // Reset loading state if subtopics changed
            if hasLoaded {
                hasLoaded = false
                trendingTopics.removeAll()
                print("DEBUG: [TrendingTopicsStepView] Reset trending topics state due to subtopic changes")
            }
            
            // Update tracking
            lastSelectedSubtopics = currentSubtopicTitles
        }
    }
    
    private func cleanupObsoleteTrendingTopics(currentSubtopics: [String]) {
        // Get all trending topics that are currently available for the selected subtopics
        var validTrendingTopics: Set<String> = []
        
        for subtopicTitle in currentSubtopics {
            if let trending = trendingTopics[subtopicTitle] {
                validTrendingTopics.formUnion(trending)
            }
        }
        
        // Remove trending topics that are no longer valid
        let originalCount = preferences.customTopics.count
        preferences.customTopics = preferences.customTopics.filter { topic in
            // Keep the topic if it's still available in current trending topics
            // or if we haven't loaded trending yet (to avoid removing valid topics prematurely)
            return validTrendingTopics.contains(topic) || !hasLoaded
        }
        
        let removedCount = originalCount - preferences.customTopics.count
        if removedCount > 0 {
            print("DEBUG: [TrendingTopicsStepView] Removed \(removedCount) obsolete trending topics")
        }
    }
    
    private func loadTrendingTopics() {
        guard !selectedSubtopics.isEmpty else { return }
        
        isLoading = true
        trendingTopics.removeAll()
        
        Task {
            for subtopic in selectedSubtopics {
                do {
                    let trending = try await trendingService.fetchTrendingForSubtopic(
                        title: subtopic.title,
                        query: subtopic.query,
                        subreddits: subtopic.subreddits,
                        language: getLanguageCode(),
                        country: getCountryCode(),
                        maxArticles: 10
                    )
                    
                    await MainActor.run {
                        trendingTopics[subtopic.title] = trending
                    }
                } catch {
                    print("Failed to load trending for subtopic \(subtopic.title): \(error)")
                    await MainActor.run {
                        trendingTopics[subtopic.title] = []
                    }
                }
            }
            
            await MainActor.run {
                isLoading = false
                hasLoaded = true
                
                // Clean up obsolete trending topics now that we have fresh data
                cleanupObsoleteTrendingTopicsAfterLoad()
            }
        }
    }
    
    private func cleanupObsoleteTrendingTopicsAfterLoad() {
        // Get all currently available trending topics
        var allAvailableTrending: Set<String> = []
        for (_, trending) in trendingTopics {
            allAvailableTrending.formUnion(trending)
        }
        
        // Filter out trending topics that are no longer available
        let originalCount = preferences.customTopics.count
        preferences.customTopics = preferences.customTopics.filter { topic in
            allAvailableTrending.contains(topic)
        }
        
        let removedCount = originalCount - preferences.customTopics.count
        if removedCount > 0 {
            print("DEBUG: [TrendingTopicsStepView] Cleaned up \(removedCount) obsolete trending topics after loading fresh data")
        }
    }
    
    private func getLanguageCode() -> String {
        switch languageManager.currentLanguage {
        case "English": return "en"
        case "Français": return "fr"
        case "Español": return "es"
        case "العربية": return "ar"
        default: return "en"
        }
    }
    
    private func getCountryCode() -> String {
        let countryMappings: [String: String] = [
            "United States": "us",
            "France": "fr",
            "Spain": "es",
            "United Kingdom": "gb",
            "Canada": "ca",
            "Germany": "de",
            "Italy": "it",
            "Japan": "jp",
            "Australia": "au",
            "Brazil": "br"
        ]
        return countryMappings[preferences.country] ?? "us"
    }
    
    private func toggleTrendingTopic(_ topic: String) {
        if preferences.customTopics.contains(topic) {
            preferences.customTopics.removeAll { $0 == topic }
        } else {
            preferences.customTopics.append(topic)
        }
    }
    
    private func allTrendingSelected(for subtopicTitle: String) -> Bool {
        guard let trending = trendingTopics[subtopicTitle] else { 
            print("🔍 [allTrendingSelected] No trending topics found for '\(subtopicTitle)'")
            return false 
        }
        let selectedForSubtopic = preferences.subtopicTrends[subtopicTitle] ?? []
        let allSelected = trending.allSatisfy { selectedForSubtopic.contains($0) }
        print("🔍 [allTrendingSelected] Subtopic: '\(subtopicTitle)', Trending: \(trending.count), Selected: \(selectedForSubtopic.count), All selected: \(allSelected)")
        return allSelected
    }
    
    private func toggleAllTrending(for subtopicTitle: String) {
        guard let trending = trendingTopics[subtopicTitle] else { 
            print("🔍 [toggleAllTrending] No trending topics found for '\(subtopicTitle)'")
            return 
        }
        
        print("🔍 [toggleAllTrending] BEFORE - Subtopic: '\(subtopicTitle)', Available trends: \(trending)")
        print("    Current subtopicTrends: \(preferences.subtopicTrends)")
        print("    Current customTopics: \(preferences.customTopics)")
        
        if allTrendingSelected(for: subtopicTitle) {
            // Deselect all trending for this subtopic
            preferences.subtopicTrends[subtopicTitle] = []
            // Also remove from customTopics for backward compatibility
            preferences.customTopics.removeAll { trending.contains($0) }
            print("    DESELECTED all trends for '\(subtopicTitle)'")
        } else {
            // Select all trending for this subtopic
            preferences.subtopicTrends[subtopicTitle] = trending
            // Also add to customTopics for backward compatibility
            for topic in trending {
                if !preferences.customTopics.contains(topic) {
                    preferences.customTopics.append(topic)
                }
            }
            print("    SELECTED all trends for '\(subtopicTitle)'")
        }
        
        print("🔍 [toggleAllTrending] AFTER - Updated trends for '\(subtopicTitle)': \(preferences.subtopicTrends[subtopicTitle] ?? [])")
        print("    Updated subtopicTrends: \(preferences.subtopicTrends)")
        print("    Updated customTopics: \(preferences.customTopics)")
    }
    
    private func isTrendingSelected(_ topic: String, for subtopic: String) -> Bool {
        let isSelected = preferences.subtopicTrends[subtopic]?.contains(topic) ?? false
        print("🔍 [isTrendingSelected] Topic: '\(topic)', Subtopic: '\(subtopic)' -> \(isSelected)")
        return isSelected
    }
    
    private func toggleTrendingTopic(_ topic: String, for subtopic: String) {
        print("🔍 [toggleTrendingTopic] BEFORE - Topic: '\(topic)', Subtopic: '\(subtopic)'")
        print("    Current subtopicTrends: \(preferences.subtopicTrends)")
        print("    Current customTopics: \(preferences.customTopics)")
        
        // Initialize subtopic trends array if it doesn't exist
        if preferences.subtopicTrends[subtopic] == nil {
            preferences.subtopicTrends[subtopic] = []
            print("    Initialized empty array for subtopic '\(subtopic)'")
        }
        
        // Toggle the trend for this specific subtopic
        if var trends = preferences.subtopicTrends[subtopic] {
            if trends.contains(topic) {
                trends.removeAll { $0 == topic }
                // Also remove from customTopics for backward compatibility
                preferences.customTopics.removeAll { $0 == topic }
                print("    REMOVED trend '\(topic)' from subtopic '\(subtopic)'")
            } else {
                trends.append(topic)
                // Also add to customTopics for backward compatibility
                if !preferences.customTopics.contains(topic) {
                    preferences.customTopics.append(topic)
                }
                print("    ADDED trend '\(topic)' to subtopic '\(subtopic)'")
            }
            preferences.subtopicTrends[subtopic] = trends
        }
        
        print("🔍 [toggleTrendingTopic] AFTER - Updated trends for '\(subtopic)': \(preferences.subtopicTrends[subtopic] ?? [])")
        print("    Updated subtopicTrends: \(preferences.subtopicTrends)")
        print("    Updated customTopics: \(preferences.customTopics)")
    }
}

struct TrendingTopicChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 8))
                    .foregroundColor(isSelected ? .white : .orange)
                
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .orange)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.orange : Color.orange.opacity(0.1))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsStepView: View {
    @Binding var preferences: UserPreferences
    @State private var showCountryPicker = false
    @EnvironmentObject var languageManager: LanguageManager
    
    private let weekdays = [
        (1, "Monday"), (2, "Tuesday"), (3, "Wednesday"), (4, "Thursday"),
        (5, "Friday"), (6, "Saturday"), (7, "Sunday")
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Country Selection
            VStack(alignment: .leading, spacing: 16) {
                Text(languageManager.localizedString("preferences.country"))
                    .font(.headline)
                
                Button(action: { showCountryPicker = true }) {
                    HStack {
                        Text(preferences.country.isEmpty ? languageManager.localizedString("preferences.select_country") : preferences.country)
                            .foregroundColor(preferences.country.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
            
            // Update Frequency with Time Selection
            VStack(alignment: .leading, spacing: 16) {
                Text(languageManager.localizedString("preferences.update_frequency"))
                    .font(.headline)
                
                VStack(spacing: 12) {
                    ForEach(UpdateFrequency.allCases, id: \.self) { frequency in
                        VStack(spacing: 8) {
                            FrequencyOption(
                                frequency: frequency,
                                isSelected: preferences.updateFrequency == frequency
                            ) {
                                preferences.updateFrequency = frequency
                            }
                            
                            // Time selectors based on frequency
                            if preferences.updateFrequency == frequency {
                                switch frequency {
                                case .daily:
                                    HStack {
                                        Text(languageManager.localizedString("preferences.time"))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        DatePicker("", selection: $preferences.dailyTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                    .padding(.horizontal)
                                    
                                case .weekly:
                                    VStack(spacing: 8) {
                                        HStack {
                                            Text(languageManager.localizedString("preferences.day"))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Picker("Day", selection: $preferences.weeklyDay) {
                                                ForEach(weekdays, id: \.0) { day in
                                                    Text(day.1).tag(day.0)
                                                }
                                            }
                                            .pickerStyle(MenuPickerStyle())
                                        }
                                        
                                        HStack {
                                            Text(languageManager.localizedString("preferences.time"))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            DatePicker("", selection: $preferences.weeklyTime, displayedComponents: .hourAndMinute)
                                                .labelsHidden()
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
            
            // Detail Level
            VStack(alignment: .leading, spacing: 16) {
                Text(languageManager.localizedString("preferences.detail_level"))
                    .font(.headline)
                
                VStack(spacing: 12) {
                    ForEach(DetailLevel.allCases, id: \.self) { level in
                        DetailLevelOption(
                            level: level,
                            isSelected: preferences.detailLevel == level
                        ) {
                            preferences.detailLevel = level
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selectedCountry: $preferences.country, isPresented: $showCountryPicker)
        }
    }
}

// MARK: - Supporting Views
struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    if step < totalSteps - 1 {
                        Rectangle()
                            .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.systemBackground))
    }
}

struct CategoryCard: View {
    let category: NewsCategory
    let isSelected: Bool
    let languageManager: LanguageManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(category.localizedName(using: languageManager))
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SubcategoryChip: View {
    let name: String
    let isSelected: Bool
    let isHardcoded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if !isHardcoded {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundColor(isSelected ? .white : .orange)
                }
                
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : (isHardcoded ? .blue : .orange))
            }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            .background(isSelected ? (isHardcoded ? Color.blue : Color.orange) : (isHardcoded ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1)))
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FrequencyOption: View {
    let frequency: UpdateFrequency
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(frequency.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(frequency.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DetailLevelOption: View {
    let level: DetailLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(level.icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Conversation UI Components
struct ConversationBubble: View {
    let message: ConversationMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .frame(maxWidth: 250, alignment: .trailing)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                            .font(.caption)
                        
                        Text(message.content)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .frame(maxWidth: 250, alignment: .leading)
                    }
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                }
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                    .font(.caption)
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 6, height: 6)
                            .offset(y: animationOffset)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: animationOffset
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
            }
            Spacer()
        }
        .onAppear {
            animationOffset = -3
        }
    }
}

// MARK: - Language & Country Step View
struct LanguageCountryStepView: View {
    @Binding var preferences: UserPreferences
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showCountryPicker = false
    
    private let availableLanguages = ["English"]
    
    private let countries = [
        "United States", "Canada", "United Kingdom", "France", "Germany", "Spain", "Italy",
        "Netherlands", "Belgium", "Switzerland", "Austria", "Portugal", "Ireland", "Denmark",
        "Sweden", "Norway", "Finland", "Poland", "Czech Republic", "Hungary", "Greece",
        "Turkey", "Russia", "Ukraine", "Romania", "Bulgaria", "Croatia", "Serbia", "Slovenia",
        "Slovakia", "Lithuania", "Latvia", "Estonia", "Malta", "Cyprus", "Luxembourg",
        "Morocco", "Algeria", "Tunisia", "Egypt", "Saudi Arabia", "UAE", "Qatar", "Kuwait",
        "Bahrain", "Oman", "Jordan", "Lebanon", "Syria", "Iraq", "Iran", "Israel", "Palestine",
        "Japan", "South Korea", "China", "India", "Australia", "New Zealand", "Singapore",
        "Malaysia", "Thailand", "Philippines", "Indonesia", "Vietnam", "Cambodia", "Laos",
        "Myanmar", "Bangladesh", "Pakistan", "Sri Lanka", "Nepal", "Bhutan", "Maldives",
        "Brazil", "Argentina", "Chile", "Colombia", "Peru", "Venezuela", "Ecuador", "Uruguay",
        "Paraguay", "Bolivia", "Guyana", "Suriname", "French Guiana", "Mexico", "Guatemala",
        "Belize", "El Salvador", "Honduras", "Nicaragua", "Costa Rica", "Panama", "Cuba",
        "Jamaica", "Haiti", "Dominican Republic", "Puerto Rico", "Trinidad and Tobago",
        "Barbados", "Bahamas", "South Africa", "Nigeria", "Kenya", "Ghana", "Ethiopia",
        "Tanzania", "Uganda", "Rwanda", "Botswana", "Namibia", "Zambia", "Zimbabwe",
        "Mozambique", "Madagascar", "Mauritius", "Seychelles"
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            // Language Selection
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "textformat")
                        .foregroundColor(.blue)
                    Text(languageManager.localizedString("preferences.select_language"))
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(availableLanguages, id: \.self) { language in
                        LanguageSelectionCard(
                            language: language,
                            isSelected: preferences.language == language
                        ) {
                            preferences.language = language
                            // Force immediate language change
                            DispatchQueue.main.async {
                                languageManager.currentLanguage = language
                            }
                        }
                    }
                }
            }
            
            // Country Selection
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.blue)
                    Text(languageManager.localizedString("preferences.select_country"))
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                Button(action: {
                    showCountryPicker = true
                }) {
                    HStack {
                        Text(preferences.country.isEmpty ? languageManager.localizedString("preferences.choose_country") : preferences.country)
                            .foregroundColor(preferences.country.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(preferences.country.isEmpty ? Color.clear : Color.blue, lineWidth: 2)
                            )
                    )
                }
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selectedCountry: $preferences.country, isPresented: $showCountryPicker)
        }
        .onAppear {
            // Set initial language if not set
            if preferences.language.isEmpty {
                preferences.language = languageManager.currentLanguage
            }
        }
    }
}

struct LanguageSelectionCard: View {
    let language: String
    let isSelected: Bool
    let action: () -> Void
    
    private var languageFlag: String {
        switch language {
        case "English": return "🇺🇸"
        case "Français": return "🇫🇷"
        case "العربية": return "🇸🇦"
        case "Español": return "🇪🇸"
        default: return "🌐"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(languageFlag)
                    .font(.system(size: 30))
                
                Text(language)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected
                        ? LinearGradient(
                            gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor.secondarySystemBackground),
                                Color(UIColor.secondarySystemBackground)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct CountryPickerView: View {
    let countries: [String]?
    @Binding var selectedCountry: String
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @EnvironmentObject var languageManager: LanguageManager
    
    // Default countries list if none provided
    private static let defaultCountries = [
        "United States", "Canada", "United Kingdom", "France", "Germany", "Spain", "Italy",
        "Netherlands", "Belgium", "Switzerland", "Austria", "Portugal", "Ireland", "Denmark",
        "Sweden", "Norway", "Finland", "Poland", "Czech Republic", "Hungary", "Greece",
        "Turkey", "Russia", "Ukraine", "Romania", "Bulgaria", "Croatia", "Serbia", "Slovenia",
        "Slovakia", "Lithuania", "Latvia", "Estonia", "Malta", "Cyprus", "Luxembourg",
        "Morocco", "Algeria", "Tunisia", "Egypt", "Saudi Arabia", "UAE", "Qatar", "Kuwait",
        "Bahrain", "Oman", "Jordan", "Lebanon", "Syria", "Iraq", "Iran", "Israel", "Palestine",
        "Japan", "South Korea", "China", "India", "Australia", "New Zealand", "Singapore",
        "Malaysia", "Thailand", "Philippines", "Indonesia", "Vietnam", "Cambodia", "Laos",
        "Myanmar", "Bangladesh", "Pakistan", "Sri Lanka", "Nepal", "Bhutan", "Maldives",
        "Brazil", "Argentina", "Chile", "Colombia", "Peru", "Venezuela", "Ecuador", "Uruguay",
        "Paraguay", "Bolivia", "Guyana", "Suriname", "French Guiana", "Mexico", "Guatemala",
        "Belize", "El Salvador", "Honduras", "Nicaragua", "Costa Rica", "Panama", "Cuba",
        "Jamaica", "Haiti", "Dominican Republic", "Puerto Rico", "Trinidad and Tobago",
        "Barbados", "Bahamas", "South Africa", "Nigeria", "Kenya", "Ghana", "Ethiopia",
        "Tanzania", "Uganda", "Rwanda", "Botswana", "Namibia", "Zambia", "Zimbabwe",
        "Mozambique", "Madagascar", "Mauritius", "Seychelles"
    ]
    
    private var filteredCountries: [String] {
        let countryList = countries ?? CountryPickerView.defaultCountries
        if searchText.isEmpty {
            return countryList
        } else {
            return countryList.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // Convenience initializer for when no countries array is provided
    init(selectedCountry: Binding<String>, isPresented: Binding<Bool>) {
        self.countries = nil
        self._selectedCountry = selectedCountry
        self._isPresented = isPresented
    }
    
    // Full initializer with countries array
    init(countries: [String], selectedCountry: Binding<String>, isPresented: Binding<Bool>) {
        self.countries = countries
        self._selectedCountry = selectedCountry
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, placeholder: languageManager.localizedString("preferences.search_countries"))
                    .padding(.horizontal)
                
                List(filteredCountries, id: \.self) { country in
                    Button(action: {
                        selectedCountry = country
                        isPresented = false
                    }) {
                        HStack {
                            Text(country)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedCountry == country {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(languageManager.localizedString("preferences.select_country"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button(languageManager.localizedString("preferences.cancel")) {
                    isPresented = false
                }
            )
        }
    }
}

// MARK: - Preview
struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView(isPresented: .constant(true))
            .environmentObject(AuthService.shared)
            .environmentObject(LanguageManager())
    }
} 