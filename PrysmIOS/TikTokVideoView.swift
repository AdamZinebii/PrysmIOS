import SwiftUI
import AVKit
import AVFoundation

struct TikTokVideoView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = VideoViewModel()
    @State private var currentVideoIndex = 0
    @State private var showingGenerateAlert = false
    @State private var isGenerating = false
    @State private var players: [AVPlayer] = []
    
    var body: some View {
        GeometryReader { geometry in
            mainContentView
        }
        .alert("Generate New Videos", isPresented: $showingGenerateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Generate") {
                generateVideos()
            }
        } message: {
            Text("This will create new videos from your latest news articles. This may take a few minutes.")
        }
        .onAppear {
            loadVideos()
        }
        .onChange(of: authService.user) { _ in
            loadVideos()
        }
        .onChange(of: viewModel.videos) { videos in
            setupPlayers(for: videos)
        }
    }
    
    // MARK: - Computed Views
    
    @ViewBuilder
    private var mainContentView: some View {
        if viewModel.isLoading {
            LoadingView()
        } else if viewModel.videos.isEmpty {
            EmptyStateView {
                generateVideos()
            }
        } else {
            videoTabView
        }
    }
    
    @ViewBuilder
    private var videoTabView: some View {
        TabView(selection: $currentVideoIndex) {
            ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                VideoPlayerView(
                    video: video,
                    player: index < players.count ? players[index] : nil,
                    isCurrentVideo: index == currentVideoIndex
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .ignoresSafeArea()
        .onChange(of: currentVideoIndex) { newIndex in
            playVideoAtIndex(newIndex)
        }
        .overlay(sideControlsOverlay)
    }
    
    @ViewBuilder
    private var sideControlsOverlay: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 20) {
                    generateVideosButton
                    refreshButton
                    clearCacheButton
                    Spacer()
                }
                .padding(.trailing, 20)
            }
            Spacer()
        }
    }
    
    private var generateVideosButton: some View {
        Button(action: {
            showingGenerateAlert = true
        }) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
                .shadow(radius: 3)
        }
    }
    
    private var refreshButton: some View {
        Button(action: {
            refreshVideos()
        }) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
                .shadow(radius: 3)
        }
    }
    
    private var clearCacheButton: some View {
        Button(action: {
            clearVideoCache()
        }) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
                .shadow(radius: 3)
        }
    }
    
    // MARK: - Methods
    
    private func setupPlayers(for videos: [VideoItem]) {
        // Pause and clear existing players
        players.forEach { $0.pause() }
        players.removeAll()
        
        // Create new players for each video
        players = videos.map { video in
            guard let url = URL(string: video.url) else {
                return AVPlayer()
            }
            return AVPlayer(url: url)
        }
        
        // Start playing the first video
        if !players.isEmpty {
            playVideoAtIndex(currentVideoIndex)
        }
    }
    
    private func playVideoAtIndex(_ index: Int) {
        // Pause all players first
        players.forEach { $0.pause() }
        
        // Play the selected video
        if index < players.count {
            players[index].seek(to: .zero)
            players[index].play()
        }
    }
    
    private func loadVideos() {
        guard let userId = authService.user?.uid else { return }
        Task {
            await viewModel.loadVideos(userId: userId)
        }
    }
    
    private func refreshVideos() {
        guard let userId = authService.user?.uid else { return }
        Task {
            await viewModel.loadVideos(userId: userId)
        }
    }
    
    private func generateVideos() {
        guard let userId = authService.user?.uid else { return }
        isGenerating = true
        Task {
            await viewModel.generateVideos(userId: userId)
            isGenerating = false
            // Reload videos after generation
            await viewModel.loadVideos(userId: userId)
        }
    }
    
    private func clearVideoCache() {
        guard let userId = authService.user?.uid else { return }
        Task {
            await viewModel.clearVideoCache(userId: userId)
            await viewModel.loadVideos(userId: userId)
        }
    }
}

struct VideoPlayerView: View {
    let video: VideoItem
    let player: AVPlayer?
    let isCurrentVideo: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fit)
                        .onTapGesture {
                            togglePlayback()
                        }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                }
                
                // Video info overlay
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(video.article_title)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                                .shadow(radius: 3)
                            
                            Text(formatDate(video.created_at))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(radius: 3)
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(2)
            
            Text("Loading videos...")
                .font(.title2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct EmptyStateView: View {
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 16) {
                Text("No Videos Yet")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Generate your first videos from your news articles")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: onGenerate) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Generate Videos")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - ViewModel

@MainActor
class VideoViewModel: ObservableObject {
    @Published var videos: [VideoItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = VideoAPIService.shared
    
    func loadVideos(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.getUserVideoCache(userId: userId)
            videos = response.videos.sorted { $0.created_at > $1.created_at }
            print("Loaded \(videos.count) videos")
        } catch {
            errorMessage = "Failed to load videos: \(error.localizedDescription)"
            print("Error loading videos: \(error)")
        }
        
        isLoading = false
    }
    
    func generateVideos(userId: String) async {
        do {
            let response = try await apiService.generateArticleVideos(userId: userId)
            print("Generated videos: \(response)")
        } catch {
            errorMessage = "Failed to generate videos: \(error.localizedDescription)"
            print("Error generating videos: \(error)")
        }
    }
    
    func clearVideoCache(userId: String) async {
        do {
            let success = try await apiService.clearUserVideoCache(userId: userId)
            if success {
                videos = []
                print("Video cache cleared")
            } else {
                errorMessage = "Failed to clear video cache"
            }
        } catch {
            errorMessage = "Failed to clear video cache: \(error.localizedDescription)"
            print("Error clearing video cache: \(error)")
        }
    }
}

struct TikTokVideoView_Previews: PreviewProvider {
    static var previews: some View {
        TikTokVideoView()
            .environmentObject(AuthService.shared)
    }
} 