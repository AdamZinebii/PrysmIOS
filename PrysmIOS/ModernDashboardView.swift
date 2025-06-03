import SwiftUI
import FirebaseFirestore

struct ModernDashboardView: View {
    @StateObject private var aiFeedService = AIFeedService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var newsFeedViewModel = NewsFeedViewModel()
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var updateService = UpdateService.shared
    @State private var showSettings = false
    @State private var showPreferences = false
    @State private var selectedTopic: TopicReport?
    @State private var scrollOffset: CGFloat = 0
    
    // Audio player integration
    @ObservedObject private var audioPlayerService = AudioPlayerService.shared
    
    // Logging service
    @StateObject private var loggingService = LoggingService.shared
    
    // Scheduling preferences
    @State private var schedulingType: String = "daily"
    @State private var schedulingTime: String = ""
    @State private var schedulingDay: String = ""
    @State private var nextUpdateTimeString: String = "Calculating..."
    @State private var isLoadingSchedule = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background
                dynamicBackground
                
                VStack(spacing: 0) {
                    // Static Hero header (not scrollable)
                        heroHeader
                        
                    // Static white background container that goes to bottom
                    ZStack {
                        // Fixed white background extending to bottom
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
                        
                        VStack(spacing: 0) {
                            // Fixed section header (not scrollable)
                            fixedSectionHeader
                            
                            // Scrollable content inside the white zone
                            ScrollView {
                                scrollableArticles
                                    .padding(.top, 20)
                                    .padding(.bottom, 100) // Extra padding to ensure content goes to bottom
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                .refreshable {
                    loggingService.logRefreshTriggered(context: "pull_to_refresh")
                    await refreshData()
                }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                    }
                    .padding(.bottom, -50) // Extend below the visible area
                }
                .ignoresSafeArea(.container, edges: .bottom) // Ignore bottom safe area
                
                // Background saving overlay
                if authService.isSavingPreferencesInBackground {
                    backgroundSavingOverlay
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
            .fullScreenCover(isPresented: $showPreferences) {
                PreferencesView(isPresented: $showPreferences, isOptional: true)
            }
        }
        .onAppear {
            Task {
                await loadInitialData()
                // Load user's podcast from Firebase
                await loadUserPodcast()
                
                // Log app entrance
                loggingService.logAppEntered()
            }
        }
        .sheet(item: $selectedTopic) { topic in
            TopicDetailView(topic: topic)
                .onAppear {
                    // Log topic summary view
                    loggingService.logTopicSummaryViewed(
                        topicName: topic.displayTitle,
                        topicId: topic.topicName
                    )
                }
        }
    }
    
    // MARK: - Views
    
    private var dynamicBackground: some View {
        ZStack {
            // Base gradient using theme colors
            LinearGradient(
                gradient: Gradient(colors: themeManager.backgroundGradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated particles
            ForEach(0..<15, id: \.self) { index in
                FloatingParticle(index: index, accentColor: themeManager.particleColor)
            }
        }
        .ignoresSafeArea()
    }
    
    private var heroHeader: some View {
        VStack(spacing: 0) {
            // Status bar spacer
            Rectangle()
                .fill(Color.clear)
                .frame(height: 50)
            
            // Header content
            VStack(spacing: 20) {
                // Top bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getCurrentGreeting())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                        
                        if let userProfile = authService.userProfile,
                           !userProfile.firstName.isEmpty {
                            Text(userProfile.firstName)
                                .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    // Settings button
                    Button(action: {
                            showSettings = true
                            loggingService.logSettingsOpened()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                
                // Modern Audio Player - Always visible
                ModernAudioPlayer(podcastTitle: getUserPodcastTitle())
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                
                // Simple Update Section
                if !isLoadingSchedule && !nextUpdateTimeString.isEmpty && nextUpdateTimeString != "Calculating..." {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Next update in \(nextUpdateTimeString)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Text(schedulingType.capitalized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }
            }
            .padding(.bottom, 30)
            .background(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.clear, location: 0),
                                .init(color: Color.black.opacity(0.1), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
        }
    }
    
    private var fixedSectionHeader: some View {
        HStack {
            Text("Your Briefing")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(aiFeedService.aiFeedData?.reportsArray.count ?? 0) topics")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
    }
    
    private var scrollableArticles: some View {
        VStack(spacing: 0) {
            // Check if this is a first-time user and show appropriate state
            if updateService.isUpdating {
                firstTimeLoadingView
            } else if aiFeedService.isLoading {
                loadingView
            } else if let error = aiFeedService.error {
                errorView(error)
            } else if let aiFeedData = aiFeedService.aiFeedData {
                topicsGrid(aiFeedData.reportsArray)
            } else {
                // Check if user has completed preferences but has no data yet (first time)
                if authService.userProfile?.hasCompletedNewsPreferences == true {
                    firstTimeEmptyStateView
            } else {
                emptyStateView
            }
        }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 30) {
            // Custom loading animation
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        .frame(width: 60 + CGFloat(index * 20), height: 60 + CGFloat(index * 20))
                        .scaleEffect(aiFeedService.isLoading ? 1.1 : 0.9)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: aiFeedService.isLoading
                        )
                }
                
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text("Crafting Your News")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Our AI is analyzing the latest stories just for you")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 80)
        .padding(.horizontal, 24)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            // Error icon with animation
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 12) {
                Text("Oops! Something went wrong")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(error)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button(action: {
                Task { 
                    loggingService.logRefreshTriggered(context: "error_retry")
                    await refreshData() 
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            // Animated empty state icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: true)
            }
            
            VStack(spacing: 16) {
                Text("Ready to Begin?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Let's create your first personalized news briefing with the power of AI")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button(action: {
                Task {
                    loggingService.logRefreshTriggered(context: "empty_state_generate")
                    guard let userId = authService.user?.uid else { return }
                    await aiFeedService.generateCompleteReport(userId: userId)
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                    Text("Generate My Briefing")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
        }
        .padding(.vertical, 80)
        .padding(.horizontal, 24)
    }
    
    private var firstTimeLoadingView: some View {
        VStack(spacing: 30) {
            // Enhanced loading animation for first-time users
            ZStack {
                // Animated rings
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.4, green: 0.2, blue: 0.7),
                                    Color(red: 0.3, green: 0.15, blue: 0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 80 + CGFloat(index * 20), height: 80 + CGFloat(index * 20))
                        .scaleEffect(updateService.isUpdating ? 1.1 : 0.9)
                        .opacity(0.6 - Double(index) * 0.1)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                            value: updateService.isUpdating
                        )
                }
                
                // Central icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.4, green: 0.2, blue: 0.7).opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.7))
                        .scaleEffect(updateService.isUpdating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: updateService.isUpdating
                        )
                }
            }
            
            VStack(spacing: 12) {
                Text("Preparing Your First Update")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    Text("We're analyzing your preferences and generating")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                
                    Text("your personalized news briefing...")
                        .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
                
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color(red: 0.4, green: 0.2, blue: 0.7))
                            .frame(width: 8, height: 8)
                            .scaleEffect(updateService.isUpdating ? 1.0 : 0.5)
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: updateService.isUpdating
                            )
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 80)
        .padding(.horizontal, 24)
    }
    
    private var firstTimeEmptyStateView: some View {
        VStack(spacing: 30) {
            // Animated icon for first-time empty state
            ZStack {
                Circle()
                    .fill(Color(red: 0.4, green: 0.2, blue: 0.7).opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.7))
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: true)
            }
            
            VStack(spacing: 16) {
                Text("Your Update is Being Prepared")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    Text("We're working on your first personalized briefing.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("This usually takes a few minutes. Check back soon!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            }
            
            Button(action: {
                Task {
                    loggingService.logRefreshTriggered(context: "first_time_check_updates")
                    guard let userId = authService.user?.uid else { return }
                    await aiFeedService.generateCompleteReport(userId: userId)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                    Text("Check for Updates")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.4, green: 0.2, blue: 0.7),
                            Color(red: 0.3, green: 0.15, blue: 0.5)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                    .clipShape(Capsule())
                .shadow(color: Color(red: 0.4, green: 0.2, blue: 0.7).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(aiFeedService.isLoading)
        }
        .padding(.vertical, 60)
            .padding(.horizontal, 24)
    }
            
    private func topicsGrid(_ topics: [TopicReport]) -> some View {
        LazyVStack(spacing: 20) {
            // Topics
            ForEach(Array(topics.enumerated()), id: \.element.topicName) { index, topic in
                ElegantTopicCard(topic: topic, index: index) {
                    selectedTopic = topic
                }
                .padding(.horizontal, 24)
            }
            
            // Bottom spacing
            Rectangle()
                .fill(Color.clear)
                .frame(height: 100)
        }
    }
    
    private var settingsSheet: some View {
        SettingsSheet(
            onRefreshArticles: {
                loggingService.logRefreshTriggered(context: "settings_refresh")
                Task { await refreshData() }
            },
            onUpdatePreferences: {
                loggingService.logPreferencesOpened()
                showSettings = false // Dismiss settings first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPreferences = true // Then show preferences
                }
            }
        )
    }
    
    private var backgroundSavingOverlay: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Loading card
            VStack(spacing: 20) {
                // Animated saving icon
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(authService.isSavingPreferencesInBackground ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: authService.isSavingPreferencesInBackground)
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Saving Your Preferences")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Your settings are being updated in the background")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: authService.isSavingPreferencesInBackground)
    }
    
    
    // MARK: - Helper Methods
    
    private func getCurrentGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    private func getPersonalizedGreeting() -> String {
        let timeGreeting = getCurrentGreeting()
        
        if let userProfile = authService.userProfile,
           !userProfile.firstName.isEmpty {
            return "\(timeGreeting) \(userProfile.firstName)"
        } else {
            return timeGreeting
        }
    }
    
    private func refreshData() async {
        guard let userId = authService.user?.uid else { return }
        await aiFeedService.refreshArticles(userId: userId)
        
        // Also reload user's podcast
        await loadUserPodcast()
        
        // Reload scheduling preferences
        await loadSchedulingPreferences()
    }
    
    private func loadInitialData() async {
        guard let userId = authService.user?.uid else { return }
        await aiFeedService.fetchAIFeedReports(userId: userId)
        
        // Load scheduling preferences
        await loadSchedulingPreferences()
    }
    
    private func loadSchedulingPreferences() async {
        guard let userId = authService.user?.uid else {
            print("❌ No user ID available for scheduling preferences")
            return
        }
        
        do {
            print("📅 Loading scheduling preferences from Firebase for user: \(userId)")
            
            let db = Firestore.firestore()
            let scheduleDoc = try await db.collection("scheduling_preferences").document(userId).getDocument()
            
            if scheduleDoc.exists, let data = scheduleDoc.data() {
                await MainActor.run {
                    schedulingType = data["type"] as? String ?? "daily"
                    schedulingTime = data["local_time"] as? String ?? "09:00"
                    schedulingDay = data["day"] as? String ?? "Monday"
                    isLoadingSchedule = false
                    
                    // Calculate next update time
                    calculateNextUpdateTime()
                }
                
                print("✅ Loaded scheduling: type=\(schedulingType), local_time=\(schedulingTime), day=\(schedulingDay)")
            } else {
                print("📄 No scheduling preferences found, using defaults")
                await MainActor.run {
                    schedulingType = "daily"
                    schedulingTime = "09:00"
                    schedulingDay = "Monday"
                    isLoadingSchedule = false
                    calculateNextUpdateTime()
                }
            }
        } catch {
            print("❌ Error loading scheduling preferences: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingSchedule = false
                nextUpdateTimeString = "Unable to calculate"
            }
        }
    }
    
    private func calculateNextUpdateTime() {
        let calendar = Calendar.current
        let now = Date()
        
        // Parse the time string (format: "HH:mm")
        let timeComponents = schedulingTime.split(separator: ":").compactMap { Int($0) }
        guard timeComponents.count == 2 else {
            nextUpdateTimeString = "Invalid time format"
            return
        }
        
        let hour = timeComponents[0]
        let minute = timeComponents[1]
        
        var nextUpdate: Date?
        
        if schedulingType == "daily" {
            // Calculate next daily update
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.second = 0
            
            if let todayUpdate = calendar.date(from: dateComponents) {
                if todayUpdate > now {
                    // Today's update hasn't happened yet
                    nextUpdate = todayUpdate
                } else {
                    // Today's update already passed, next one is tomorrow
                    nextUpdate = calendar.date(byAdding: .day, value: 1, to: todayUpdate)
                }
            }
        } else if schedulingType == "weekly" {
            // Calculate next weekly update
            let weekdays = ["Sunday": 1, "Monday": 2, "Tuesday": 3, "Wednesday": 4, "Thursday": 5, "Friday": 6, "Saturday": 7]
            guard let targetWeekday = weekdays[schedulingDay] else {
                nextUpdateTimeString = "Invalid day"
                return
            }
            
            let currentWeekday = calendar.component(.weekday, from: now)
            var daysToAdd = targetWeekday - currentWeekday
            
            if daysToAdd < 0 {
                daysToAdd += 7 // Next week
            } else if daysToAdd == 0 {
                // Same day, check if time has passed
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
                dateComponents.hour = hour
                dateComponents.minute = minute
                dateComponents.second = 0
                
                if let todayUpdate = calendar.date(from: dateComponents), todayUpdate <= now {
                    daysToAdd = 7 // Next week
                }
            }
            
            if let targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: now) {
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                dateComponents.hour = hour
                dateComponents.minute = minute
                dateComponents.second = 0
                nextUpdate = calendar.date(from: dateComponents)
            }
        }
        
        // Calculate time remaining
        if let nextUpdate = nextUpdate {
            let timeInterval = nextUpdate.timeIntervalSince(now)
            nextUpdateTimeString = formatTimeRemaining(timeInterval)
        } else {
            nextUpdateTimeString = "Unable to calculate"
        }
    }
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        if timeInterval <= 0 {
            return "Now"
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        
        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            if remainingHours == 0 {
                return "\(days) day\(days == 1 ? "" : "s")"
            } else {
                return "\(days) day\(days == 1 ? "" : "s"), \(remainingHours)h"
            }
        } else if hours > 0 {
            if minutes == 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                return "\(hours)h \(minutes)m"
            }
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
    
    private func loadUserPodcast() async {
        guard let userId = authService.user?.uid else { 
            print("❌ No user ID available for podcast loading")
            return 
        }
        
        do {
            print("🎵 Loading user podcast from Firebase for user: \(userId)")
            
            let db = Firestore.firestore()
            let audioDoc = try await db.collection("audio").document(userId).getDocument()
            
            if audioDoc.exists, let data = audioDoc.data() {
                if let podcastUrl = data["latest_podcast_url"] as? String, !podcastUrl.isEmpty {
                    print("✅ Found podcast URL: \(podcastUrl)")
                    
                    // Load the podcast in the audio player
                    await MainActor.run {
                        audioPlayerService.playAudio(from: podcastUrl)
                    }
                    
                    // Log additional podcast metadata if available
                    if let createdAt = data["latest_podcast_created"] as? String {
                        print("📅 Podcast created at: \(createdAt)")
                    }
                    if let presenterName = data["presenter_name"] as? String {
                        print("🎤 Presenter: \(presenterName)")
                    }
                    if let language = data["language"] as? String {
                        print("🌍 Language: \(language)")
                    }
                } else {
                    print("📭 No podcast URL found for user")
                    // NE PAS générer automatiquement - juste laisser vide
                }
            } else {
                print("📄 No audio document found for user")
                // NE PAS générer automatiquement - juste laisser vide
            }
        } catch {
            print("❌ Error loading user podcast: \(error.localizedDescription)")
        }
    }
    
    private func getUserPodcastTitle() -> String {
        if let userProfile = authService.userProfile,
           !userProfile.firstName.isEmpty {
            return "\(userProfile.firstName)'s Daily Briefing"
        } else {
            return "Your Daily Briefing"
        }
    }
}

// MARK: - Elegant Topic Card
struct ElegantTopicCard: View {
    let topic: TopicReport
    let index: Int
    let onSelect: () -> Void
    @State private var isPressed = false
    
    // Get consistent thumbnails - always use first two available, sorted for consistency
    private var firstThumbnail: String? {
        let thumbnails = topic.articleThumbnails.sorted() // Sort to ensure consistency
        return thumbnails.isEmpty ? nil : thumbnails.first
    }
    
    private var secondThumbnail: String? {
        let thumbnails = topic.articleThumbnails.sorted() // Sort to ensure consistency
        return thumbnails.count > 1 ? thumbnails[1] : thumbnails.first
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
                onSelect()
            }
        }) {
            VStack(spacing: 0) {
                // Main content card
                HStack(spacing: 0) {
                    // Left side - text content
                VStack(alignment: .leading, spacing: 18) {
                        // Header section with icon and title
                    HStack(spacing: 14) {
                        // Enhanced topic icon with modern design (smaller size)
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: getVibrantIconColors(for: topic)),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .shadow(color: getVibrantIconColors(for: topic)[0].opacity(0.4), radius: 8, x: 0, y: 4)
                                .overlay(
                                    // Subtle inner highlight
                                    Circle()
                                        .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.clear
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                    )
                                        .frame(width: 44, height: 44)
                                )
                            
                            Image(systemName: topic.colorTheme.iconName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                        
                        // Title and subtopic count
                        VStack(alignment: .leading, spacing: 6) {
                            Text(topic.displayTitle)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            // Subtopic count with modern badge design
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(getVibrantIconColors(for: topic)[0])
                                Text("\(topic.subtopics.count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(getVibrantIconColors(for: topic)[0])
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(getVibrantIconColors(for: topic)[0].opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(getVibrantIconColors(for: topic)[0].opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                        }
                        
                        Spacer(minLength: 0)
                    }
                    
                    // Enhanced pickup line section with better typography
                    VStack(alignment: .leading, spacing: 0) {
                        MarkdownText(
                            cleanPickupLine(topic.pickupLine),
                            font: .system(size: 15, weight: .medium),
                            color: .primary.opacity(0.85),
                            lineLimit: 3,
                            alignment: .leading
                        )
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right side - dual images with diagonal split
                    if let firstUrl = firstThumbnail, !firstUrl.isEmpty {
                        dualImageView(firstUrl: firstUrl)
                            .frame(width: 120)
                            .clipped()
                    } else {
                        // Fallback when no thumbnails available
                        gradientFallback(topic: topic)
                            .frame(width: 120)
                            .overlay(
                                Image(systemName: topic.colorTheme.iconName)
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            )
                    }
                }
                .background(
                    ZStack {
                        // Main card background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        
                            // Subtle gradient overlay for depth
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                        .init(color: topic.colorTheme.primaryColor.hexColor.opacity(0.03), location: 0),
                                        .init(color: topic.colorTheme.secondaryColor.hexColor.opacity(0.015), location: 1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        
                        // Top corner accent
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: 60, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 40))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: getVibrantIconColors(for: topic)),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.08)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        // Card border
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                        getVibrantIconColors(for: topic)[0].opacity(0.12),
                                        getVibrantIconColors(for: topic)[1].opacity(0.06)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .shadow(color: getVibrantIconColors(for: topic)[0].opacity(0.06), radius: 16, x: 0, y: 4)
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .shadow(color: isPressed ? .clear : .black.opacity(0.02), radius: isPressed ? 4 : 12, x: 0, y: isPressed ? 1 : 6)
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Helper function for gradient fallback
    private func gradientFallback(topic: TopicReport, opacity: Double = 1.0) -> some View {
        LinearGradient(
            gradient: Gradient(colors: [
                topic.colorTheme.primaryColor.hexColor.opacity(0.6 * opacity),
                topic.colorTheme.secondaryColor.hexColor.opacity(0.4 * opacity)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Helper function to clean pickup line from quotes
    private func cleanPickupLine(_ text: String) -> String {
        var cleaned = text
        // Remove quotes from beginning and end
        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        if cleaned.hasPrefix("'") && cleaned.hasSuffix("'") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        return cleaned
    }
    
    // Helper function to generate vibrant icon colors based on topic
    private func getVibrantIconColors(for topic: TopicReport) -> [Color] {
        let topicName = topic.displayTitle.lowercased()
        
        // Beautiful darker vibrant color schemes similar to personalization themes
        if topicName.contains("technology") || topicName.contains("tech") {
            return [Color(red: 0.1, green: 0.2, blue: 0.8), Color(red: 0.0, green: 0.4, blue: 0.7)]
        } else if topicName.contains("business") || topicName.contains("finance") || topicName.contains("economy") {
            return [Color(red: 0.8, green: 0.4, blue: 0.1), Color(red: 0.9, green: 0.2, blue: 0.2)]
        } else if topicName.contains("health") || topicName.contains("medical") {
            return [Color(red: 0.1, green: 0.6, blue: 0.3), Color(red: 0.0, green: 0.7, blue: 0.4)]
        } else if topicName.contains("science") || topicName.contains("research") {
            return [Color(red: 0.5, green: 0.2, blue: 0.7), Color(red: 0.3, green: 0.2, blue: 0.8)]
        } else if topicName.contains("sports") || topicName.contains("football") || topicName.contains("basketball") {
            return [Color(red: 0.8, green: 0.3, blue: 0.1), Color(red: 0.7, green: 0.4, blue: 0.0)]
        } else if topicName.contains("entertainment") || topicName.contains("movie") || topicName.contains("music") {
            return [Color(red: 0.7, green: 0.1, blue: 0.5), Color(red: 0.6, green: 0.2, blue: 0.7)]
        } else if topicName.contains("world") || topicName.contains("international") || topicName.contains("global") {
            return [Color(red: 0.0, green: 0.5, blue: 0.6), Color(red: 0.1, green: 0.3, blue: 0.7)]
        } else if topicName.contains("politics") || topicName.contains("government") || topicName.contains("nation") {
            return [Color(red: 0.5, green: 0.1, blue: 0.3), Color(red: 0.6, green: 0.2, blue: 0.1)]
        } else {
            // Default darker vibrant gradient for unknown topics
            return [Color(red: 0.2, green: 0.4, blue: 0.7), Color(red: 0.3, green: 0.2, blue: 0.6)]
        }
    }
    
    private func dualImageView(firstUrl: String) -> some View {
        GeometryReader { geometry in
            ZStack {
                // First image (top-left triangle)
                AsyncImage(url: URL(string: firstUrl)) { phase in
                    switch phase {
                    case .empty:
                        gradientFallback(topic: topic)
                    .overlay(
                                ProgressView()
                                    .tint(.white.opacity(0.8))
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    case .failure(_):
                        gradientFallback(topic: topic)
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(DiagonalTopShape())
                
                // Second image (bottom-right triangle)
                secondImageView(geometry: geometry)
                
                // Diagonal separator line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.3))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.7))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                
                // Subtle gradient overlay
                                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: Color.black.opacity(0.05), location: 0.7),
                        .init(color: Color.black.opacity(0.15), location: 1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    private func secondImageView(geometry: GeometryProxy) -> some View {
        Group {
            if let secondUrl = secondThumbnail, !secondUrl.isEmpty {
                if secondUrl != firstThumbnail {
                    // Different image available
                    AsyncImage(url: URL(string: secondUrl)) { phase in
                        switch phase {
                        case .empty:
                            gradientFallback(topic: topic, opacity: 0.7)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        case .failure(_):
                            gradientFallback(topic: topic, opacity: 0.7)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // Same image - show with different treatment (darker overlay)
                    AsyncImage(url: URL(string: secondUrl)) { phase in
                        switch phase {
                        case .empty:
                            gradientFallback(topic: topic, opacity: 0.7)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .overlay(
                                    Color.black.opacity(0.2) // Darker overlay for distinction
                                )
                        case .failure(_):
                            gradientFallback(topic: topic, opacity: 0.7)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            } else {
                // No image available - show gradient fallback
                gradientFallback(topic: topic, opacity: 0.8)
            }
        }
        .clipShape(DiagonalBottomShape())
    }
}

// MARK: - Custom Shapes for Diagonal Split
struct DiagonalTopShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.7))
        path.addLine(to: CGPoint(x: 0, y: rect.height * 0.3))
        path.closeSubpath()
        return path
    }
}

struct DiagonalBottomShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.7))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Floating Particle
struct FloatingParticle: View {
    let index: Int
    let accentColor: Color
    @State private var position = CGPoint.zero
    @State private var opacity: Double = 0
    
    var body: some View {
        Circle()
            .fill(accentColor.opacity(opacity))
            .frame(width: CGFloat.random(in: 2...6), height: CGFloat.random(in: 2...6))
            .position(position)
            .onAppear {
                startAnimation()
            }
    }
    
    private func startAnimation() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        position = CGPoint(
            x: CGFloat.random(in: 0...screenWidth),
            y: screenHeight + 50
        )
        
        withAnimation(
            .linear(duration: Double.random(in: 8...15))
            .repeatForever(autoreverses: false)
        ) {
            position.y = -50
            position.x += CGFloat.random(in: -100...100)
        }
        
        withAnimation(
            .easeInOut(duration: 2)
            .repeatForever(autoreverses: true)
            .delay(Double.random(in: 0...2))
        ) {
            opacity = Double.random(in: 0.1...0.3)
        }
    }
}

// MARK: - Blur View
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Scroll Offset Preference
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Extensions
extension View {
    func backdrop<T: View>(_ content: T) -> some View {
        overlay(content)
    }
}

// MARK: - Settings Sheet
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    let onRefreshArticles: () -> Void
    let onUpdatePreferences: () -> Void
    @State private var showPersonalization = false
    @State private var showSignOutAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // User Profile Section
                    if let userProfile = authService.userProfile {
                        userProfileSection(userProfile)
                    }
                    
                    // News Actions Section
                    newsActionsSection
                    
                    // Personalization Section
                    personalizationSection
                    
                    // Account Actions Section
                    accountActionsSection
                    
                    // Bottom spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
            .sheet(isPresented: $showPersonalization) {
                PersonalizationView()
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out of your account?")
            }
        }
    }
    
    private func userProfileSection(_ profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            // Profile header
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.4, green: 0.2, blue: 0.7),
                                Color(red: 0.6, green: 0.3, blue: 0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(profile.firstName.prefix(1).uppercased())
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(profile.firstName)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let email = authService.user?.email {
                        Text(email)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    private var newsActionsSection: some View {
        VStack(spacing: 12) {
            sectionHeader("News & Updates")
            
            modernButton(
                title: "Update Preferences",
                subtitle: "Modify your news topics",
                icon: "slider.horizontal.3",
                action: {
                    onUpdatePreferences()
                }
            )
        }
    }
    
    private var personalizationSection: some View {
        VStack(spacing: 12) {
            sectionHeader("Appearance")
            
            modernButton(
                title: "Personalize Theme",
                subtitle: "Customize colors and style",
                icon: "paintbrush.fill",
                action: {
                    showPersonalization = true
                }
            )
        }
    }
    
    private var accountActionsSection: some View {
        VStack(spacing: 12) {
            sectionHeader("Account")
            
            modernButton(
                title: "Sign Out",
                subtitle: "Log out of your account",
                icon: "rectangle.portrait.and.arrow.right",
                isDestructive: true,
                        action: { 
                    showSignOutAlert = true
                }
            )
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
        }
    }
    
    private func modernButton(
        title: String,
        subtitle: String,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDestructive ? .red : Color(red: 0.4, green: 0.2, blue: 0.7))
                    .frame(width: 24, height: 24)
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDestructive ? .red : .primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Modern Audio Player
struct ModernAudioPlayer: View {
    @ObservedObject private var audioPlayerService = AudioPlayerService.shared
    @State private var isDraggingSlider = false
    @State private var draggedProgress: Double = 0
    @State private var isControlsPressed = false
    @State private var pressedControl: String = ""
    let podcastTitle: String
    
    private var progress: Double {
        guard audioPlayerService.duration > 0 else { return 0 }
        return audioPlayerService.currentTime / audioPlayerService.duration
    }
    
    var body: some View {
        if audioPlayerService.isPlayerAvailable || audioPlayerService.isPlaying {
            // Audio available - show full player
            enhancedAudioPlayerView
        } else {
            // No audio available - show elegant waiting state
            elegantNoAudioView
        }
    }
    
    private var enhancedAudioPlayerView: some View {
        HStack(spacing: 16) {
            // Enhanced album artwork - smaller
            ZStack {
                // Glow background
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 3,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)
                
                // Main artwork container
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.25), location: 0),
                                .init(color: Color.white.opacity(0.15), location: 0.5),
                                .init(color: Color.white.opacity(0.1), location: 1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        // Glass effect border
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        // Audio icon with pulse animation
                        Image("orel_logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .foregroundColor(.white.opacity(0.9))
                            .scaleEffect(audioPlayerService.isPlaying ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: audioPlayerService.isPlaying)
                    )
                    .shadow(color: .white.opacity(0.2), radius: 6, x: 0, y: 2)
            }
            
            // Track info and progress - middle section
            VStack(alignment: .leading, spacing: 6) {
                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(podcastTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("AI Generated Podcast")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                // Compact progress bar
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Track background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 4)
                            
                            // Progress fill
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.9))
                                    .frame(
                                        width: geometry.size.width * (isDraggingSlider ? draggedProgress : progress),
                                        height: 4
                                    )
                                Spacer(minLength: 0)
                            }
                            .animation(.linear(duration: 0.1), value: progress)
                            
                            // Draggable thumb
                            Circle()
                                .fill(Color.white)
                                .frame(width: isDraggingSlider ? 12 : 8, height: isDraggingSlider ? 12 : 8)
                                .offset(x: (geometry.size.width * (isDraggingSlider ? draggedProgress : progress)) - 4)
                                .opacity(isDraggingSlider || audioPlayerService.duration > 0 ? 1 : 0)
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingSlider = true
                                    draggedProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                                }
                                .onEnded { value in
                                    let newProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                                    let seekTime = newProgress * audioPlayerService.duration
                                    audioPlayerService.seek(to: seekTime)
                                    isDraggingSlider = false
                                }
                        )
                    }
                    .frame(height: 4)
                    
                    // Compact time labels
                    HStack {
                        Text(formatTime(audioPlayerService.currentTime))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Text(formatTime(audioPlayerService.duration))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .monospacedDigit()
                    }
                }
            }
            
            // Compact controls on the right
            HStack(spacing: 8) {
                // Skip backward - smaller
                Button(action: { audioPlayerService.skipBackward(15.0) }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!audioPlayerService.isPlayerAvailable)
                .opacity(audioPlayerService.isPlayerAvailable ? 1.0 : 0.6)
                
                // Main play/pause button - smaller
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        audioPlayerService.togglePlayPause()
                    }
                }) {
                    ZStack {
                        // Main button background
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.15)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            .shadow(color: .white.opacity(0.2), radius: 6, x: 0, y: 2)
                        
                        // Play/pause icon
                        Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: audioPlayerService.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(audioPlayerService.isPlaying ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioPlayerService.isPlaying)
                
                // Skip forward - smaller
                Button(action: { audioPlayerService.skipForward(15.0) }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!audioPlayerService.isPlayerAvailable)
                .opacity(audioPlayerService.isPlayerAvailable ? 1.0 : 0.6)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            // Glass morphism background
            ZStack {
                // Base background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.black.opacity(0.15), location: 0),
                                .init(color: Color.black.opacity(0.1), location: 0.5),
                                .init(color: Color.black.opacity(0.2), location: 1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                // Inner highlight
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 6)
    }
    
    private var elegantNoAudioView: some View {
        HStack(spacing: 18) {
            // Enhanced waiting state icon
            ZStack {
                // Pulsing background rings
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1 - Double(index) * 0.02), lineWidth: 1)
                        .frame(width: 54 + CGFloat(index * 8), height: 54 + CGFloat(index * 8))
                        .scaleEffect(1.0 + Double(index) * 0.1)
                        .animation(
                            .easeInOut(duration: 2.0 + Double(index) * 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                            value: true
                        )
                }
                
                // Main container
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.15), location: 0),
                                .init(color: Color.white.opacity(0.08), location: 1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .rotationEffect(.degrees(0))
                            .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: true)
                    )
                    .shadow(color: .white.opacity(0.1), radius: 8, x: 0, y: 2)
            }
            
            // Enhanced message content
            VStack(alignment: .leading, spacing: 6) {
                Text("Preparing Your Briefing")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    // Animated dots
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.white.opacity(0.6))
                                .frame(width: 4, height: 4)
                                .scaleEffect(1.0)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: true
                                )
                        }
                    }
                    
                    Text("Your podcast will be ready soon")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Status indicator
            VStack(spacing: 4) {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: true)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(
            // Elegant glass background for waiting state
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.black.opacity(0.1), location: 0),
                                .init(color: Color.black.opacity(0.05), location: 0.5),
                                .init(color: Color.black.opacity(0.15), location: 1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
        )
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    ModernDashboardView()
        .environmentObject(AuthService.shared)
        .environmentObject(LanguageManager())
} 
