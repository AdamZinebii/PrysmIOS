import SwiftUI

struct TrackersListView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let profile = authService.userProfile, !profile.structuredTrackedItems.isEmpty {
                    // Section Sports
                    if hasSportsTrackers(profile) {
                        sportsSection(profile)
                    }
                    
                    // Section Finance
                    if hasFinanceTrackers(profile) {
                        financeSection(profile)
                    }
                } else if authService.isLoadingProfile {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("You haven't added any specific trackers yet. Go to Profile > Edit Preferences to add some.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("My Trackers")
    }
    
    private func hasSportsTrackers(_ profile: UserProfile) -> Bool {
        profile.structuredTrackedItems.contains { item in
            item.type == .leagueSchedule || item.type == .leagueStanding
        }
    }
    
    private func hasFinanceTrackers(_ profile: UserProfile) -> Bool {
        profile.structuredTrackedItems.contains { item in
            item.type == .assetPrice
        }
    }
    
    private func sportsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sports")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 4)
            
            ForEach(profile.structuredTrackedItems.filter { $0.type == .leagueSchedule || $0.type == .leagueStanding }) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: iconName(for: item.type))
                            .foregroundColor(iconColor(for: item.type))
                        Text(item.competitionName ?? item.identifier)
                            .font(.headline)
                            .onAppear {
                                print("DEBUG: Item details:")
                                print("  - Type: \(item.type)")
                                print("  - ID: \(item.identifier)")
                                print("  - Competition Name: \(item.competitionName ?? "nil")")
                            }
                    }
                    
                    if item.type == .leagueSchedule {
                        LeagueScheduleView(leagueId: item.identifier)
                            .frame(height: 200)
                    } else if item.type == .leagueStanding {
                        LeagueStandingView(leagueId: item.identifier)
                            .frame(height: 200)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
        }
    }
    
    private func financeSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finance")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 4)
            
            ForEach(profile.structuredTrackedItems.filter { $0.type == .assetPrice }) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: iconName(for: item.type))
                            .foregroundColor(iconColor(for: item.type))
                        Text(displayName(for: item))
                            .font(.headline)
                    }
                    
                    AssetPriceView(symbol: item.identifier)
                        .frame(height: 200)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
        }
    }
    
    private func displayName(for item: TrackedItem) -> String {
        switch item.type {
        case .leagueSchedule, .leagueStanding:
            return LeagueManager.shared.getLeagueName(for: item.identifier)
        case .assetPrice:
        return item.identifier
        }
    }
    
    private func iconName(for type: TrackedItem.TrackedItemType) -> String {
        switch type {
        case .leagueSchedule: return "list.star"
        case .leagueStanding: return "list.number"
        case .assetPrice: return "chart.line.uptrend.xyaxis"
        }
    }
    
    private func iconColor(for type: TrackedItem.TrackedItemType) -> Color {
        switch type {
        case .leagueSchedule: return .orange
        case .leagueStanding: return .blue
        case .assetPrice: return .green
        }
    }
}

struct TrackersListView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = AuthService.shared
        authService.userProfile = UserProfile(id: "previewUser", firstName: "Test", surname: "User")
        authService.userProfile?.structuredTrackedItems = [
            TrackedItem(type: .leagueStanding, identifier: "PL"),
            TrackedItem(type: .assetPrice, identifier: "AAPL"),
            TrackedItem(type: .leagueSchedule, identifier: "CL")
        ]
        
        return NavigationView {
            TrackersListView()
                .environmentObject(authService)
        }
    }
} 