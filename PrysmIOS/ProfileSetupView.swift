import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var firstName: String = ""
    @State private var surname: String = ""
    @State private var ageString: String = ""
    @State private var isSaving: Bool = false
    @State private var localErrorMessage: String? = nil
    @State private var currentStep: Int = 0
    
    private let totalSteps = 3

    var body: some View {
        ZStack {
            // Purple violet gradient background matching LoginView
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.1, blue: 0.4),    // Dark purple
                    Color(red: 0.4, green: 0.2, blue: 0.7),    // Medium purple
                    Color(red: 0.3, green: 0.15, blue: 0.5)    // Purple blend
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating particles animation
            ForEach(0..<6, id: \.self) { index in
                FloatingProfileParticle(index: index)
            }
            
            ScrollView {
                VStack(spacing: 0) {
                    // Top spacer
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 40)
                    
                    // Header section
                    VStack(spacing: 24) {
                        // Progress indicator
                        HStack(spacing: 8) {
                            ForEach(0..<totalSteps, id: \.self) { step in
                                Circle()
                                    .fill(step <= currentStep ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: 10, height: 10)
                                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                            }
                        }
                        .padding(.bottom, 10)
                        
                        // Welcome section
                        VStack(spacing: 16) {
                            Text("Complete Your Profile")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Help us personalize your experience")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 40)
                    
                    // Form container
                    VStack(spacing: 24) {
                        stepContent
                        
                        // Error messages
                        if let localErrorMessage = localErrorMessage {
                            Text(localErrorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        if let authErrorMessage = authService.errorMessage {
                            Text(authErrorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Action buttons
                        VStack(spacing: 16) {
                            // Main action button
                            Button(action: handleMainAction) {
                                HStack {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    
                                    Text(getMainButtonText())
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 0.5, green: 0.3, blue: 0.8),
                                                    Color(red: 0.4, green: 0.2, blue: 0.7)
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .shadow(color: Color(red: 0.5, green: 0.3, blue: 0.8).opacity(0.3), radius: 8, x: 0, y: 4)
                                )
                            }
                            .disabled(isSaving || !canProceed)
                            .buttonStyle(PlainButtonStyle())
                            .scaleEffect(isSaving || !canProceed ? 0.98 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSaving)
                            
                            // Back button (if not on first step)
                            if currentStep > 0 {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentStep -= 1
                                    }
                                }) {
                                    Text("Back")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.white.opacity(0.05))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            // Pre-fill form if editing existing profile
            if let profile = authService.userProfile {
                firstName = profile.firstName
                surname = profile.surname
                if let age = profile.age {
                    ageString = "\(age)"
                }
            }
            authService.errorMessage = nil
        }
    }
    
    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            firstNameStep
        case 1:
            surnameStep
        case 2:
            ageStep
        default:
            EmptyView()
        }
    }
    
    private var firstNameStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("What's your first name?")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("We'll use this to personalize your experience")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            ProfileTextField(
                text: $firstName,
                placeholder: "Enter your first name",
                icon: "person"
            )
        }
    }
    
    private var surnameStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("And your last name?")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("This helps us create your complete profile")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            ProfileTextField(
                text: $surname,
                placeholder: "Enter your last name",
                icon: "person.badge.plus"
            )
        }
    }
    
    private var ageStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("How old are you?")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("This is optional but helps us curate better content")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            ProfileTextField(
                text: $ageString,
                placeholder: "Enter your age (optional)",
                icon: "calendar",
                keyboardType: .numberPad
            )
            
            // Skip option
            Button(action: {
                ageString = ""
                saveProfile()
            }) {
                Text("Skip for now")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .underline()
            }
        }
    }
    
    // MARK: - Helper Properties
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            return !surname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2:
            return true // Age is optional
        default:
            return false
        }
    }
    
    // MARK: - Helper Functions
    private func getMainButtonText() -> String {
        if isSaving {
            return "Saving..."
        }
        
        switch currentStep {
        case 0, 1:
            return "Continue"
        case 2:
            return "Complete Setup"
        default:
            return "Continue"
        }
    }
    
    private func handleMainAction() {
        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        } else {
            saveProfile()
        }
    }
    
    private func saveProfile() {
        localErrorMessage = nil
        authService.errorMessage = nil
        isSaving = true
        
        guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            localErrorMessage = "First name cannot be empty."
            isSaving = false
            return
        }
        guard !surname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            localErrorMessage = "Last name cannot be empty."
            isSaving = false
            return
        }
        
        var age: Int? = nil
        if !ageString.isEmpty {
            if let parsedAge = Int(ageString), parsedAge > 0 && parsedAge < 120 {
                age = parsedAge
            } else {
                localErrorMessage = "Please enter a valid age."
                isSaving = false
                return
            }
        }
        
        // Save profile with basic information only
        authService.updateUserProfile(
            firstName: firstName,
            surname: surname,
            age: age
        )
        
        // Set flag to show preferences flow after profile is saved
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSaving = false
            // Trigger preferences flow
            authService.shouldShowNewsPreferences = true
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Modern Text Field (Profile Version)
struct ProfileTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .textContentType(keyboardType == .emailAddress ? .emailAddress : .none)
                .focused($isFocused)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isFocused ? 0.15 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(isFocused ? 0.4 : 0.2), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Floating Particle Animation (Profile Version)
struct FloatingProfileParticle: View {
    let index: Int
    @State private var position = CGPoint.zero
    @State private var opacity: Double = 0
    
    var body: some View {
        Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3))
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
            .linear(duration: Double.random(in: 20...30))
            .repeatForever(autoreverses: false)
        ) {
            position.y = -50
            position.x += CGFloat.random(in: -80...80)
        }
        
        withAnimation(
            .easeInOut(duration: 4)
            .repeatForever(autoreverses: true)
            .delay(Double.random(in: 0...4))
        ) {
            opacity = Double.random(in: 0.05...0.2)
        }
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView()
            .environmentObject(AuthService.shared)
            .environmentObject(LanguageManager())
    }
} 
