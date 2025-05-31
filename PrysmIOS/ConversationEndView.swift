import SwiftUI

struct ConversationEndView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.presentationMode) var presentationMode
    
    let onContinueConversation: () -> Void
    let onScheduleNews: () -> Void
    
    @State private var showAnimation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Background with gradient
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.1),
                        Color(UIColor.systemBackground)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Success Icon with Animation
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(showAnimation ? 1.0 : 0.8)
                            .opacity(showAnimation ? 1.0 : 0.0)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(showAnimation ? 1.0 : 0.5)
                            .opacity(showAnimation ? 1.0 : 0.0)
                    }
                    
                    // Title and Description
                    VStack(spacing: 16) {
                        Text(localizedString("conversation_complete"))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .opacity(showAnimation ? 1.0 : 0.0)
                        
                        Text(localizedString("conversation_complete_description"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .opacity(showAnimation ? 1.0 : 0.0)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Continue Conversation Button
                        Button(action: {
                            onContinueConversation()
                        }) {
                            HStack {
                                Image(systemName: "message.badge.waveform")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(localizedString("continue_conversation"))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Text(localizedString("refine_interests_more"))
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                        }
                        .scaleEffect(showAnimation ? 1.0 : 0.9)
                        .opacity(showAnimation ? 1.0 : 0.0)
                        
                        // Schedule News Button
                        Button(action: {
                            onScheduleNews()
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(localizedString("schedule_news"))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Text(localizedString("setup_daily_schedule"))
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.purple, .purple.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                        }
                        .scaleEffect(showAnimation ? 1.0 : 0.9)
                        .opacity(showAnimation ? 1.0 : 0.0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                showAnimation = true
            }
        }
    }
    
    private func localizedString(_ key: String) -> String {
        return languageManager.localizedString(key)
    }
}

// MARK: - Alternative Compact Version
struct ConversationEndCompactView: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    let onContinueConversation: () -> Void
    let onScheduleNews: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                Text(localizedString("great_progress"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(localizedString("what_next"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: onContinueConversation) {
                    HStack {
                        Image(systemName: "message")
                        Text(localizedString("continue_conversation"))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                    .foregroundColor(.white)
                }
                
                Button(action: onScheduleNews) {
                    HStack {
                        Image(systemName: "calendar")
                        Text(localizedString("schedule_news"))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.purple)
                    )
                    .foregroundColor(.white)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
    
    private func localizedString(_ key: String) -> String {
        return languageManager.localizedString(key)
    }
}

struct ConversationEndView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConversationEndView(
                onContinueConversation: { print("Continue conversation") },
                onScheduleNews: { print("Schedule news") }
            )
            .environmentObject(LanguageManager())
            
            ConversationEndCompactView(
                onContinueConversation: { print("Continue conversation") },
                onScheduleNews: { print("Schedule news") }
            )
            .environmentObject(LanguageManager())
            .previewDisplayName("Compact Version")
        }
    }
} 