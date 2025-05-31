import SwiftUI
import FirebaseFirestore

struct ModernDashboardView: View {
    @StateObject private var aiFeedService = AIFeedService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var newsFeedViewModel = NewsFeedViewModel()
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showSettings = false
    @State private var showPreferences = false
    @State private var selectedTopic: TopicReport?
    @State private var scrollOffset: CGFloat = 0
    
    // Audio player integration
    @ObservedObject private var audioPlayerService = AudioPlayerService.shared
    
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
                                await refreshData()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                    }
                    .padding(.bottom, -50) // Extend below the visible area
                }
                .ignoresSafeArea(.container, edges: .bottom) // Ignore bottom safe area
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
            .fullScreenCover(isPresented: $showPreferences) {
                PreferencesView(isPresented: $showPreferences)
            }
        }
        .onAppear {
            Task {
                await loadInitialData()
                // Load user's podcast from Firebase
                await loadUserPodcast()
            }
        }
        .sheet(item: $selectedTopic) { topic in
            TopicDetailView(topic: topic)
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
                        Text(getPersonalizedGreeting())
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Settings button
                    Button(action: {
                        showSettings = true
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
                
                // Modern Audio Player
                if audioPlayerService.isPlayerAvailable || audioPlayerService.isPlaying {
                    ModernAudioPlayer()
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
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
            if aiFeedService.isLoading {
                loadingView
            } else if let error = aiFeedService.error {
                errorView(error)
            } else if let aiFeedData = aiFeedService.aiFeedData {
                topicsGrid(aiFeedData.reportsArray)
            } else {
                emptyStateView
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
                Task { await refreshData() }
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
                Task { await refreshData() }
            },
            onUpdatePreferences: {
                showPreferences = true
            }
        )
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
    }
    
    private func loadInitialData() async {
        guard let userId = authService.user?.uid else { return }
        await aiFeedService.fetchAIFeedReports(userId: userId)
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
}

// MARK: - Elegant Topic Card
struct ElegantTopicCard: View {
    let topic: TopicReport
    let index: Int
    let onSelect: () -> Void
    @State private var isPressed = false
    
    // Get a random thumbnail for the card background
    private var randomThumbnail: String? {
        let thumbnails = topic.articleThumbnails
        return thumbnails.isEmpty ? nil : thumbnails.randomElement()
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
                    VStack(alignment: .leading, spacing: 20) {
                        // Header section with icon and title
                        HStack(spacing: 16) {
                            // Enhanced topic icon with modern design
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                topic.colorTheme.primaryColor.hexColor,
                                                topic.colorTheme.secondaryColor.hexColor
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)
                                    .shadow(color: topic.colorTheme.primaryColor.hexColor.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: topic.colorTheme.iconName)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            // Title and subtopic count
                            VStack(alignment: .leading, spacing: 8) {
                                Text(topic.displayTitle)
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                
                                // Subtopic count with modern badge design
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(topic.colorTheme.primaryColor.hexColor)
                                    Text("\(topic.subtopics.count)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(topic.colorTheme.primaryColor.hexColor)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(topic.colorTheme.primaryColor.hexColor.opacity(0.12))
                                )
                            }
                            
                            Spacer()
                        }
                        
                        // Enhanced pickup line section
                        VStack(alignment: .leading, spacing: 0) {
                            MarkdownText(
                                cleanPickupLine(topic.pickupLine),
                                font: .system(size: 16, weight: .medium),
                                color: .primary.opacity(0.8),
                                lineLimit: 3,
                                alignment: .leading
                            )
                        }
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right side - single random image
                    if let thumbnailUrl = randomThumbnail, !thumbnailUrl.isEmpty {
                        AsyncImage(url: URL(string: thumbnailUrl)) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                topic.colorTheme.primaryColor.hexColor.opacity(0.3),
                                                topic.colorTheme.secondaryColor.hexColor.opacity(0.2)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120)
                                    .overlay(
                                        ProgressView()
                                            .tint(.white.opacity(0.8))
                                    )
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120)
                                    .clipped()
                                    .overlay(
                                        // Gradient overlay for better text readability
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color.clear, location: 0),
                                                .init(color: Color.black.opacity(0.1), location: 0.7),
                                                .init(color: Color.black.opacity(0.3), location: 1)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            case .failure(_):
                                // Fallback gradient when image fails to load
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                topic.colorTheme.primaryColor.hexColor.opacity(0.6),
                                                topic.colorTheme.secondaryColor.hexColor.opacity(0.4)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120)
                                    .overlay(
                                        Image(systemName: topic.colorTheme.iconName)
                                            .font(.system(size: 32, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        // Fallback when no thumbnails available
                        RoundedRectangle(cornerRadius: 0)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        topic.colorTheme.primaryColor.hexColor.opacity(0.6),
                                        topic.colorTheme.secondaryColor.hexColor.opacity(0.4)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120)
                            .overlay(
                                Image(systemName: topic.colorTheme.iconName)
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            )
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .overlay(
                            // Subtle gradient overlay for depth
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: topic.colorTheme.primaryColor.hexColor.opacity(0.02), location: 0),
                                            .init(color: topic.colorTheme.secondaryColor.hexColor.opacity(0.01), location: 1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            topic.colorTheme.primaryColor.hexColor.opacity(0.15),
                                            topic.colorTheme.secondaryColor.hexColor.opacity(0.08)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
                        .shadow(color: topic.colorTheme.primaryColor.hexColor.opacity(0.08), radius: 20, x: 0, y: 8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
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
    let onRefreshArticles: () -> Void
    let onUpdatePreferences: () -> Void
    @State private var showPersonalization = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Actions") {
                    Button(action: onRefreshArticles) {
                        Label("Actualiser les Articles", systemImage: "arrow.clockwise")
                    }
                    
                    Button(action: onUpdatePreferences) {
                        Label("Mettre à Jour les Préférences", systemImage: "slider.horizontal.3")
                    }
                }
                
                Section("Personnalisation") {
                    Button(action: {
                        showPersonalization = true
                    }) {
                        Label("Personnaliser", systemImage: "paintbrush.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPersonalization) {
                PersonalizationView()
            }
        }
    }
}

// MARK: - Modern Audio Player
struct ModernAudioPlayer: View {
    @ObservedObject private var audioPlayerService = AudioPlayerService.shared
    @State private var isDraggingSlider = false
    @State private var draggedProgress: Double = 0
    
    private var progress: Double {
        guard audioPlayerService.duration > 0 else { return 0 }
        return audioPlayerService.currentTime / audioPlayerService.duration
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Track info and controls row
            HStack(spacing: 16) {
                // Album artwork placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    )
                
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Daily Briefing")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("AI Generated Podcast")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Play/Pause control
                Button(action: {
                    audioPlayerService.togglePlayPause()
                }) {
                    Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(audioPlayerService.isPlaying ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioPlayerService.isPlaying)
            }
            
            // Progress bar
            VStack(spacing: 6) {
                // Progress slider
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        // Progress fill
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(0.7)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * (isDraggingSlider ? draggedProgress : progress),
                                height: 4
                            )
                            .animation(.linear(duration: 0.1), value: progress)
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
                
                // Time labels
                HStack {
                    Text(formatTime(audioPlayerService.currentTime))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(formatTime(audioPlayerService.duration))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    Color.black.opacity(0.1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
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