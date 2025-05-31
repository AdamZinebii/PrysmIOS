//
//  PrysmIOSApp.swift
//  PrysmIOS
//
//  Created by Adam Zinebi on 10.05.2025.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import GoogleSignIn
import SafariServices
import WebKit
import FirebaseAuth
import AVFoundation
import AVKit

class LanguageManager: ObservableObject {
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
            updateBundle()
        }
    }
    
    private var bundle: Bundle?
    
    init() {
        // Récupérer la langue sauvegardée ou utiliser l'anglais par défaut
        self.currentLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "English"
        updateBundle()
    }
    
    private func updateBundle() {
        let languageCode: String
        switch currentLanguage {
        case "Français":
            languageCode = "fr"
        case "العربية":
            languageCode = "ar"
        case "English":
            languageCode = "en"
        default:
            languageCode = "en"
        }
        
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            self.bundle = Bundle.main
        }
    }
    
    func localizedString(_ key: String) -> String {
        return bundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
    }
}

@main
struct PrysmIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var authService = AuthService.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var languageManager = LanguageManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(themeManager)
                .environmentObject(languageManager)
        }
    }
}

// --- AppDelegate for Firebase Messaging and Push Notifications ---
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    lazy var authService = AuthService.shared

    override init() {
        super.init()
        print("AppDelegate: init() called.")
        // FirebaseApp.configure() // Moved to didFinishLaunchingWithOptions
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("AppDelegate: application(_:didFinishLaunchingWithOptions:) - START")
        
        // Configure Firebase first
        if FirebaseApp.app() == nil {
            print("AppDelegate: FirebaseApp not configured yet. Configuring now...")
            FirebaseApp.configure()
        } else {
            print("AppDelegate: FirebaseApp already configured.")
        }

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("AppDelegate: Error requesting notification permission: \(error.localizedDescription)")
                return
            }
            print("AppDelegate: Notification permission granted: \(granted)")
            if granted {
                DispatchQueue.main.async {
                    print("AppDelegate: Notification permission granted. Registering for remote notifications...")
                    application.registerForRemoteNotifications()
                }
            } else {
                print("AppDelegate: Notification permission denied.")
            }
        }
        
        setupAudioSessionAndRemoteControls(application: application)

        print("AppDelegate: application(_:didFinishLaunchingWithOptions:) - END")
        return true
    }

    private func setupAudioSessionAndRemoteControls(application: UIApplication) {
        print("AppDelegate: Setting up audio session and remote controls...")
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try audioSession.setActive(true)
            print("AppDelegate: Audio session configured for playback and activated.")
            
            application.beginReceivingRemoteControlEvents()
            AudioPlayerService.shared.setupRemoteTransportControls()
            print("AppDelegate: Remote controls set up.")
            
        } catch {
            print("AppDelegate: Failed to set up audio session or remote controls: \(error.localizedDescription)")
        }
    }

    // Called when a remote notification is registered.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("AppDelegate: SUCCESS - Registered for remote notifications (APNS). Device Token: \(token)")
        Messaging.messaging().apnsToken = deviceToken // Set APNS token for FCM
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("AppDelegate: ERROR - Failed to register for remote notifications (APNS): \(error.localizedDescription)")
    }

    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("AppDelegate: Firebase registration token: \(fcmToken ?? "N/A")")
        
        guard let token = fcmToken else {
            print("AppDelegate: FCM token is nil.")
            return
        }

        // Store the token in AuthService
        print("AppDelegate: Storing FCM token in AuthService")
        self.authService.updateFCMToken(token)
    }

    // MARK: - UNUserNotificationCenterDelegate
    // Handle incoming notification messages while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification, 
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("AppDelegate: Will present notification: \(userInfo)")
        
        // Show the notification in foreground
        completionHandler([.banner, .list, .sound]) 
    }

    // Handle user interaction with the notification (e.g., tapping it).
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                didReceive response: UNNotificationResponse, 
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("AppDelegate: Did receive notification response: \(userInfo)")

        // TODO: Implement navigation to relevant part of the app based on userInfo
        // For example, if the notification contains a "screen" key:
        // if let targetScreen = userInfo["screen"] as? String {
        //    if targetScreen == "news_feed" {
        //        // Navigate to NewsFeedView
        //    }
        // }

        completionHandler()
    }
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var languageManager: LanguageManager
    @State private var hasTriggeredPreferences = false
    @State private var lastPreferencesCloseTime: Date?

    var body: some View {
        Group {
            if authService.isLoadingProfile { 
                VStack {
                    Text("Loading...") // Generic loading message
                    ProgressView()
                }
            } else if authService.user != nil { // User is authenticated
                if authService.userProfile != nil && authService.userProfile!.isProfileComplete {
                    // Profile is complete, show the main app view in all cases
                    MainAppView()
                        .onAppear {
                            // If news preferences aren't completed yet, display them after a very short delay
                            // This makes the navigation hierarchy consistent for new and existing users
                            let hasCompletedPrefs = authService.userProfile?.hasCompletedNewsPreferences ?? false
                            print("DEBUG: [ContentView] hasCompletedNewsPreferences = \(hasCompletedPrefs), hasTriggeredPreferences = \(hasTriggeredPreferences)")
                            
                            // Check if preferences were recently closed (within last 3 seconds)
                            let recentlyClosed = lastPreferencesCloseTime.map { Date().timeIntervalSince($0) < 3.0 } ?? false
                            print("DEBUG: [ContentView] recentlyClosed = \(recentlyClosed)")
                            
                            if !hasCompletedPrefs && !hasTriggeredPreferences && !recentlyClosed {
                                hasTriggeredPreferences = true
                                // Delay just enough to let the view appear but not be noticeable to the user
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    print("DEBUG: [ContentView] Triggering preferences flow")
                                    // Set a state that MainAppView can observe to show preferences
                                    authService.shouldShowNewsPreferences = true
                                }
                            }
                        }
                        .onChange(of: authService.userProfile?.hasCompletedNewsPreferences) { newValue in
                            print("DEBUG: [ContentView] hasCompletedNewsPreferences changed to: \(newValue ?? false)")
                            if newValue == true {
                                hasTriggeredPreferences = false // Reset for future use
                                lastPreferencesCloseTime = Date() // Record when preferences were completed
                            }
                        }
                } else {
                    // User is signed in BUT profile is not complete (or doesn't exist yet)
                    ProfileSetupView()
                        .environmentObject(languageManager) // Add LanguageManager environment object
                }
            } else {
                // User is not signed in, show the LoginView
                LoginView()
            }
        }
        // Consider adding .onAppear here to call fetchUserProfile if user is authenticated but profile is nil
        // This can handle scenarios where the app was closed mid-profile setup.
        .onAppear {
            if authService.user != nil && authService.userProfile == nil && !authService.isLoadingProfile {
                print("ContentView appeared, user logged in but no profile, fetching...")
                authService.fetchUserProfile(uid: authService.user!.uid)
            }
        }
        .onChange(of: authService.user) { newUser in
            // Reset the trigger flag when user changes (login/logout)
            hasTriggeredPreferences = false
            lastPreferencesCloseTime = nil
        }
    }
}

struct MainAppView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showNewsPreferences: Bool = false

    var body: some View {
            ModernDashboardView()
        .fullScreenCover(isPresented: $showNewsPreferences) {
                // Présentez les nouvelles préférences modernes
                PreferencesView(isPresented: $showNewsPreferences)
        }
        // Observer les changements de shouldShowNewsPreferences dans AuthService
        .onChange(of: authService.shouldShowNewsPreferences) { newValue in
            if newValue {
                // Afficher les préférences
                showNewsPreferences = true
                // Réinitialiser le drapeau dans AuthService
                authService.shouldShowNewsPreferences = false
            }
        }
    }
}

struct BottomActionButton: View {
    let systemName: String
    let text: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: 20))
                Text(text)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isDestructive ? .red : Color.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
    }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var languageManager: LanguageManager
    @Binding var selectedLanguage: String
    let languages: [String]
    let onSave: (String) -> Void
    let onDismissSettings: () -> Void
    let onUpdateRequestPreferences: () -> Void
    
    let onRefreshAction: (() -> Void)?
    let onGenerateAction: (() -> Void)?
    
    init(selectedLanguage: Binding<String>, 
         languages: [String], 
         onSave: @escaping (String) -> Void, 
         onDismissSettings: @escaping () -> Void, 
         onUpdateRequestPreferences: @escaping () -> Void,
         onRefreshAction: (() -> Void)? = nil,
         onGenerateAction: (() -> Void)? = nil) {
        self._selectedLanguage = selectedLanguage
        self.languages = languages
        self.onSave = onSave
        self.onDismissSettings = onDismissSettings
        self.onUpdateRequestPreferences = onUpdateRequestPreferences
        self.onRefreshAction = onRefreshAction
        self.onGenerateAction = onGenerateAction
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(languageManager.localizedString("Language Preference"))) {
                    Picker(languageManager.localizedString("Choose your preferred language"), selection: $selectedLanguage) {
                        ForEach(languages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                    .onChange(of: selectedLanguage) { newLanguage in
                        // Update language immediately when changed
                        languageManager.currentLanguage = newLanguage
                        onSave(newLanguage)
                    }
                }

                Section(header: Text(languageManager.localizedString("News & Research Preferences"))) {
                    Button(languageManager.localizedString("Update My News Preferences")) {
                        onUpdateRequestPreferences()
                    }
                    .foregroundColor(Color.blue)
                }

                if onRefreshAction != nil || onGenerateAction != nil {
                    Section(header: Text(languageManager.localizedString("News Actions"))) {
                        if let refreshAction = onRefreshAction {
                            Button(languageManager.localizedString("Refresh News Feed")) {
                                refreshAction()
                                onDismissSettings()
                            }
                            .foregroundColor(Color.blue)
                        }
                        if let generateAction = onGenerateAction {
                            Button(languageManager.localizedString("Generate New Summary Now")) {
                                generateAction()
                                onDismissSettings()
                            }
                            .foregroundColor(Color.blue)
                        }
                    }
                }
                
                Section(header: Text(languageManager.localizedString("Account"))) {
                    Button(languageManager.localizedString("Sign Out")) {
                        authService.signOut()
                        onDismissSettings()
                    }
                    .foregroundColor(.red)
                }
                
                Section {
                    Button(languageManager.localizedString("Done")) {
                        onDismissSettings()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(Color.blue)
                }
            }
            .navigationTitle(languageManager.localizedString("Settings"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct MarkdownView: UIViewRepresentable {
    let markdown: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let cssStyle = """
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                margin: 0;
                padding: 0;
                color: #333;
                line-height: 1.6;
            }
            h1, h2, h3 { color: #1f77b4; }
            h3 { margin-top: 20px; margin-bottom: 10px; }
            .sources-section {
                background: #f5f5f5;
                border-radius: 6px;
                padding: 8px 12px;
                margin: 12px 0;
            }
            .sources-title {
                font-weight: 600;
                color: #555;
                margin-bottom: 8px;
            }
            .sources-buttons {
                display: flex;
                flex-wrap: wrap;
                gap: 8px;
            }
            .source-button {
                display: inline-block;
                font-size: 0.85em;
                color: #444;
                background-color: white;
                border: 1px solid #ddd;
                border-radius: 4px;
                padding: 4px 10px;
                text-decoration: none;
                box-shadow: 0 1px 2px rgba(0,0,0,0.05);
                margin-bottom: 5px;
            }
            a {
                color: #1f77b4;
                text-decoration: none;
            }
            .time-indicator {
                font-size: 0.85em;
                color: #666;
                font-style: italic;
                margin-bottom: 10px;
            }
        </style>
        """
        
        let htmlContent = markdown
            .replacingOccurrences(of: "#####", with: "<h5>")
            .replacingOccurrences(of: "####", with: "<h4>")
            .replacingOccurrences(of: "###", with: "<h3>")
            .replacingOccurrences(of: "##", with: "<h2>")
            .replacingOccurrences(of: "#", with: "<h1>")
            .replacingOccurrences(of: "\n\n", with: "</p><p>")
            .replacingOccurrences(of: "*", with: "<em>")
            .replacingOccurrences(of: "**", with: "<strong>")
            .replacingOccurrences(of: "<em><em>", with: "<strong>")
            .replacingOccurrences(of: "</em></em>", with: "</strong>")
            
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            \(cssStyle)
        </head>
        <body>
            <p>\(htmlContent)</p>
        </body>
        </html>
        """
        
        uiView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownView
        
        init(_ parent: MarkdownView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
