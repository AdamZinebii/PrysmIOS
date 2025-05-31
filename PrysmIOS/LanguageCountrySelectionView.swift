import SwiftUI

struct LanguageCountrySelectionView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedLanguage: String = "English"
    @State private var selectedCountry: String = ""
    @State private var showCountryPicker = false
    
    let onComplete: (String, String) -> Void
    
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
    
    init(onComplete: @escaping (String, String) -> Void) {
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.top, 40)
                    
                    Text(localizedString("welcome_to_prysm"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(localizedString("setup_language_country"))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Language Selection
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "textformat")
                                    .foregroundColor(.blue)
                                Text(localizedString("select_language"))
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                                ForEach(availableLanguages, id: \.self) { language in
                                                            LanguageCard(
                            language: language,
                            isSelected: selectedLanguage == language
                        ) {
                            selectedLanguage = language
                            // Force immediate language change
                            DispatchQueue.main.async {
                                languageManager.currentLanguage = language
                            }
                        }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Country Selection
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "location")
                                    .foregroundColor(.blue)
                                Text(localizedString("select_country"))
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            Button(action: {
                                showCountryPicker = true
                            }) {
                                HStack {
                                    Text(selectedCountry.isEmpty ? localizedString("choose_country") : selectedCountry)
                                        .foregroundColor(selectedCountry.isEmpty ? .secondary : .primary)
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
                                                .stroke(selectedCountry.isEmpty ? Color.clear : Color.blue, lineWidth: 2)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
                
                // Continue Button
                VStack(spacing: 16) {
                    Button(action: {
                        onComplete(selectedLanguage, selectedCountry)
                    }) {
                        HStack {
                            Text(localizedString("continue"))
                                .font(.headline)
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .disabled(selectedCountry.isEmpty)
                        .opacity(selectedCountry.isEmpty ? 0.6 : 1.0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemBackground))
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(
                countries: countries,
                selectedCountry: $selectedCountry,
                isPresented: $showCountryPicker
            )
        }
        .onAppear {
            // Set initial language from LanguageManager
            selectedLanguage = languageManager.currentLanguage
        }
    }
    
    private func localizedString(_ key: String) -> String {
        return languageManager.localizedString(key)
    }
}

struct LanguageCard: View {
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

struct CountryPickerSheet: View {
    let countries: [String]
    @Binding var selectedCountry: String
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @EnvironmentObject var languageManager: LanguageManager
    
    private var filteredCountries: [String] {
        if searchText.isEmpty {
            return countries
        } else {
            return countries.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
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

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

struct LanguageCountrySelectionView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageCountrySelectionView { language, country in
            print("Selected: \(language), \(country)")
        }
        .environmentObject(LanguageManager())
    }
} 