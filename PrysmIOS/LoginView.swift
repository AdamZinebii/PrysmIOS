import SwiftUI
import AuthenticationServices 
import CryptoKit // For SHA256

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var isEmailMode = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()
            
            // Subtle floating particles animation
            ForEach(0..<6, id: \.self) { index in
                FloatingAuthParticle(index: index)
            }
            
            ScrollView {
                VStack(spacing: 0) {
                    // Top spacer - smaller when in email mode
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: isEmailMode ? 40 : 80)
                    
                    // Logo and welcome text section
                    VStack(spacing: isEmailMode ? 20 : 30) {
                        // Logo with subtle violet glow effect - larger size
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.4, green: 0.2, blue: 0.7).opacity(0.1))
                                .frame(width: isEmailMode ? 140 : 180, height: isEmailMode ? 140 : 180)
                                .blur(radius: 15)
                            
                            Circle()
                                .fill(Color(red: 0.3, green: 0.15, blue: 0.5).opacity(0.05))
                                .frame(width: isEmailMode ? 120 : 150, height: isEmailMode ? 120 : 150)
                            
                            // Your custom Orel logo - increased size
                            Image("orel_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: isEmailMode ? 100 : 120, height: isEmailMode ? 100 : 120)
                        }
                        
                        // Welcome text - only show when not in email mode
                        if !isEmailMode {
                            Text("Welcome to Orel")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                        }
                    }
                    .padding(.bottom, isEmailMode ? 50 : 80)
                    
                    // Main card container
                    VStack(spacing: 0) {
                        if !isEmailMode {
                            // Social login mode
                            socialLoginSection
                        } else {
                            // Email login mode
                            emailLoginSection
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isEmailMode)
            
            // Loading overlay
            if isLoading {
                loadingOverlay
            }
        }
        .navigationBarHidden(true)
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    // MARK: - Social Login Section
    private var socialLoginSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                // Google Sign-In Button
                Button(action: handleGoogleSignIn) {
                    HStack(spacing: 12) {
                        // Google Logo
                        Image("google_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        
                        Text("Continue with Google")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(red: 0.9, green: 0.9, blue: 0.95), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Apple Sign-In Button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        let rawNonce = randomNonceString()
                        authService.setCurrentNonce(rawNonce)
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(rawNonce)
                    },
                    onCompletion: { result in
                        handleAppleSignInResult(result)
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                
                // Email option with violet accent
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isEmailMode = true
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.7))
                        
                        Text("Continue with Email")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.7))
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.7))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.4, green: 0.2, blue: 0.7).opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(red: 0.4, green: 0.2, blue: 0.7).opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Error message
            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Email Login Section
    private var emailLoginSection: some View {
        VStack(spacing: 24) {
            // Header with back button
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isEmailMode = false
                        email = ""
                        password = ""
                        authService.errorMessage = nil
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                        Text("Back")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.7))
                }
                
                Spacer()
            }
            
            VStack(spacing: 20) {
                // Email field
                ModernTextField(
                    text: $email,
                    placeholder: "Email address",
                    icon: "envelope",
                    keyboardType: .emailAddress
                )
                
                // Password field
                ModernSecureField(
                    text: $password,
                    placeholder: "Password",
                    icon: "lock"
                )
                
                // Main action button with violet gradient
                Button(action: handleEmailAuth) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(showingSignUp ? "Create Account" : "Sign In")
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
                                        Color(red: 0.4, green: 0.2, blue: 0.7),
                                        Color(red: 0.3, green: 0.15, blue: 0.5)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color(red: 0.4, green: 0.2, blue: 0.7).opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isLoading || email.isEmpty || password.isEmpty ? 0.98 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLoading)
                
                // Toggle sign up/in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingSignUp.toggle()
                        authService.errorMessage = nil
                    }
                }) {
                    Text(showingSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.7))
                }
                .padding(.top, 8)
            }
            
            // Error message
            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.4, green: 0.2, blue: 0.7)))
                    .scaleEffect(1.2)
                
                Text("Signing you in...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
        }
    }
    
    // MARK: - Helper Functions
    private func handleGoogleSignIn() {
        isLoading = true
        
        guard let rootViewController = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.windows
            .filter({$0.isKeyWindow}).first?.rootViewController else {
                authService.errorMessage = "Cannot find root view controller for Google Sign-In."
                isLoading = false
                return
            }
        
        authService.signInWithGoogle(presentingViewController: rootViewController)
        
        // Reset loading state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
        }
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        
        switch result {
        case .success(let authorization):
            authService.handleAppleSignIn(authorization: authorization)
        case .failure(let error):
            authService.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
        }
        
        // Reset loading state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
        }
    }
    
    private func handleEmailAuth() {
        guard !email.isEmpty, !password.isEmpty else { return }
        
        isLoading = true
        
        if showingSignUp {
            authService.signUpWithEmail(email: email, password: password)
        } else {
            authService.signInWithEmail(email: email, password: password)
        }
        
        // Reset loading state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isLoading = false
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // Nonce helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Modern Text Field
struct ModernTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isFocused ? Color(red: 0.4, green: 0.2, blue: 0.7) : Color(red: 0.6, green: 0.6, blue: 0.7))
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .textContentType(keyboardType == .emailAddress ? .emailAddress : .none)
                .focused($isFocused)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isFocused ? Color(red: 0.4, green: 0.2, blue: 0.7) : Color(red: 0.9, green: 0.9, blue: 0.95), lineWidth: isFocused ? 2 : 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Modern Secure Field
struct ModernSecureField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    @State private var isSecured = true
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isFocused ? Color(red: 0.4, green: 0.2, blue: 0.7) : Color(red: 0.6, green: 0.6, blue: 0.7))
                .frame(width: 20)
            
            Group {
                if isSecured {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(size: 16))
            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
            .textContentType(.password)
            .focused($isFocused)
            
            Button(action: {
                isSecured.toggle()
            }) {
                Image(systemName: isSecured ? "eye.slash" : "eye")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isFocused ? Color(red: 0.4, green: 0.2, blue: 0.7) : Color(red: 0.9, green: 0.9, blue: 0.95), lineWidth: isFocused ? 2 : 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Floating Particle Animation
struct FloatingAuthParticle: View {
    let index: Int
    @State private var position = CGPoint.zero
    @State private var opacity: Double = 0
    
    var body: some View {
        Circle()
            .fill(Color(red: 0.4, green: 0.2, blue: 0.7).opacity(opacity))
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
            position.x += CGFloat.random(in: -50...50)
        }
        
        withAnimation(
            .easeInOut(duration: 4)
            .repeatForever(autoreverses: true)
            .delay(Double.random(in: 0...4))
        ) {
            opacity = Double.random(in: 0.05...0.15)
        }
    }
}

// Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView().environmentObject(AuthService.shared)
    }
} 
