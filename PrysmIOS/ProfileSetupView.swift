import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var firstName: String = ""
    @State private var surname: String = ""
    @State private var ageString: String = ""
    
    @State private var isSaving: Bool = false
    @State private var localErrorMessage: String? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information").font(.headline)) {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Surname", text: $surname)
                        .textContentType(.familyName)
                    TextField("Age (Optional)", text: $ageString)
                        .keyboardType(.numberPad)
                }

                if let localErrorMessage = localErrorMessage {
                    Text(localErrorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                if let authErrorMessage = authService.errorMessage {
                    Text(authErrorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: saveProfile) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .padding(.trailing, 5)
                        }
                        Text(isSaving ? "Saving..." : "Save Profile & Continue")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSaving || firstName.isEmpty || surname.isEmpty)
                .padding(.vertical)
                .listRowBackground(Color.black)
                .foregroundColor(.white)
            }
            .navigationTitle("Complete Your Profile")
            .onAppear {
                // Pre-fill form if editing existing (partial) profile
                if let profile = authService.userProfile {
                    self.firstName = profile.firstName
                    self.surname = profile.surname
                    if let age = profile.age {
                        self.ageString = "\(age)"
                    }
                }
                authService.errorMessage = nil // Clear global errors on appear
            }
        }
    }
    
    func saveProfile() {
        localErrorMessage = nil
        authService.errorMessage = nil
        isSaving = true
        
        guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            localErrorMessage = "First name cannot be empty."
            isSaving = false
            return
        }
        guard !surname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            localErrorMessage = "Surname cannot be empty."
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
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView().environmentObject(AuthService.shared)
    }
} 
