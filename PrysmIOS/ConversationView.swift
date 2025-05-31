import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ConversationView: View {
    @Binding var preferences: UserPreferences
    @Binding var isPresented: Bool
    
    @State private var conversationMessages: [ConversationMessage] = []
    @State private var userInput = ""
    @State private var isAITyping = false
    @State private var hasStarted = false
    @State private var preferencesUploaded = false
    @State private var showingNewsView = false
    @State private var showingConversationEnd = false
    @State private var showingPreferences = false
    @StateObject private var conversationService = ConversationService.shared
    
    // Timer for polling specific subjects from database
    @State private var subjectsPollingTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top section - Specific Subjects (1/4 of screen)
                specificSubjectsSection
                    .frame(height: geometry.size.height * 0.25)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.1),
                                Color.purple.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Bottom section - Conversation (3/4 of screen)
                conversationSection
                    .frame(height: geometry.size.height * 0.75)
                    .background(Color(UIColor.systemBackground))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !hasStarted {
                uploadPreferencesAndStartConversation()
                startSubjectsPolling()
                hasStarted = true
            }
        }
        .onDisappear {
            stopSubjectsPolling()
        }
        .sheet(isPresented: $showingNewsView) {
            Text("News Feed Coming Soon!")
                .font(.title)
                .padding()
        }
        .fullScreenCover(isPresented: $showingConversationEnd) {
            ConversationEndView(
                onContinueConversation: {
                    showingConversationEnd = false
                    // Continue the conversation - no action needed, just dismiss
                },
                onScheduleNews: {
                    showingConversationEnd = false
                    showingPreferences = true
                }
            )
        }
        .fullScreenCover(isPresented: $showingPreferences) {
            PreferencesView(isPresented: $showingPreferences, startAtScheduling: true)
        }
    }
    
    // MARK: - Specific Subjects Section
    private var specificSubjectsSection: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Button(action: { isPresented = false }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                        Text("Back")
                            .font(.body)
                    }
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("AI Discovery")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isAITyping ? Color.orange : Color.green)
                            .frame(width: 6, height: 6)
                        
                        Text(isAITyping ? "Analyzing..." : "Active")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Settings button
                Button(action: {}) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Specific subjects display
            if conversationService.specificSubjects.isEmpty {
                emptySubjectsView
            } else {
                populatedSubjectsView
            }
            
            Spacer()
        }
    }
    
    private var emptySubjectsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundColor(.blue.opacity(0.6))
            
            Text("AI is learning your interests...")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Start chatting to discover personalized topics")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
    
    private var populatedSubjectsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text("Discovered Interests")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(conversationService.specificSubjects.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(conversationService.specificSubjects.enumerated()), id: \.offset) { index, subject in
                        SubjectBubbleView(
                            subject: subject,
                            index: index,
                            total: conversationService.specificSubjects.count
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.horizontal, 20)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: conversationService.specificSubjects)
        }
    }
    
    // MARK: - Conversation Section
    private var conversationSection: some View {
        VStack(spacing: 0) {
            // Conversation area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Welcome message
                        if conversationMessages.isEmpty && !isAITyping {
                            welcomeCard
                                .padding(.top, 20)
                        }
                        
                        // Messages
                        ForEach(conversationMessages) { message in
                            ModernMessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        // Typing indicator
                        if isAITyping {
                            ModernTypingIndicator()
                                .id("typing")
                        }
                        
                        // Bottom padding
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
                .onChange(of: conversationMessages.count) { _ in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        if let lastMessage = conversationMessages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isAITyping) { typing in
                    if typing {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area
            modernInputView
        }
    }
    
    // MARK: - Welcome Card
    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Assistant")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Ready to personalize your news")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text("I'll analyze our conversation to discover your specific interests and create a personalized news feed just for you.")
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            if !preferences.selectedCategories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your selected topics:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(preferences.selectedCategories, id: \.self) { category in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text(category)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Modern Input View
    private var modernInputView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            HStack(spacing: 12) {
                // Input field
                HStack {
                    TextField(getPlaceholderText(), text: $userInput, axis: .vertical)
                        .font(.body)
                        .lineLimit(1...4)
                        .disabled(isAITyping)
                    
                    if !userInput.isEmpty {
                        Button(action: { userInput = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.body)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(20)
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(canSendMessage ? Color.blue : Color.gray)
                        )
                }
                .disabled(!canSendMessage)
                .scaleEffect(canSendMessage ? 1.0 : 0.8)
                .animation(.spring(response: 0.3), value: canSendMessage)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Computed Properties
    private var canSendMessage: Bool {
        !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAITyping
    }
    
    // MARK: - Helper Functions
    private func getPlaceholderText() -> String {
        let languageCode = getLanguageCode(from: preferences.language)
        switch languageCode {
        case "fr":
            return "Parlez-moi de vos intérêts..."
        case "es":
            return "Háblame de tus intereses..."
        case "ar":
            return "أخبرني عن اهتماماتك..."
        default:
            return "Tell me about your interests..."
        }
    }
    
    private func getLanguageCode(from language: String) -> String {
        switch language {
        case "English": return "en"
        case "Français": return "fr"
        case "Español": return "es"
        case "العربية": return "ar"
        default: return "en"
        }
    }
    
    // MARK: - Subjects Polling
    private func startSubjectsPolling() {
        subjectsPollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            pollSpecificSubjectsFromDatabase()
        }
    }
    
    private func stopSubjectsPolling() {
        subjectsPollingTimer?.invalidate()
        subjectsPollingTimer = nil
    }
    
    private func pollSpecificSubjectsFromDatabase() {
        guard conversationService.currentUserId != nil else { return }
        
        conversationService.pollSpecificSubjects { result in
            switch result {
            case .success(let response):
                if response.success {
                    // Update subjects if new ones are found
                    let currentSubjects = Set(conversationService.specificSubjects)
                    let newSubjects = Set(response.totalSubjects)
                    
                    let addedSubjects = newSubjects.subtracting(currentSubjects)
                    
                    for subject in addedSubjects {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            conversationService.specificSubjects.append(subject)
                        }
                    }
                }
            case .failure(let error):
                print("Failed to poll specific subjects: \(error)")
            }
        }
    }
    
    // MARK: - Actions
    private func uploadPreferencesAndStartConversation() {
        // Utiliser l'userId Firebase Auth au lieu de générer un UUID temporaire
        guard let firebaseUserId = AuthService.shared.user?.uid else {
            print("Error: No Firebase user ID available")
            // Fallback: générer un UUID temporaire seulement si pas d'utilisateur Firebase
        conversationService.currentUserId = UUID().uuidString
            print("Using temporary user ID for session: \(conversationService.currentUserId ?? "unknown")")
            startConversation()
            return
        }
        
        // Utiliser l'userId Firebase réel
        conversationService.currentUserId = firebaseUserId
        print("Using Firebase user ID for session: \(conversationService.currentUserId ?? "unknown")")
        
        // Start conversation directly with current preferences
        startConversation()
    }
    
    private func startConversation() {
        isAITyping = true
        let conversationPreferences = preferences.toConversationPreferences()
        
        conversationService.startConversation(with: conversationPreferences) { result in
            self.isAITyping = false
            
            switch result {
            case .success(let response):
                if response.success, let aiMessage = response.aiMessage {
                    self.conversationMessages.append(ConversationMessage(
                        id: UUID(),
                        content: aiMessage,
                        isFromUser: false,
                        timestamp: Date()
                    ))
                    
                    if response.readyForNews {
                        self.handleConversationEnd()
                    }
                    
                    if let usage = response.usage {
                        print("Tokens used: \(usage.totalTokens)")
                    }
                } else {
                    self.addFallbackMessage()
                }
                
            case .failure(let error):
                print("Conversation error: \(error)")
                self.addFallbackMessage()
            }
        }
    }
    
    private func sendMessage() {
        let message = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        conversationMessages.append(ConversationMessage(
            id: UUID(),
            content: message,
            isFromUser: true,
            timestamp: Date()
        ))
        
        userInput = ""
        isAITyping = true
        
        let conversationPreferences = preferences.toConversationPreferences()
        let request = ConversationRequest(
            userId: conversationService.currentUserId,
            userPreferences: conversationPreferences,
            conversationHistory: conversationMessages,
            userMessage: message
        )
        
        conversationService.continueConversation(with: request) { result in
            self.isAITyping = false
            
            switch result {
            case .success(let response):
                if response.success, let aiMessage = response.aiMessage {
                    self.conversationMessages.append(ConversationMessage(
                        id: UUID(),
                        content: aiMessage,
                        isFromUser: false,
                        timestamp: Date()
                    ))
                    
                    if response.readyForNews {
                        self.handleConversationEnd()
                    }
                    
                    // The backend now handles specific subjects discovery
                    // No need for local simulation
                    
                    if let usage = response.usage {
                        print("Tokens used: \(usage.totalTokens)")
                    }
                } else {
                    self.addFallbackMessage()
                }
                
            case .failure(let error):
                print("Conversation error: \(error)")
                self.addFallbackMessage()
            }
        }
    }
    
    private func handleConversationEnd() {
        // Save all preferences (topics, subtopics, and specific subjects) at the end
        let conversationPreferences = preferences.toConversationPreferences()
        
        conversationService.saveAllPreferencesAtEnd(conversationPreferences) { result in
            switch result {
            case .success(let response):
                if response.success {
                    print("All preferences saved successfully at conversation end")
                } else {
                    print("Failed to save preferences at end: \(response.error ?? "unknown error")")
                }
            case .failure(let error):
                print("Error saving preferences at end: \(error)")
            }
        }
        
        // Show conversation end view instead of directly going to news feed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showingConversationEnd = true
        }
    }
    
    private func handleFinalCompletion() {
        // This is called when user completes daily scheduling or chooses to go to news feed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showingNewsView = true
        }
    }
    
    private func addFallbackMessage() {
        let languageCode = getLanguageCode(from: preferences.language)
        let fallbackMessage: String
        
        switch languageCode {
        case "fr":
            fallbackMessage = "Désolé, je rencontre des difficultés techniques. Pouvez-vous réessayer ?"
        case "es":
            fallbackMessage = "Lo siento, estoy experimentando dificultades técnicas. ¿Puedes intentar de nuevo?"
        case "ar":
            fallbackMessage = "آسف، أواجه صعوبات تقنية. هل يمكنك المحاولة مرة أخرى؟"
        default:
            fallbackMessage = "Sorry, I'm experiencing technical difficulties. Can you try again?"
        }
        
        conversationMessages.append(ConversationMessage(
            id: UUID(),
            content: fallbackMessage,
            isFromUser: false,
            timestamp: Date()
        ))
    }
}

// MARK: - Subject Bubble View
struct SubjectBubbleView: View {
    let subject: String
    let index: Int
    let total: Int
    
    private var bubbleColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .indigo]
        return colors[index % colors.count]
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(subject)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    bubbleColor,
                                    bubbleColor.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: bubbleColor.opacity(0.3), radius: 4, x: 0, y: 2)
                )
            
            // Small indicator dot
            Circle()
                .fill(bubbleColor.opacity(0.6))
                .frame(width: 4, height: 4)
        }
    }
}

// MARK: - Modern Message Bubble
struct ModernMessageBubble: View {
    let message: ConversationMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.isFromUser {
                Spacer(minLength: 60)
            } else {
                // AI Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 6) {
                MarkdownText(
                    message.content,
                    font: .body,
                    color: message.isFromUser ? .white : .primary,
                    lineLimit: nil,
                    alignment: .leading
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            message.isFromUser
                            ? LinearGradient(
                                gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(UIColor.secondarySystemBackground),
                                    Color(UIColor.tertiarySystemBackground)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !message.isFromUser {
                Spacer(minLength: 60)
            } else {
                // User Avatar
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Modern Typing Indicator
struct ModernTypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // AI Avatar
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 8, height: 8)
                            .offset(y: animationOffset)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: animationOffset
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                
                Text("AI is thinking...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animationOffset = -4
        }
    }
}

// MARK: - Preview
struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationView(
            preferences: .constant(UserPreferences()),
            isPresented: .constant(true)
        )
    }
} 