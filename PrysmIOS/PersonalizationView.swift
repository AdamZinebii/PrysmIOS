import SwiftUI

// MARK: - Color Theme Models
struct ColorTheme: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color
    let gradientColors: [Color]
    let particleColor: Color
    let backgroundType: BackgroundType
    
    enum BackgroundType {
        case gradient
        case radial
        case angular
    }
}

extension ColorTheme {
    static let themes: [ColorTheme] = [
        ColorTheme(
            name: "Deep Ocean",
            primaryColor: Color(red: 0.1, green: 0.2, blue: 0.4),
            secondaryColor: Color(red: 0.0, green: 0.3, blue: 0.5),
            accentColor: Color(red: 0.2, green: 0.4, blue: 0.6),
            gradientColors: [
                Color(red: 0.0, green: 0.1, blue: 0.3),
                Color(red: 0.1, green: 0.2, blue: 0.4),
                Color(red: 0.0, green: 0.3, blue: 0.5)
            ],
            particleColor: Color(red: 0.3, green: 0.5, blue: 0.7),
            backgroundType: .gradient
        ),
        ColorTheme(
            name: "Dark Ember",
            primaryColor: Color(red: 0.4, green: 0.1, blue: 0.0),
            secondaryColor: Color(red: 0.5, green: 0.2, blue: 0.1),
            accentColor: Color(red: 0.6, green: 0.3, blue: 0.1),
            gradientColors: [
                Color(red: 0.3, green: 0.0, blue: 0.0),
                Color(red: 0.4, green: 0.1, blue: 0.0),
                Color(red: 0.5, green: 0.2, blue: 0.1)
            ],
            particleColor: Color(red: 0.7, green: 0.4, blue: 0.2),
            backgroundType: .radial
        ),
        ColorTheme(
            name: "Forest Shadow",
            primaryColor: Color(red: 0.1, green: 0.3, blue: 0.1),
            secondaryColor: Color(red: 0.2, green: 0.4, blue: 0.2),
            accentColor: Color(red: 0.1, green: 0.5, blue: 0.2),
            gradientColors: [
                Color(red: 0.0, green: 0.2, blue: 0.1),
                Color(red: 0.1, green: 0.3, blue: 0.1),
                Color(red: 0.2, green: 0.4, blue: 0.2)
            ],
            particleColor: Color(red: 0.3, green: 0.6, blue: 0.3),
            backgroundType: .gradient
        ),
        ColorTheme(
            name: "Violet Night",
            primaryColor: Color(red: 0.3, green: 0.1, blue: 0.4),
            secondaryColor: Color(red: 0.4, green: 0.2, blue: 0.5),
            accentColor: Color(red: 0.5, green: 0.3, blue: 0.6),
            gradientColors: [
                Color(red: 0.2, green: 0.0, blue: 0.3),
                Color(red: 0.3, green: 0.1, blue: 0.4),
                Color(red: 0.4, green: 0.2, blue: 0.5)
            ],
            particleColor: Color(red: 0.6, green: 0.4, blue: 0.7),
            backgroundType: .angular
        ),
        ColorTheme(
            name: "Burgundy Depths",
            primaryColor: Color(red: 0.4, green: 0.1, blue: 0.2),
            secondaryColor: Color(red: 0.5, green: 0.2, blue: 0.3),
            accentColor: Color(red: 0.6, green: 0.3, blue: 0.4),
            gradientColors: [
                Color(red: 0.3, green: 0.0, blue: 0.1),
                Color(red: 0.4, green: 0.1, blue: 0.2),
                Color(red: 0.5, green: 0.2, blue: 0.3)
            ],
            particleColor: Color(red: 0.7, green: 0.4, blue: 0.5),
            backgroundType: .radial
        ),
        ColorTheme(
            name: "Midnight Steel",
            primaryColor: Color(red: 0.1, green: 0.1, blue: 0.2),
            secondaryColor: Color(red: 0.2, green: 0.2, blue: 0.3),
            accentColor: Color(red: 0.3, green: 0.3, blue: 0.4),
            gradientColors: [
                Color(red: 0.0, green: 0.0, blue: 0.1),
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.2, green: 0.2, blue: 0.3)
            ],
            particleColor: Color(red: 0.4, green: 0.4, blue: 0.5),
            backgroundType: .gradient
        )
    ]
}

struct PersonalizationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedTheme: ColorTheme = ColorTheme.themes[0]
    @State private var animationOffset: CGFloat = 0
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // White background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header with floating animation
                        headerView
                        
                        // Color theme selection grid
                        themeSelectionGrid
                        
                        // Preview section (nouvel aperçu)
                        previewSection
                        
                        // Apply button
                        applyButton
                        
                        // Reset button
                        resetButton
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Personalization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        applyTheme()
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            startHeaderAnimation()
            // Initialize with current theme if one is applied
            if let currentCustomTheme = themeManager.customColorTheme {
                // Find the matching ColorTheme for the current custom theme
                if let matchingTheme = ColorTheme.themes.first(where: { theme in
                    theme.gradientColors == currentCustomTheme.gradientColors &&
                    theme.particleColor == currentCustomTheme.particleColor
                }) {
                    selectedTheme = matchingTheme
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            // Mini aperçu de la page principale
            ZStack {
                // Background avec le thème sélectionné
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: selectedTheme.gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .overlay(
                        // Particules miniatures
                        ForEach(0..<8, id: \.self) { index in
                            Circle()
                                .fill(selectedTheme.particleColor.opacity(0.4))
                                .frame(width: 3, height: 3)
                                .position(
                                    x: CGFloat.random(in: 20...300),
                                    y: CGFloat.random(in: 20...180)
                                )
                                .animation(
                                    .easeInOut(duration: Double.random(in: 2...4))
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.3),
                                    value: selectedTheme.id
                                )
                        }
                    )
                
                VStack(spacing: 12) {
                    // Header simulé
                    HStack {
                        Text("Good Night")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 28, height: 28)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    // Zone blanche simulée
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.95))
                        .frame(height: 100)
                        .overlay(
                            VStack(spacing: 8) {
                                HStack {
                                    Circle()
                                        .fill(selectedTheme.primaryColor)
                                        .frame(width: 20, height: 20)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.gray.opacity(0.7))
                                            .frame(width: 80, height: 8)
                                        
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.gray.opacity(0.4))
                                            .frame(width: 60, height: 6)
                                    }
                                    
                                    Spacer()
                                }
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 40)
                            }
                            .padding(12)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .animation(.easeInOut(duration: 0.8), value: selectedTheme.id)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .scaleEffect(1.0 + sin(animationOffset) * 0.05)
                
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.primary)
                    .rotationEffect(.degrees(animationOffset * 0.5))
            }
            
            VStack(spacing: 8) {
                Text("Personalize Your Experience")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Choose your perfect color theme")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 40)
    }
    
    private var themeSelectionGrid: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Color Themes")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(ColorTheme.themes) { theme in
                    ThemeCard(
                        theme: theme,
                        isSelected: selectedTheme.id == theme.id,
                        onSelect: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                selectedTheme = theme
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var applyButton: some View {
        Button(action: {
            applyTheme()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("Apply Theme")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                selectedTheme.primaryColor,
                                selectedTheme.secondaryColor
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: selectedTheme.primaryColor.opacity(0.4), radius: 10, x: 0, y: 5)
            )
        }
        .padding(.horizontal, 20)
    }
    
    private var resetButton: some View {
        Button(action: {
            resetTheme()
        }) {
            Text("Reset to Default")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Methods
    
    private func startHeaderAnimation() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
    
    private func applyTheme() {
        print("🎨 PersonalizationView: Applying theme: \(selectedTheme.name)")
        
        // Convert ColorTheme to CustomColorTheme
        let customTheme = CustomColorTheme(
            gradientColors: selectedTheme.gradientColors,
            particleColor: selectedTheme.particleColor,
            primaryColor: selectedTheme.primaryColor,
            secondaryColor: selectedTheme.secondaryColor,
            accentColor: selectedTheme.accentColor
        )
        
        print("🎨 PersonalizationView: Custom theme created with \(customTheme.gradientColors.count) gradient colors")
        
        // Apply the theme to the theme manager
        themeManager.applyCustomTheme(customTheme)
        
        print("🎨 PersonalizationView: Theme applied to ThemeManager")
    }
    
    private func resetTheme() {
        print("🎨 PersonalizationView: Resetting theme to default")
        
        // Reset to the default theme
        selectedTheme = ColorTheme.themes[0]
        themeManager.resetToDefaultTheme()
        
        print("🎨 PersonalizationView: Theme reset completed")
    }
}

// MARK: - Theme Card
struct ThemeCard: View {
    let theme: ColorTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            onSelect()
        }) {
            VStack(spacing: 12) {
                // Color preview with clean gradient design
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: theme.gradientColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 100)
                        .overlay(
                            // Mini floating particles
                            ForEach(0..<5, id: \.self) { index in
                                Circle()
                                    .fill(theme.particleColor.opacity(0.6))
                                    .frame(width: 4, height: 4)
                                    .position(
                                        x: CGFloat.random(in: 20...120),
                                        y: CGFloat.random(in: 20...80)
                                    )
                                    .animation(
                                        .easeInOut(duration: Double.random(in: 2...4))
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                        value: isSelected
                                    )
                            }
                        )
                        .shadow(color: theme.primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    // Selection indicator
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.primaryColor, lineWidth: 3)
                        
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(theme.primaryColor)
                                            .frame(width: 32, height: 32)
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                            .padding(8)
                            Spacer()
                        }
                    }
                }
                
                // Theme name
                Text(theme.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isSelected)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
        }
    }
}

#Preview {
    PersonalizationView()
        .environmentObject(ThemeManager())
} 