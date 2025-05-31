import SwiftUI

enum ThemeMode {
    case light
    case dark
}

struct ThemeShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Custom Color Theme Support
struct CustomColorTheme {
    let gradientColors: [Color]
    let particleColor: Color
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color
}

class ThemeManager: ObservableObject {
    @Published var themeMode: ThemeMode = .dark
    @Published var customColorTheme: CustomColorTheme? {
        didSet {
            if shouldSave {
                saveCustomTheme()
            }
        }
    }
    
    // UserDefaults keys
    private let customThemeKey = "SavedCustomTheme"
    private var shouldSave = true
    
    init() {
        loadSavedTheme()
    }
    
    // MARK: - Colors
    var backgroundColor: Color {
        themeMode == .dark ? Color.black : Color(UIColor.systemBackground)
    }
    
    var cardBackgroundColor: Color {
        themeMode == .dark ? Color(UIColor.darkGray) : Color(UIColor.systemBackground)
    }
    
    var textPrimaryColor: Color {
        themeMode == .dark ? Color.white : Color.primary
    }
    
    var textSecondaryColor: Color {
        themeMode == .dark ? Color.gray : Color.secondary
    }
    
    var accentColor: Color {
        if let customTheme = customColorTheme {
            return customTheme.accentColor
        }
        return themeMode == .dark ? Color.blue : Color.blue
    }
    
    // MARK: - New Custom Theme Properties
    var backgroundGradientColors: [Color] {
        if let customTheme = customColorTheme {
            return customTheme.gradientColors
        }
        // Default gradient colors (Violet theme)
        return [
            Color(red: 0.3, green: 0.15, blue: 0.5),
            Color(red: 0.4, green: 0.2, blue: 0.7),
            Color(red: 0.5, green: 0.25, blue: 0.8)
        ]
    }
    
    var particleColor: Color {
        if let customTheme = customColorTheme {
            return customTheme.particleColor
        }
        return Color(red: 0.6, green: 0.4, blue: 0.9)
    }
    
    var dividerColor: Color {
        themeMode == .dark ? Color.gray.opacity(0.3) : Color(UIColor.systemGray4)
    }
    
    var subtopicBackgroundColor: Color {
        themeMode == .dark ? Color(UIColor.darkGray).opacity(0.5) : Color(UIColor.systemGray6)
    }
    
    // MARK: - Shadows
    var cardShadow: ThemeShadow {
        themeMode == .dark ? 
            ThemeShadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2) :
            ThemeShadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Theme Management
    func toggleTheme() {
        themeMode = themeMode == .dark ? .light : .dark
    }
    
    func applyCustomTheme(_ theme: CustomColorTheme) {
        print("🔧 ThemeManager: Applying custom theme with \(theme.gradientColors.count) gradient colors")
        withAnimation(.easeInOut(duration: 0.8)) {
            customColorTheme = theme
        }
        print("🔧 ThemeManager: Custom theme applied successfully")
    }
    
    func resetToDefaultTheme() {
        print("🔧 ThemeManager: Resetting to default theme")
        withAnimation(.easeInOut(duration: 0.8)) {
            customColorTheme = nil
        }
        print("🔧 ThemeManager: Reset to default theme completed")
    }
    
    private func saveCustomTheme() {
        guard let theme = customColorTheme else {
            UserDefaults.standard.removeObject(forKey: customThemeKey)
            print("🔧 ThemeManager: Removed saved theme")
            return
        }
        
        let themeData: [String: Any] = [
            "gradientColors": theme.gradientColors.map { colorToRGBA($0) },
            "particleColor": colorToRGBA(theme.particleColor),
            "primaryColor": colorToRGBA(theme.primaryColor),
            "secondaryColor": colorToRGBA(theme.secondaryColor),
            "accentColor": colorToRGBA(theme.accentColor)
        ]
        
        UserDefaults.standard.set(themeData, forKey: customThemeKey)
        print("🔧 ThemeManager: Saved custom theme to UserDefaults")
    }
    
    private func loadSavedTheme() {
        guard let themeData = UserDefaults.standard.dictionary(forKey: customThemeKey) else {
            print("🔧 ThemeManager: No saved theme found")
            return
        }
        
        guard let gradientColorsData = themeData["gradientColors"] as? [[String: Double]],
              let particleColorData = themeData["particleColor"] as? [String: Double],
              let primaryColorData = themeData["primaryColor"] as? [String: Double],
              let secondaryColorData = themeData["secondaryColor"] as? [String: Double],
              let accentColorData = themeData["accentColor"] as? [String: Double] else {
            print("🔧 ThemeManager: Invalid saved theme data")
            return
        }
        
        let gradientColors = gradientColorsData.compactMap { rgbaToColor($0) }
        guard let particleColor = rgbaToColor(particleColorData),
              let primaryColor = rgbaToColor(primaryColorData),
              let secondaryColor = rgbaToColor(secondaryColorData),
              let accentColor = rgbaToColor(accentColorData) else {
            print("🔧 ThemeManager: Failed to convert saved colors")
            return
        }
        
        let theme = CustomColorTheme(
            gradientColors: gradientColors,
            particleColor: particleColor,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            accentColor: accentColor
        )
        
        // Disable saving while loading
        shouldSave = false
        customColorTheme = theme
        shouldSave = true
        print("🔧 ThemeManager: Loaded saved custom theme")
    }
    
    private func colorToRGBA(_ color: Color) -> [String: Double] {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return [
            "red": Double(red),
            "green": Double(green),
            "blue": Double(blue),
            "alpha": Double(alpha)
        ]
    }
    
    private func rgbaToColor(_ rgba: [String: Double]) -> Color? {
        guard let red = rgba["red"],
              let green = rgba["green"],
              let blue = rgba["blue"],
              let alpha = rgba["alpha"] else {
            return nil
        }
        
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
} 