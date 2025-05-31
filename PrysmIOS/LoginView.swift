import SwiftUI
import AuthenticationServices 
import CryptoKit // For SHA256

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    
    // For Apple Sign In nonce
    // @State private var currentNonce: String? // Nonce is now managed by AuthService

    var body: some View {
        NavigationView {
            ScrollView { // Make content scrollable
                VStack(spacing: 20) {
                    // ... (Image, Title, ErrorMessage - keep as is)
                    Image("prysm_logo") 
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .padding(.top, 30)
                        .padding(.bottom, 10)

                    Text(showingSignUp ? "Create Prysm Account" : "Welcome to Prysm")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "#512da8"))

                    if let errorMessage = authService.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Group {
                        TextField("Email Address", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                        
                        SecureField("Password", text: $password)
                            .textContentType(showingSignUp ? .newPassword : .password)
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                    }.padding(.horizontal)

                    Button(action: {
                        if showingSignUp {
                            authService.signUpWithEmail(email: email, password: password)
                        } else {
                            authService.signInWithEmail(email: email, password: password)
                        }
                    }) {
                        Text(showingSignUp ? "Sign Up" : "Sign In")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#673ab7"))
                            .cornerRadius(10)
                            .shadow(color: Color(hex: "#673ab7").opacity(0.4), radius: 5, y: 3)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    Text("OR CONNECT WITH")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.vertical, 10)

                    // Google Sign-In Button
                    Button(action: {
                         guard let rootViewController = UIApplication.shared.connectedScenes
                            .filter({$0.activationState == .foregroundActive})
                            .compactMap({$0 as? UIWindowScene})
                            .first?.windows
                            .filter({$0.isKeyWindow}).first?.rootViewController else {
                                authService.errorMessage = "Cannot find root view controller for Google Sign-In."
                                return
                            }
                        authService.signInWithGoogle(presentingViewController: rootViewController)
                    }) {
                        HStack {
                            Image("google_logo")
                                .resizable()
                                .frame(width: 22, height: 22)
                            Text("Sign in with Google")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Color(hex: "#4285F4"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    // Apple Sign-In Button
                    SignInWithAppleButton(
                        .signIn, // Use .signIn for the label
                        onRequest: { request in
                            let rawNonce = randomNonceString()
                            authService.setCurrentNonce(rawNonce) // Pass raw nonce to AuthService
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = sha256(rawNonce) // Hash the nonce for the request
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                authService.handleAppleSignIn(authorization: authorization)
                            case .failure(let error):
                                authService.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black) 
                    .frame(height: 50)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {
                        showingSignUp.toggle()
                        authService.errorMessage = nil
                    }) {
                        Text(showingSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(Color(hex: "#673ab7"))
                    }
                    .padding(.bottom)
                }
                .padding()
            }
            .navigationBarHidden(true)
            //.background(LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray.opacity(0.1)]), startPoint: .top, endPoint: .bottom).edgesIgnoringSafeArea(.all)) // Optional background gradient
        }
    }
    
    // Nonce and SHA256 helpers should be here as they are used by this View
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

// Color Hex Extension (Keep as is)
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