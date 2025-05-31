import Foundation
import FirebaseAuth
import FirebaseFirestore
// import FirebaseFirestoreSwift // Remove this if it's not a separate product
import AuthenticationServices 
import GoogleSignIn 
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import FirebaseFunctions
import SwiftUI

// UserDefaults key for storing pending FCM token
private let kPendingFCMTokenKey = "pendingFCMToken"

// Define a UserProfile struct that matches your Firestore document structure
struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String? // Firestore document ID, maps to user.uid
    var firstName: String
    var surname: String
    var age: Int?
    var country: String = "" // Added country field
    var createdAt: Timestamp? = Timestamp(date: Date()) // Store creation date
    var updatedAt: Timestamp? = Timestamp(date: Date())

    // Flag to indicate if profile setup is complete
    var isProfileComplete: Bool = false 
    var hasCompletedNewsPreferences: Bool? = false // Made optional with default value
    var original_news_subjects: [String] = []
    var news_subjects: [String] = []
    var original_research_topics: [String] = []
    var specific_research_topics: [String] = []
    var news_detail_levels: [String] = []
    var research_detail_levels: [String] = []
    var preferredLanguage: String = "English"  // Default language is English
    var structuredTrackedItems: [TrackedItem] = [] // New field for specific trackers
    
    // New fields for update frequency
    var updateFrequency: Int? = 1
    var firstUpdateTime: String? // Stored as HH:mm string
    var secondUpdateTime: String? // Stored as HH:mm string, optional
    
    // Custom coding keys to handle potentially missing fields
    private enum CodingKeys: String, CodingKey {
        case id, firstName, surname, age, country, createdAt, updatedAt, 
             isProfileComplete, hasCompletedNewsPreferences,
             original_news_subjects, news_subjects,
             original_research_topics, specific_research_topics,
             news_detail_levels, research_detail_levels,
             preferredLanguage,
             structuredTrackedItems, // Added to coding keys
             updateFrequency, firstUpdateTime, secondUpdateTime // New keys
    }
    
    // Default initializer for manual document handling
    init(id: String?, firstName: String, surname: String) {
        self.id = id
        self.firstName = firstName
        self.surname = surname
    }
    
    // Custom initializer from decoder to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        surname = try container.decode(String.self, forKey: .surname)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        country = try container.decodeIfPresent(String.self, forKey: .country) ?? ""
        createdAt = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Timestamp.self, forKey: .updatedAt)
        isProfileComplete = try container.decodeIfPresent(Bool.self, forKey: .isProfileComplete) ?? false
        
        // Handle potentially missing news preferences fields
        hasCompletedNewsPreferences = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedNewsPreferences) ?? false
        original_news_subjects = try container.decodeIfPresent([String].self, forKey: .original_news_subjects) ?? []
        news_subjects = try container.decodeIfPresent([String].self, forKey: .news_subjects) ?? []
        original_research_topics = try container.decodeIfPresent([String].self, forKey: .original_research_topics) ?? []
        specific_research_topics = try container.decodeIfPresent([String].self, forKey: .specific_research_topics) ?? []
        news_detail_levels = try container.decodeIfPresent([String].self, forKey: .news_detail_levels) ?? []
        research_detail_levels = try container.decodeIfPresent([String].self, forKey: .research_detail_levels) ?? []
        preferredLanguage = try container.decode(String.self, forKey: .preferredLanguage)
        structuredTrackedItems = try container.decodeIfPresent([TrackedItem].self, forKey: .structuredTrackedItems) ?? [] // Decode new field
        
        // Decode frequency settings
        updateFrequency = try container.decodeIfPresent(Int.self, forKey: .updateFrequency) ?? 1
        firstUpdateTime = try container.decodeIfPresent(String.self, forKey: .firstUpdateTime)
        secondUpdateTime = try container.decodeIfPresent(String.self, forKey: .secondUpdateTime)
    }
}

// Define TrackedItem struct and its Type enum
struct TrackedItem: Codable, Hashable, Identifiable {
    var id = UUID() 
    var type: TrackedItemType
    var identifier: String // e.g., league_id, or asset symbol
    var competitionName: String? // Name of the competition for sports trackers

    enum TrackedItemType: String, CaseIterable, Codable, Identifiable {
        // case teamSchedule = "Team Matches" // Removed for simplification
        case leagueSchedule = "League Matches"   // Tracks all matches for a league ID
        case leagueStanding = "League Standing" // Tracks a league's table
        case assetPrice = "Asset Price"       // Tracks an asset's price

        var id: String { self.rawValue }

        var placeholderText: String {
            switch self {
            // case .teamSchedule: // Removed
            //     return "Team ID (e.g., 57 for Arsenal)"
            case .leagueSchedule:
                return "Search & select a league"
            case .leagueStanding:
                return "Search & select a league"
            case .assetPrice:
                return "Search for asset (e.g., AAPL, Oracle)"
            }
        }
    }
    
    init(type: TrackedItemType, identifier: String, competitionName: String? = nil) {
        self.id = UUID()
        self.type = type
        self.identifier = identifier
        self.competitionName = competitionName
    }
}

class AuthService: ObservableObject {
    static let shared = AuthService() // <-- Reverted to static let

    @Published var user: User?
    private var pendingFCMToken: String? {
        get {
            // First check memory, then UserDefaults
            return _pendingFCMToken ?? UserDefaults.standard.string(forKey: kPendingFCMTokenKey)
        }
        set {
            _pendingFCMToken = newValue
            // Persist to UserDefaults
            UserDefaults.standard.set(newValue, forKey: kPendingFCMTokenKey)
        }
    }
    private var _pendingFCMToken: String?
    @Published var errorMessage: String?
    @Published var userProfile: UserProfile? // To hold the loaded profile
    @Published var isLoadingProfile: Bool = false
    @Published var apiKeys: [String: String]? // To store API keys fetched from backend
    @Published var isLoadingApiKeys: Bool = false
    @Published var shouldShowNewsPreferences: Bool = false // Flag to trigger news preferences flow
    @Published var isSavingPreferencesInBackground: Bool = false // Flag to show loading while saving preferences
    @Published var isFirstTimeSetup: Bool = false // Flag to track if this is first time preferences setup

    private var db = Firestore.firestore() // Firestore instance
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    var isAuthenticated: Bool {
        user != nil
    }

    // Make init private for singleton
    private init() {
        // Load any pending token from UserDefaults
        if let savedToken = UserDefaults.standard.string(forKey: kPendingFCMTokenKey) {
            print("AuthService: Loaded pending FCM token from UserDefaults")
            _pendingFCMToken = savedToken
        }
        setupAuthStateListener()
    }

    func registerAuthStateHandler() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            guard let self = self else { return }
            self.user = user
            if let firebaseUser = user {
                print("User is signed in with uid: \(firebaseUser.uid)")
                self.fetchUserProfile(uid: firebaseUser.uid)
                self.fetchApiKeysFromServer() // Fetch API keys after user signs in
            } else {
                print("User is signed out.")
                self.userProfile = nil // Clear profile on sign out
            }
        }
    }

    // --- API Key Management ---
    func fetchApiKeysFromServer() {
        guard apiKeys == nil else { // Fetch only if not already loaded
            print("API keys already loaded or being loaded.")
            return
        }
        isLoadingApiKeys = true
        errorMessage = nil
        
        // Ensure you have Firebase Functions set up and a callable function named "getApiKeys"
        let functions = Functions.functions() // Requires FirebaseFunctions import
        functions.httpsCallable("getApiKeys").call { [weak self] result, error in
            guard let self = self else { return }
            self.isLoadingApiKeys = false
            if let error = error as NSError? {
                self.errorMessage = "Error fetching API keys: \(error.localizedDescription)"
                print("Error fetching API keys: \(error.localizedDescription)")
                // Handle specific errors, e.g., if the function is not found or auth issues
                if error.domain == FunctionsErrorDomain {
                    let code = FunctionsErrorCode(rawValue: error.code)
                    switch code {
                    case .unauthenticated:
                        self.errorMessage = "API Key Fetch: User not authenticated."
                    case .notFound:
                        self.errorMessage = "API Key Fetch: Backend function not found."
                    default:
                        self.errorMessage = "API Key Fetch: \(error.localizedDescription)"
                    }
                }
                return
            }
            if let keys = result?.data as? [String: String] {
                self.apiKeys = keys
                print("API keys fetched successfully: \(keys.keys.joined(separator: ", "))")
                // Example: Access a key
                // if let footballKey = self.apiKeys?["FOOTBALL_DATA_API_KEY"] {
                //    print("Got football key: \(footballKey.prefix(5))...")
                // }
            } else {
                self.errorMessage = "API Key Fetch: Invalid data format."
                print("Invalid data format for API keys.")
            }
        }
    }

    // --- User Profile Functions ---
    func fetchUserProfile(uid: String) {
        isLoadingProfile = true
        let userDocRef = db.collection("users").document(uid)
        userDocRef.getDocument { (document, error) in
            if let error = error {
                self.errorMessage = "Error fetching user profile: \(error.localizedDescription)"
                print("Error fetching user profile: \(error)")
                self.isLoadingProfile = false
                // User might not have a profile yet, which is not necessarily an error for a new user
                // Consider this an incomplete profile state if document doesn't exist
                if (error as NSError).code == FirestoreErrorCode.notFound.rawValue {
                    self.userProfile = nil // Explicitly set to nil if not found
                } 
                return
            }

            if let document = document, document.exists {
                // Manual document handling instead of Codable
                if let data = document.data() {
                    // Create UserProfile manually from dictionary
                    var profile = UserProfile(
                        id: document.documentID,
                        firstName: data["firstName"] as? String ?? "",
                        surname: data["surname"] as? String ?? ""
                    )
                    
                    // Set optional fields
                    profile.age = data["age"] as? Int
                    profile.createdAt = data["createdAt"] as? Timestamp
                    profile.updatedAt = data["updatedAt"] as? Timestamp
                    profile.isProfileComplete = data["isProfileComplete"] as? Bool ?? false
                    
                    // Handle news preferences fields - these may be missing in older documents
                    profile.hasCompletedNewsPreferences = data["hasCompletedNewsPreferences"] as? Bool ?? false
                    profile.original_news_subjects = data["original_news_subjects"] as? [String] ?? []
                    profile.news_subjects = data["news_subjects"] as? [String] ?? []
                    profile.original_research_topics = data["original_research_topics"] as? [String] ?? []
                    profile.specific_research_topics = data["specific_research_topics"] as? [String] ?? []
                    profile.news_detail_levels = data["news_detail_levels"] as? [String] ?? []
                    profile.research_detail_levels = data["research_detail_levels"] as? [String] ?? []
                    profile.preferredLanguage = data["preferredLanguage"] as? String ?? "English"
                    
                    // Debug: Log country data from Firestore
                    if let countryData = data["country"] {
                        print("DEBUG: [fetchUserProfile] Found country in Firestore: \(countryData) (Type: \(type(of: countryData)))")
                    } else {
                        print("DEBUG: [fetchUserProfile] No country data found in Firestore")
                    }
                    
                    profile.country = data["country"] as? String ?? ""
                    print("DEBUG: [fetchUserProfile] Set profile.country to: '\(profile.country)'")
                    
                    // Manually decode structuredTrackedItems if present
                    if let itemsData = data["structuredTrackedItems"] as? [[String: Any]] {
                        profile.structuredTrackedItems = itemsData.compactMap { itemDict in
                            print("DEBUG: Raw item data from Firestore: \(itemDict)")
                            
                            guard let typeString = itemDict["type"] as? String,
                                  let type = TrackedItem.TrackedItemType(rawValue: typeString),
                                  let identifier = itemDict["identifier"] as? String else {
                                print("DEBUG: Failed to decode required fields")
                                return nil
                            }
                            
                            // Try to get competitionName from different possible locations
                            var competitionName: String? = nil
                            if let name = itemDict["competitionName"] as? String {
                                competitionName = name
                            } else if let matches = itemDict["matches"] as? [[String: Any]],
                                      let firstMatch = matches.first,
                                      let competition = firstMatch["competition"] as? String {
                                competitionName = competition
                            }
                            
                            print("DEBUG: Decoding TrackedItem:")
                            print("  - Type: \(typeString)")
                            print("  - ID: \(identifier)")
                            print("  - Competition Name: \(competitionName ?? "nil")")
                            
                            return TrackedItem(type: type, identifier: identifier, competitionName: competitionName)
                        }
                    } else {
                        profile.structuredTrackedItems = []
                    }
                    
                    // Manually decode update frequency settings
                    profile.updateFrequency = data["update_frequency"] as? Int ?? 1
                    profile.firstUpdateTime = data["first_update_time"] as? String
                    profile.secondUpdateTime = data["second_update_time"] as? String
                    
                    self.userProfile = profile
                    print("User profile fetched: \(profile.firstName), NewsPrefsCompleted: \(profile.hasCompletedNewsPreferences ?? false)")
                } else {
                    self.errorMessage = "Error: Document exists but has no data"
                    print("Error: Document exists but has no data")
                    self.userProfile = nil
                }
            } else {
                print("User profile document does not exist for uid: \(uid) - new user or profile not created.")
                self.userProfile = nil // No profile exists yet
            }
            self.isLoadingProfile = false
        }
    }

    func updateUserProfile(firstName: String, surname: String, age: Int?) {
        print("DEBUG: [updateUserProfile] Starting update with basic profile info")
        guard let user = self.user else {
            let error = "No authenticated user found to update profile."
            print("ERROR: \(error)")
            self.errorMessage = error
            return
        }

        isLoadingProfile = true
        let userDocRef = db.collection("users").document(user.uid)
        
        var dataToUpdate: [String: Any] = [
            "firstName": firstName,
            "surname": surname,
            "updatedAt": Timestamp(date: Date()),
            "isProfileComplete": true, // Mark as complete
            "preferredLanguage": "English", // Default language
            "country": "" // Empty country for now - will be set in preferences
        ]
        
        print("DEBUG: [updateUserProfile] Prepared data for Firestore - dataToUpdate: \(dataToUpdate)")
        
        if let age = age {
            dataToUpdate["age"] = age
        }

        // Use merge to create if not exists, or update if it does
        print("DEBUG: Attempting to save to Firestore...")
        userDocRef.setData(dataToUpdate, merge: true) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                let errorMsg = "Error updating user profile: \(error.localizedDescription)"
                print("ERROR: \(errorMsg)")
                print("Full error: \(error)")
                self.errorMessage = errorMsg
            } else {
                print("SUCCESS: User profile updated successfully in Firestore")
                print("DEBUG: Fetching updated profile...")
                // Re-fetch to update the local userProfile object
                self.fetchUserProfile(uid: user.uid)
                self.errorMessage = nil // Clear error on success
            }
            self.isLoadingProfile = false
        }
    }

    // Keep the original method for backward compatibility
    func updateUserProfile(firstName: String, surname: String, age: Int?, country: String, preferredLanguage: String = "English") {
        print("DEBUG: [updateUserProfile] Starting update with country code: '\(country)'")
        guard let user = self.user else {
            let error = "No authenticated user found to update profile."
            print("ERROR: \(error)")
            self.errorMessage = error
            return
        }

        // Validate country code
        let countryCode = country.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        print("DEBUG: [updateUserProfile] Processed country code: '\(countryCode)'")
        
        guard !countryCode.isEmpty else {
            let error = "Country code cannot be empty"
            print("ERROR: \(error)")
            self.errorMessage = error
            return
        }

        isLoadingProfile = true
        let userDocRef = db.collection("users").document(user.uid)
        
        var dataToUpdate: [String: Any] = [
            "firstName": firstName,
            "surname": surname,
            "updatedAt": Timestamp(date: Date()),
            "isProfileComplete": true, // Mark as complete
            "preferredLanguage": preferredLanguage,
            "country": countryCode // Using the processed country code
        ]
        
        print("DEBUG: [updateUserProfile] Prepared data for Firestore - dataToUpdate: \(dataToUpdate)")
        
        if let age = age {
            dataToUpdate["age"] = age
        }

        // Use merge to create if not exists, or update if it does
        print("DEBUG: Attempting to save to Firestore...")
        userDocRef.setData(dataToUpdate, merge: true) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                let errorMsg = "Error updating user profile: \(error.localizedDescription)"
                print("ERROR: \(errorMsg)")
                print("Full error: \(error)")
                self.errorMessage = errorMsg
            } else {
                print("SUCCESS: User profile updated successfully in Firestore")
                print("DEBUG: Fetching updated profile...")
                // Re-fetch to update the local userProfile object
                self.fetchUserProfile(uid: user.uid)
                self.errorMessage = nil // Clear error on success
            }
            self.isLoadingProfile = false
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.userProfile = nil
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
            self.errorMessage = "Error signing out: \(signOutError.localizedDescription)"
        }
    }

    func signInWithEmail(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            self.errorMessage = nil
            if let user = authResult?.user {
                print("User signed in with email. UID: \(user.uid)")
                self.processPendingFCMToken()  // Process any pending token
            }
        }
    }

    func signUpWithEmail(email: String, password: String) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            self.errorMessage = nil
            
            guard let userId = authResult?.user.uid else {
                self.errorMessage = "Failed to get user ID after sign up"
                return
            }
            
            print("User created with email. UID: \(userId)")
            
            // Get current FCM token if available
            Messaging.messaging().token { [weak self] token, error in
                guard let self = self else { return }
                
                // Create user data with FCM token if available
                var userData: [String: Any] = [
                    "id": userId,
                    "email": email,
                    "createdAt": FieldValue.serverTimestamp(),
                    "isProfileComplete": false
                ]
                
                // Add FCM token if available
                if let token = token, !token.isEmpty {
                    userData["fcmToken"] = token
                    userData["fcmTokenLastUpdated"] = FieldValue.serverTimestamp()
                    print("Adding FCM token to new user profile")
                }
                
                // Store the user profile
                self.db.collection("users").document(userId).setData(userData) { error in
                    if let error = error {
                        print("Error creating user profile: \(error.localizedDescription)")
                        self.errorMessage = "Failed to create user profile: \(error.localizedDescription)"
                        // Store token as pending for later retry
                        if let token = token, !token.isEmpty {
                            self.pendingFCMToken = token
                        }
                    } else {
                        print("Successfully created user profile for: \(userId)")
                        // Clear pending token since it's now stored
                        self.pendingFCMToken = nil
                        
                        // Also update the token via the function for consistency
                        if let token = token, !token.isEmpty {
                            self.storeFCMToken(userId: userId, token: token)
                        }
                    }
                }
            }
        }
    }
    
    func signInWithGoogle(presentingViewController: UIViewController?) {
        self.errorMessage = nil 
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            self.errorMessage = "Google Client ID not found in Firebase options."
            print("Error: Google Client ID not found - check GoogleService-Info.plist.")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let rootViewController = presentingViewController ?? UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.windows
            .filter({$0.isKeyWindow}).first?.rootViewController else {
                self.errorMessage = "Could not find presenting view controller for Google Sign-In."
                print("Error: Could not find presenting view controller for Google Sign-In.")
                return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    print("Google Sign-In was canceled.")
                } else {
                    self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                }
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self.errorMessage = "Google Sign-In succeeded but ID token missing."
                return
            }
            
            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                if let error = error {
                    self.errorMessage = "Firebase Sign-In with Google failed: \(error.localizedDescription)"
                    return
                }
                self.errorMessage = nil
                guard let user = authResult?.user else { return }
                let userId = user.uid
                let isNewUser = authResult?.additionalUserInfo?.isNewUser ?? false
                
                if isNewUser {
                    print("New Google user signed up: \(userId)")
                    // Create a basic user profile for new Google sign-in
                    let email = user.email ?? ""
                    let userData: [String: Any] = [
                        "id": userId,
                        "email": email,
                        "createdAt": FieldValue.serverTimestamp(),
                        "isProfileComplete": false
                    ]
                    
                    // Store the user profile
                    self.db.collection("users").document(userId).setData(userData) { error in
                        if let error = error {
                            print("Error creating Google user profile: \(error.localizedDescription)")
                            self.errorMessage = "Failed to create user profile: \(error.localizedDescription)"
                        } else {
                            print("Successfully created Google user profile for: \(userId)")
                            // Now that profile is created, process any pending FCM token
                            self.processPendingFCMToken()
                        }
                    }
                } else {
                    print("Existing Google user signed in: \(userId)")
                    // For existing users, just fetch the profile and process FCM token
                    self.fetchUserProfile(uid: userId)
                    self.processPendingFCMToken()
                }
            }
        }
    }
    
    func setCurrentNonce(_ nonce: String?) {
        self.currentNonce = nonce
    }

    func handleAppleSignIn(authorization: ASAuthorization) {
        self.errorMessage = nil
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            self.errorMessage = "Apple Auth failed: Invalid credential."
            return
        }
        guard let nonce = self.currentNonce else {
            self.errorMessage = "Apple Auth failed: Nonce missing."
            return
        }
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            self.errorMessage = "Apple Auth failed: Token issue."
            return
        }
        let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                idToken: idTokenString,
                                                rawNonce: nonce)
        Auth.auth().signIn(with: credential) { [weak self] (authResult, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = "Firebase Sign-In with Apple failed: \(error.localizedDescription)"
                return
            }
            self.errorMessage = nil
            if let user = authResult?.user {
                print("User signed into Firebase with Apple. UID: \(user.uid)")
                self.processPendingFCMToken()  // Process any pending token
            }
        }
    }
    
    // Update preferences completion in AuthService
    func updateLocalProfileForPrefCompletion(
        originalNews: [String],
        refinedNews: [String],
        originalResearch: [String],
        refinedResearch: [String],
        newsDetails: [String],
        researchDetails: [String]
    ) {
        if var profile = self.userProfile {
            profile.original_news_subjects = originalNews
            profile.news_subjects = refinedNews
            profile.original_research_topics = originalResearch
            profile.specific_research_topics = refinedResearch
            profile.news_detail_levels = newsDetails
            profile.research_detail_levels = researchDetails
            profile.hasCompletedNewsPreferences = true // Mark as complete
            
            self.userProfile = profile
            print("DEBUG: Local profile updated after preference completion.")
            print("News: \(originalNews), details: \(newsDetails)")
            print("Research: \(originalResearch), details: \(researchDetails)")
        } else {
            print("Error: Cannot update preferences, userProfile is nil")
        }
    }

    // New function to mark news preferences as complete
    func markNewsPreferencesComplete() {
        guard let user = self.user else {
            print("Cannot mark news preferences complete: No user.")
            return
        }
        
        print("DEBUG: [markNewsPreferencesComplete] Marking preferences as complete for user \(user.uid)")
        print("DEBUG: [markNewsPreferencesComplete] isFirstTimeSetup: \(isFirstTimeSetup)")
        
        // Update Firestore directly with simple data
        let userDocRef = db.collection("users").document(user.uid)
        userDocRef.updateData([
            "hasCompletedNewsPreferences": true,
            "updatedAt": Timestamp(date: Date())
        ]) { [weak self] error in
            guard let self = self else { return }
            
                if let error = error {
                print("ERROR: [markNewsPreferencesComplete] Failed to update Firestore: \(error.localizedDescription)")
                } else {
                print("SUCCESS: [markNewsPreferencesComplete] Updated hasCompletedNewsPreferences in Firestore")
                
                // Update local state immediately
                self.userProfile?.hasCompletedNewsPreferences = true
                print("DEBUG: [markNewsPreferencesComplete] Updated local userProfile.hasCompletedNewsPreferences = true")
                
                // Trigger update endpoint for first-time users
                if self.isFirstTimeSetup {
                    print("🚀 [markNewsPreferencesComplete] First time setup detected, triggering update endpoint")
                    Task {
                        await UpdateService.shared.triggerFirstTimeUpdate(userId: user.uid)
                    }
                    // Reset the flag
                    self.isFirstTimeSetup = false
                }
            }
        }
    }

    // --- FCM Token Management ---
    
    /// Updates the FCM token for the current user
    /// - Parameter token: The FCM token to store
    func updateFCMToken(_ token: String) {
        print("AuthService: updateFCMToken called with token: \(token.prefix(6))...")
        if let userId = user?.uid {
            print("AuthService: User is authenticated, storing token immediately for user \(userId)")
            storeFCMToken(userId: userId, token: token)
        } else {
            // Store the token to be processed after authentication
            print("AuthService: User not authenticated, storing token as pending")
            pendingFCMToken = token
        }
    }
    
    private func setupAuthStateListener() {
        // Remove any existing listener to avoid duplicates
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
        
        // Add new listener
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            
            // Update the user - this will automatically update isAuthenticated
            self.user = user
            
            if let user = user {
                print("Auth state changed: User is signed in with UID: \(user.uid)")
                self.fetchUserProfile(uid: user.uid)
                self.processPendingFCMToken()  // Process any pending token
            } else {
                print("Auth state changed: User is signed out")
                self.userProfile = nil
            }
        }
    }
    
    private func processPendingFCMToken() {
        print("AuthService: Processing pending FCM token...")
        guard let userId = user?.uid else {
            print("AuthService: User not authenticated")
            return
        }
        
        // If no pending token, try to get the current token
        if pendingFCMToken == nil {
            print("AuthService: No pending token, requesting current token...")
            Messaging.messaging().token { [weak self] token, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("AuthService: Error getting FCM token: \(error.localizedDescription)")
                    return
                }
                
                if let token = token {
                    print("AuthService: Retrieved fresh FCM token: \(token.prefix(6))...")
                    self.storeFCMTokenIfProfileExists(userId: userId, token: token)
                }
            }
        } else if let token = pendingFCMToken {
            print("AuthService: Using pending token")
            storeFCMTokenIfProfileExists(userId: userId, token: token)
        }
    }
    
    private func storeFCMTokenIfProfileExists(userId: String, token: String) {
        print("AuthService: Verifying profile exists for user \(userId)")
        
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("AuthService: Error checking user profile: \(error.localizedDescription)")
                // Store the token as pending and try again later
                self.pendingFCMToken = token
                return
            }
            
            if document?.exists == true {
                print("AuthService: Storing FCM token for user \(userId)")
                self.storeFCMToken(userId: userId, token: token)
                self.pendingFCMToken = nil // Clear only after successful storage
            } else {
                print("AuthService: Profile doesn't exist yet, will retry")
                self.pendingFCMToken = token // Keep the token for next attempt
            }
        }
    }
    
    func storeFCMToken(userId: String, token: String) {
        print(" [AuthService] storeFCMToken called. UserID: \(userId), Token: \(token.prefix(6))...")
        
        // First, store in Firestore directly as a backup
        let userRef = db.collection("users").document(userId)
        userRef.updateData([
            "fcmToken": token,
            "fcmTokenLastUpdated": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print(" [AuthService] Error updating FCM token in Firestore: \(error.localizedDescription)")
                // Keep the token as pending to retry later
                self.pendingFCMToken = token
                return
            }
            
            print(" [AuthService] Successfully updated FCM token in Firestore for user \(userId)")
            
            // Only clear the pending token after successful Firestore update
            self.pendingFCMToken = nil
            
            // Then call the Firebase Function
            print(" [AuthService] Calling Firebase Function 'store_fcm_token'...")
            let functions = Functions.functions(region: "us-central1")
            functions.httpsCallable("store_fcm_token").call(["userId": userId, "fcmToken": token]) { result, error in
                if let error = error as NSError? {
                    print(" [AuthService] Error calling 'store_fcm_token' Firebase Function:")
                    print("  - Error Code: \(error.code)")
                    print("  - Error Domain: \(error.domain)")
                    print("  - Localized Description: \(error.localizedDescription)")
                    
                    // Log additional error details if available
                    for (key, value) in error.userInfo {
                        print("  - \(key): \(value)")
                    }
                } else if let data = result?.data as? [String: Any] {
                    print(" [AuthService] Successfully called 'store_fcm_token' with result: \(data)")
                } else {
                    print(" [AuthService] Successfully called 'store_fcm_token' but got no data in response")
                }
            }
        }
    }

    func clearFCMToken(userId: String) {
        // Optional: Call a function to remove the token from Firestore if user logs out or disables notifications
        print("AuthService: Attempting to clear FCM token for user \(userId)")
        let functions = Functions.functions()
        functions.httpsCallable("clear_fcm_token").call(["userId": userId]) { result, error in
            if let error = error {
                print("AuthService: Error clearing FCM token: \(error.localizedDescription)")
                return
            }
            print("AuthService: FCM token cleared successfully via Firebase Function.")
        }
    }

    deinit {
        if let authStateHandler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(authStateHandler)
        }
    }
} 