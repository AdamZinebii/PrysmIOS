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
            name: "Ocean",
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
            name: "Ember",
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
            name: "Forest",
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
            name: "Violet",
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
            name: "Burgundy",
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
            name: "Steel",
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
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        headerView
                        themeSelectionGrid
                        previewSection
                        
                        VStack(spacing: 12) {
                            applyButton
                            resetButton
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Themes")
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
                    .fontWeight(.medium)
                }
            }
        }
        .onAppear {
            if let currentCustomTheme = themeManager.customColorTheme {
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
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Choose Your Theme")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Personalize your experience")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .padding(.top, 16)
    }
    
    private var themeSelectionGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(ColorTheme.themes) { theme in
                ThemeCard(
                    theme: theme,
                    isSelected: selectedTheme.id == theme.id,
                    onSelect: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTheme = theme
                        }
                    }
                )
            }
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: selectedTheme.gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)
                    .overlay(
                        ForEach(0..<6, id: \.self) { index in
                            Circle()
                                .fill(selectedTheme.particleColor.opacity(0.4))
                                .frame(width: 2, height: 2)
                                .position(
                                    x: CGFloat.random(in: 20...280),
                                    y: CGFloat.random(in: 20...120)
                                )
                        }
                    )
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Good Night")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 20, height: 20)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.95))
                        .frame(height: 60)
                        .overlay(
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(selectedTheme.primaryColor.opacity(0.8))
                                    .frame(width: 12, height: 12)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.gray.opacity(0.6))
                                        .frame(width: 60, height: 4)
                                    
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.gray.opacity(0.4))
                                        .frame(width: 40, height: 3)
                                }
                                
                                Spacer()
                            }
                            .padding(8)
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: selectedTheme.id)
        }
    }
    
    private var applyButton: some View {
        Button(action: {
            applyTheme()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .medium))
                Text("Apply")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule()
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
                    .shadow(color: selectedTheme.primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
    }
    
    private var resetButton: some View {
        Button(action: {
            resetTheme()
        }) {
            Text("Reset")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule()
                        .fill(Color(.systemGray6))
                )
        }
    }
    
    // MARK: - Helper Methods
    
    private func applyTheme() {
        print("🎨 PersonalizationView: Applying theme: \(selectedTheme.name)")
        
        let customTheme = CustomColorTheme(
            gradientColors: selectedTheme.gradientColors,
            particleColor: selectedTheme.particleColor,
            primaryColor: selectedTheme.primaryColor,
            secondaryColor: selectedTheme.secondaryColor,
            accentColor: selectedTheme.accentColor
        )
        
        print("🎨 PersonalizationView: Custom theme created with \(customTheme.gradientColors.count) gradient colors")
        
        themeManager.applyCustomTheme(customTheme)
        
        print("🎨 PersonalizationView: Theme applied to ThemeManager")
    }
    
    private func resetTheme() {
        print("🎨 PersonalizationView: Resetting theme to default")
        
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
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: theme.gradientColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)
                        .overlay(
                            ForEach(0..<4, id: \.self) { index in
                                Circle()
                                    .fill(theme.particleColor.opacity(0.5))
                                    .frame(width: 2, height: 2)
                                    .position(
                                        x: CGFloat.random(in: 15...120),
                                        y: CGFloat.random(in: 15...65)
                                    )
                            }
                        )
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.primaryColor, lineWidth: 2)
                        
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(theme.primaryColor)
                                            .frame(width: 22, height: 22)
                                    )
                            }
                            .padding(6)
                            Spacer()
                        }
                    }
                }
                
                Text(theme.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
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