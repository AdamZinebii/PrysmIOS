import SwiftUI

struct SubtopicDetailView: View {
    let subtopicName: String
    let subtopicReport: SubtopicReport
    let topicTheme: TopicColorTheme
    
    @State private var showRedditSheet = false
    @Environment(\.dismiss) private var dismiss
    
    // Logging service
    @StateObject private var loggingService = LoggingService.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Hero section
                SubtopicHeroSection(
                    name: subtopicName,
                    theme: topicTheme
                )
                .padding(.horizontal)
                
                // Summary content
                SubtopicContentSection(
                    summary: subtopicReport.subtopicSummary,
                    theme: topicTheme
                )
                .padding(.horizontal)
                
                // Reddit reactions bar (if available)
                if subtopicReport.hasRedditContent {
                    RedditReactionsBar(
                        theme: topicTheme,
                        onTap: {
                            showRedditSheet = true
                            // Log reddit summary view
                            loggingService.logRedditSummaryViewed(
                                subtopicName: subtopicName,
                                parentTopic: nil // Could be enhanced to track parent topic
                            )
                        }
                    )
                    .padding(.horizontal)
                }
                
                // Spacer for bottom sheet
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
        .navigationTitle(subtopicName.capitalized)
        .navigationBarTitleDisplayMode(.large)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    topicTheme.primaryColor.hexColor.opacity(0.03)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showRedditSheet) {
            RedditReactionsSheet(
                subtopicName: subtopicName,
                redditSummary: subtopicReport.redditSummary,
                theme: topicTheme
            )
        }
    }
}

// MARK: - Hero Section
struct SubtopicHeroSection: View {
    let name: String
    let theme: TopicColorTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Subtopic icon (derived from theme)
                Image(systemName: getSubtopicIcon(for: name))
                    .font(.largeTitle)
                    .foregroundColor(theme.primaryColor.hexColor)
                
                Spacer()
                
                // Category badge
                Text("Subtopic")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.primaryColor.hexColor)
                    .clipShape(Capsule())
            }
            
            Text(name.capitalized)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    theme.primaryColor.hexColor.opacity(0.3),
                                    theme.secondaryColor.hexColor.opacity(0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func getSubtopicIcon(for name: String) -> String {
        let lowercaseName = name.lowercased()
        
        switch lowercaseName {
        case let x where x.contains("ai") || x.contains("artificial"):
            return "brain"
        case let x where x.contains("finance") || x.contains("money"):
            return "dollarsign.circle"
        case let x where x.contains("startup"):
            return "lightbulb"
        case let x where x.contains("crypto"):
            return "bitcoinsign.circle"
        case let x where x.contains("health"):
            return "heart"
        case let x where x.contains("climate") || x.contains("environment"):
            return "leaf"
        case let x where x.contains("space"):
            return "globe"
        case let x where x.contains("energy"):
            return "bolt"
        default:
            return "doc.text"
        }
    }
}

// MARK: - Content Section
struct SubtopicContentSection: View {
    let summary: String
    let theme: TopicColorTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarkdownText(
                summary,
                font: .system(size: 16, weight: .regular),
                color: .primary,
                lineLimit: nil,
                alignment: .leading
            )
            .padding(.vertical, 4)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    theme.primaryColor.hexColor.opacity(0.2),
                                    theme.secondaryColor.hexColor.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: theme.primaryColor.hexColor.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Reddit Reactions Bar
struct RedditReactionsBar: View {
    let theme: TopicColorTheme
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Reddit logo
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.orange)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reactions on")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Reddit")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Pulse animation
                Circle()
                    .fill(theme.primaryColor.hexColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPressed ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPressed)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            isPressed = true
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Reddit Reactions Sheet
struct RedditReactionsSheet: View {
    let subtopicName: String
    let redditSummary: String
    let theme: TopicColorTheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    RedditSheetHeader(subtopicName: subtopicName, theme: theme)
                        .padding(.horizontal)
                    
                    // Reddit summary content
                    RedditSummaryContent(summary: redditSummary)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Reddit Reactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color.orange.opacity(0.05)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Reddit Sheet Header
struct RedditSheetHeader: View {
    let subtopicName: String
    let theme: TopicColorTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color.orange)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Community Reactions")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(subtopicName.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Reddit Summary Content
struct RedditSummaryContent: View {
    let summary: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What Reddit is saying")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                MarkdownText(
                    summary,
                    font: .body,
                    color: .primary,
                    lineLimit: nil,
                    alignment: .leading
                )
                .padding(.vertical, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    NavigationView {
        SubtopicDetailView(
            subtopicName: "Artificial Intelligence",
            subtopicReport: SubtopicReport(
                subtopicSummary: "**Artificial Intelligence Overview**\n\nKey developments in AI technology and industry trends. Major breakthroughs in machine learning and neural networks are reshaping the technology landscape.",
                redditSummary: "**Key Developments:**\n• AI breakthrough in machine learning\n• Industry adoption accelerating\n• Concerns about job displacement growing"
            ),
            topicTheme: TopicColorTheme.theme(for: "technology")
        )
    }
} 