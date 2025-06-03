# Token FCM - Documentation Complète

## Vue d'ensemble

Cette documentation explique comment le token Firebase Cloud Messaging (FCM) est demandé, obtenu et géré dans l'application iOS PrysmIOS après l'installation.

## Architecture du système

Le système de gestion des tokens FCM utilise plusieurs composants :

- **AppDelegate** : Gère l'initialisation Firebase et les permissions de notification
- **AuthService** : Stocke et gère les tokens FCM pour les utilisateurs
- **Firebase Messaging** : Service qui génère et fournit les tokens FCM
- **Firestore** : Base de données où les tokens sont persistés

## Processus de demande du token FCM

### 1. Initialisation au lancement de l'app

#### Dans `PrysmIOSApp.swift` - AppDelegate

```swift
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
    
    return true
}
```

**Étapes :**
1. Configuration de Firebase
2. Attribution des delegates pour Firebase Messaging et notifications
3. Demande d'autorisation pour les notifications (popup système)
4. Si accordée : enregistrement pour les notifications distantes

### 2. Gestion des tokens APNS

```swift
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
```

### 3. Récupération du token FCM

#### Delegate MessagingDelegate

```swift
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
```

**Quand cette méthode est appelée :**
- Première génération du token
- Refresh du token (périodique ou après réinstallation)
- Changement d'appareil ou restauration

## Gestion dans AuthService

### 1. Système de "Pending Token"

```swift
// UserDefaults key for storing pending FCM token
private let kPendingFCMTokenKey = "pendingFCMToken"

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
```

### 2. Point d'entrée principal

```swift
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
```

### 3. Traitement des tokens en attente

```swift
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
```

### 4. Stockage sécurisé

```swift
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
            } else if let data = result?.data as? [String: Any] {
                print(" [AuthService] Successfully called 'store_fcm_token' with result: \(data)")
            } else {
                print(" [AuthService] Successfully called 'store_fcm_token' but got no data in response")
            }
        }
    }
}
```

## Scénarios d'utilisation

### Scénario 1 : Première installation
1. App se lance → Firebase configure
2. Demande permission notifications → utilisateur accepte
3. Enregistrement APNS → token FCM généré
4. Token stocké comme "pending" (pas encore connecté)
5. Utilisateur se connecte → token traité et stocké

### Scénario 2 : Utilisateur déjà connecté
1. App se lance → Firebase configure
2. Token FCM généré → directement stocké pour l'utilisateur

### Scénario 3 : Création de nouveau compte
```swift
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
        // Handle result...
    }
}
```

### Scénario 4 : Connexion Google/Apple
Le token pending est traité après la connexion réussie :
```swift
if isNewUser {
    // Create profile then process token
    self.processPendingFCMToken()
} else {
    // Existing user - just process token
    self.processPendingFCMToken()
}
```

## Gestion des erreurs et retry

### 1. Token en attente persistant
- Stockage dans UserDefaults pour survivre aux redémarrages
- Traitement automatique à la prochaine connexion

### 2. Échec de stockage
- Token remis en "pending" pour retry automatique
- Logs détaillés pour debug

### 3. Profil utilisateur inexistant
```swift
private func storeFCMTokenIfProfileExists(userId: String, token: String) {
    let userRef = db.collection("users").document(userId)
    userRef.getDocument { [weak self] (document, error) in
        if document?.exists == true {
            // Profile exists - store token
            self.storeFCMToken(userId: userId, token: token)
            self.pendingFCMToken = nil
        } else {
            // Profile doesn't exist yet - keep as pending
            self.pendingFCMToken = token
        }
    }
}
```

## Débogage et monitoring

### Logs importantes
- `AppDelegate: Firebase registration token: [TOKEN]`
- `AuthService: updateFCMToken called with token: [TOKEN_PREFIX]...`
- `AuthService: User is authenticated, storing token immediately`
- `AuthService: User not authenticated, storing token as pending`
- `Successfully updated FCM token in Firestore for user [USER_ID]`

### Points de vérification
1. **Permission notifications** : Vérifier que l'utilisateur accepte
2. **Token généré** : Vérifier les logs AppDelegate
3. **Stockage réussi** : Vérifier les logs AuthService
4. **Persistance** : Vérifier en base Firestore

## Configuration Firebase

### GoogleService-Info.plist
Clés importantes pour FCM :
```xml
<key>GCM_SENDER_ID</key>
<string>808558524364</string>
<key>IS_GCM_ENABLED</key>
<true></true>
```

### Imports nécessaires
```swift
import FirebaseMessaging
import UserNotifications
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
```

## Conclusion

Le système de gestion des tokens FCM dans PrysmIOS est robuste avec :
- **Gestion automatique** des tokens à l'installation
- **Persistance** des tokens en attente
- **Retry automatique** en cas d'échec
- **Double stockage** (Firestore + Firebase Functions)
- **Logs détaillés** pour le debugging

Le token est demandé dès le premier lancement de l'app, après acceptation des permissions de notification, et géré intelligemment selon l'état de connexion de l'utilisateur. 