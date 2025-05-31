import SwiftUI
import GoogleSignIn
import FirebaseAuth
import FirebaseCore

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: 60))
                            .foregroundColor(themeManager.accentColor)
                        
                        Text("Orel News")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.textPrimaryColor)
                        
                        Text("Your personalized news companion")
                            .font(.subheadline)
                            .foregroundColor(themeManager.textSecondaryColor)
                    }
                    .padding(.bottom, 40)
                    
                    // Sign In Button
                    Button(action: signInWithGoogle) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            
                            Text("Sign in with Google")
                                .font(.headline)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal, 40)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.accentColor))
                            .scaleEffect(1.5)
                            .padding(.top, 20)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 10)
                    }
                }
                .padding()
            }
        }
    }
    
    private func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Failed to get client ID"
            isLoading = false
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            errorMessage = "Failed to get root view controller"
            isLoading = false
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [self] result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                isLoading = false
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                errorMessage = "Failed to get authentication token"
                isLoading = false
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            Auth.auth().signIn(with: credential) { result, error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    return
                }
                
                // Successfully signed in
                if let user = result?.user {
                    authService.user = user
                    authService.fetchUserProfile(uid: user.uid)
                }
                
                isLoading = false
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthService.shared)
        .environmentObject(ThemeManager())
} 