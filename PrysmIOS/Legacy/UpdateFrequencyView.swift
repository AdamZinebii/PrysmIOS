import SwiftUI
import FirebaseAuth

struct UpdateFrequencyView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode

    // Preferences passed from ResearchTopicsView
    let newsSubjects: [String]
    let newsDetailLevels: [String]
    let researchTopics: [String]
    let researchDetailLevels: [String]
    let structuredTrackers: [[String: String]] // Use the same structure as the payload
    var onPreferencesSaved: (() -> Void)? = nil

    @State private var updateFrequency: Int = 1 // 1 for once, 2 for twice
    @State private var firstUpdateTime: Date = Date()
    @State private var secondUpdateTime: Date = Date()
    @State private var showSecondTimePicker: Bool = false

    @State private var isSaving: Bool = false
    @State private var localErrorMessage: String? = nil

    let frequencyOptions = [1, 2]

    var body: some View {
        Form {
            Section(header: Text("Update Frequency")) {
                Picker("How often?", selection: $updateFrequency) {
                    Text("Once a day").tag(1)
                    Text("Twice a day").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: updateFrequency) { newValue in
                    showSecondTimePicker = (newValue == 2)
                }
            }

            Section(header: Text("Update Times")) {
                DatePicker("First update at", selection: $firstUpdateTime, displayedComponents: .hourAndMinute)
                
                if showSecondTimePicker {
                    DatePicker("Second update at", selection: $secondUpdateTime, displayedComponents: .hourAndMinute)
                }
            }
            
            if let localErrorMessage = localErrorMessage {
                Text(localErrorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            if let authError = authService.errorMessage {
                Text(authError)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Section {
                Button(action: savePreferencesWithFrequency) {
                    HStack {
                        if isSaving {
                            ProgressView().padding(.trailing, 5)
                        }
                        Text(isSaving ? "Saving..." : "Save & Finish")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSaving)
                .padding()
                .background(Color.blue) // Changed to blue for distinction from previous save
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .navigationTitle("Update Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onAppear {
            // Initialize second time picker visibility based on current frequency
            showSecondTimePicker = (updateFrequency == 2)
            // Potentially load existing frequency preferences if they exist
            // For now, we default them.
        }
    }

    func savePreferencesWithFrequency() {
        localErrorMessage = nil
        authService.errorMessage = nil // Clear previous auth errors
        isSaving = true

        guard let uid = authService.user?.uid else {
            localErrorMessage = "Error: Not signed in."
            isSaving = false
            return
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Convert to UTC

        let firstUpdateTimeString = timeFormatter.string(from: firstUpdateTime)
        var secondUpdateTimeString: String? = nil
        if updateFrequency == 2 {
            secondUpdateTimeString = timeFormatter.string(from: secondUpdateTime)
        }

        var payload: [String: Any] = [
            "user_id": uid,
            "news_subjects": newsSubjects,
            "specific_research_topics": researchTopics,
            "news_detail_levels": newsDetailLevels,
            "research_detail_levels": researchDetailLevels,
            "structured_trackers": structuredTrackers,
            // Add new frequency fields
            "update_frequency": updateFrequency,
            "first_update_time": firstUpdateTimeString
        ]
        
        if let secondTime = secondUpdateTimeString {
            payload["second_update_time"] = secondTime
        }

        print("DEBUG: Full payload with frequency being sent: \(payload)")

        guard let url = URL(string: "https://us-central1-prysmios.cloudfunctions.net/set_user_preferences") else {
            localErrorMessage = "Error: Invalid server URL."
            isSaving = false
            return
        }

        Auth.auth().currentUser?.getIDTokenResult(forcingRefresh: false) { tokenResult, error in
            if let error = error {
                self.localErrorMessage = "Error getting auth token: \(error.localizedDescription)"
                self.isSaving = false
                return
            }
            
            guard let token = tokenResult?.token else {
                self.localErrorMessage = "Authentication token not available."
                self.isSaving = false
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
                request.httpBody = jsonData
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async {
                        self.isSaving = false
                        if let error = error {
                            self.localErrorMessage = "Error saving preferences: \(error.localizedDescription)"
                            return
                        }
                        guard let httpResponse = response as? HTTPURLResponse else {
                            self.localErrorMessage = "Invalid server response."
                            return
                        }
                        
                        if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                            print("DEBUG: Save Prefs with Freq Response (\(httpResponse.statusCode)): \(responseString)")
                        }

                        if httpResponse.statusCode == 200 {
                            print("DEBUG: Preferences with frequency saved successfully to backend.")
                            // Update local profile, including new frequency settings if needed
                            self.authService.updateLocalProfileForPrefCompletion(
                                originalNews: self.newsSubjects,
                                refinedNews: self.newsSubjects, // Assuming refinement happens earlier or not at all here
                                originalResearch: self.researchTopics,
                                refinedResearch: self.researchTopics,
                                newsDetails: self.newsDetailLevels,
                                researchDetails: self.researchDetailLevels
                                // Add frequency/time to local profile if your AuthService supports it
                            )
                            if var currentProfile = self.authService.userProfile {
                                // Convert structuredTrackers from [[String:String]] to [TrackedItem]
                                // This assumes TrackedItem has an initializer that can take a dictionary
                                // or you adjust how structuredTrackers are stored/passed.
                                // For now, let's assume it's handled or we adjust `structuredTrackers` prop type
                                // currentProfile.structuredTrackedItems = self.structuredTrackers.compactMap { TrackedItem(dictionary: $0) }
                                
                                // Add frequency details to local profile if UserProfile struct is updated
                                currentProfile.updateFrequency = self.updateFrequency
                                currentProfile.firstUpdateTime = firstUpdateTimeString
                                currentProfile.secondUpdateTime = secondUpdateTimeString
                                self.authService.userProfile = currentProfile
                            }
                            self.authService.markNewsPreferencesComplete()
                            
                            // Call the completion handler if provided
                            self.onPreferencesSaved?()
                            
                            // Dismiss this view
                            self.presentationMode.wrappedValue.dismiss()

                        } else {
                            self.localErrorMessage = "Failed to save preferences. Status: \(httpResponse.statusCode). \(String(data: data ?? Data(), encoding: .utf8) ?? "")"
                        }
                    }
                }.resume()
            } catch {
                DispatchQueue.main.async {
                    self.localErrorMessage = "Error preparing data for saving: \(error.localizedDescription)"
                    self.isSaving = false
                }
            }
        }
    }
}

struct UpdateFrequencyView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UpdateFrequencyView(
                newsSubjects: ["AI", "Climate Change"],
                newsDetailLevels: ["Detailed", "Medium"],
                researchTopics: ["Future of Work"],
                researchDetailLevels: ["Medium"],
                structuredTrackers: [["type": "assetPrice", "identifier": "AAPL", "competitionName": "Apple Inc."]]
            )
            .environmentObject(AuthService.shared)
        }
    }
}

// Note: You might need to add/update UserProfile in AuthService.swift
// to include:
// var updateFrequency: Int?
// var firstUpdateTime: String?
// var secondUpdateTime: String?
//
// And ensure TrackedItem can be initialized if converting from [[String:String]]
// or adjust the type of structuredTrackers passed to this view. 
