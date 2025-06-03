import SwiftUI

struct TopicDetailView: View {
    let topic: TopicReport
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSubtopic: SubtopicWrapper?
    
    // Logging service
    @StateObject private var loggingService = LoggingService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Enhanced header with just icon and subtitle info
                    topicHeader
                    
                    // Enhanced pickup line section
                    pickupLineSection
                    
                    // Enhanced topic summary section
                    topicSummarySection
                    
                    // Subtopics (clickable)
                    if !topic.subtopics.isEmpty {
                        subtopicsSection
                    }
                    
                    // Bottom spacing
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(topic.displayTitle)
            .navigationBarTitleDisplayMode(.large)
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
                        topic.colorTheme.primaryColor.hexColor.opacity(0.02)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .sheet(item: $selectedSubtopic) { wrapper in
            SubtopicDetailView(
                subtopicName: wrapper.name,
                subtopicReport: wrapper.report,
                topicTheme: topic.colorTheme
            )
            .onAppear {
                // Log subtopic summary view
                loggingService.logSubtopicSummaryViewed(
                    subtopicName: wrapper.name,
                    parentTopic: topic.displayTitle
                )
            }
        }
    }
    
    // MARK: - View Components
    
    private var topicHeader: some View {
        HStack(spacing: 16) {
            // Enhanced topic icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
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
                    .frame(width: 70, height: 70)
                    .shadow(color: topic.colorTheme.primaryColor.hexColor.opacity(0.3), radius: 12, x: 0, y: 6)
                
                Image(systemName: topic.colorTheme.iconName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Metadata only (title is in navigation bar)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14))
                            .foregroundColor(topic.colorTheme.primaryColor.hexColor)
                        Text("\(topic.subtopics.count) subtopics")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(topic.colorTheme.primaryColor.hexColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(topic.colorTheme.primaryColor.hexColor.opacity(0.1))
                    )
                }
                
                Text("Updated recently")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
    
    private var pickupLineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 18))
                    .foregroundColor(topic.colorTheme.primaryColor.hexColor)
                
                Text("Key Insight")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            MarkdownText(
                cleanPickupLine(topic.pickupLine),
                font: .system(size: 18, weight: .medium),
                color: .primary,
                lineLimit: nil,
                alignment: .leading
            )
            .padding(.leading, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    topic.colorTheme.primaryColor.hexColor.opacity(0.3),
                                    topic.colorTheme.secondaryColor.hexColor.opacity(0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: topic.colorTheme.primaryColor.hexColor.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var topicSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.plaintext.fill")
                    .font(.system(size: 18))
                    .foregroundColor(topic.colorTheme.primaryColor.hexColor)
                
                Text("Detailed Summary")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            MarkdownText(
                topic.topicSummary,
                font: .system(size: 16, weight: .regular),
                color: .primary,
                lineLimit: nil,
                alignment: .leading
            )
            .padding(.leading, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var subtopicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(topic.colorTheme.primaryColor.hexColor)
                
                Text("Explore Subtopics")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(topic.subtopics.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(topic.colorTheme.primaryColor.hexColor)
                    )
            }
            
            LazyVStack(spacing: 12) {
                ForEach(topic.subtopicsArray, id: \.0) { subtopicName, subtopicReport in
                    SubtopicCard(
                        name: subtopicName,
                        report: subtopicReport,
                        theme: topic.colorTheme,
                        onTap: {
                            selectedSubtopic = SubtopicWrapper(name: subtopicName, report: subtopicReport)
                        }
                    )
                }
            }
        }
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

// MARK: - Supporting Views

struct SubtopicCard: View {
    let name: String
    let report: SubtopicReport
    let theme: TopicColorTheme
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Simple haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Animation feedback
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }
            
            // Call the actual action
            onTap()
            
            // Reset animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
        }) {
            HStack(spacing: 18) {
                // Enhanced subtopic icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    theme.primaryColor.hexColor,
                                    theme.secondaryColor.hexColor
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: theme.primaryColor.hexColor.opacity(0.3), radius: 6, x: 0, y: 3)
                    
                    Image(systemName: getSubtopicIcon(for: name))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(name.capitalized)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        if report.hasRedditContent {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                Text("Reddit insights")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.1))
                            )
                        }
                        
                        Text("Tap to explore")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Enhanced arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryColor.hexColor)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(theme.primaryColor.hexColor.opacity(0.1))
                    )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        theme.primaryColor.hexColor.opacity(0.3),
                                        theme.secondaryColor.hexColor.opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: theme.primaryColor.hexColor.opacity(0.1), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
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
        case let x where x.contains("market") || x.contains("business"):
            return "chart.line.uptrend.xyaxis"
        case let x where x.contains("security") || x.contains("privacy"):
            return "shield.fill"
        case let x where x.contains("mobile") || x.contains("app"):
            return "iphone"
        case let x where x.contains("social") || x.contains("media"):
            return "person.2.fill"
        default:
            return "doc.text.fill"
        }
    }
}

// Wrapper for sheet presentation
struct SubtopicWrapper: Identifiable {
    let id = UUID()
    let name: String
    let report: SubtopicReport
}

#Preview {
    NavigationView {
        TopicDetailView(topic: TopicReport(
            topicName: "technology",
            pickupLine: "🚨 Breaking: AI revolution is reshaping tech as major companies announce groundbreaking developments that could change everything.",
            topicSummary: "# TECHNOLOGY BRIEFING\n\n🔥 **TOP HEADLINES**\n• Major AI breakthrough announced\n• Tech stocks surge amid innovation\n\n📊 **SUBTOPIC INSIGHTS**\n**Artificial Intelligence**\n• Revolutionary AI model released\n• Industry leaders respond positively",
            subtopics: [
                "AI": SubtopicReport(
                    subtopicSummary: "**Artificial Intelligence Overview**\n\nKey developments in AI technology and industry trends.",
                    redditSummary: "**Key Developments:**\n• AI breakthrough in machine learning\n• Industry adoption accelerating"
                ),
                "Startups": SubtopicReport(
                    subtopicSummary: "**Startup Ecosystem**\n\nEmerging companies and funding trends in technology.",
                    redditSummary: "**Startup Trends:**\n• Record funding rounds\n• New unicorn companies emerging"
                )
            ],
            generationStats: nil
        ))
    }
} 