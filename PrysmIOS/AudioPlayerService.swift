import Foundation
import AVFoundation
import Combine
import MediaPlayer

class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()
    
    private var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0

    private var cancellables = Set<AnyCancellable>()
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var currentItemStatusObserver: NSKeyValueObservation?
    private var durationObserver: NSKeyValueObservation?
    private var periodicTimeObserver: Any?
    private var currentUrl: URL?

    private init() {}

    func playAudio(from urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            errorMessage = "Invalid audio URL"
            return
        }

        if url == currentUrl && player?.timeControlStatus == .playing {
            player?.pause()
            return
        }
        
        if url != currentUrl {
            player?.pause()
            resetPlaybackState()
            
            isLoading = true
            currentUrl = url
            let playerItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: playerItem)
            
            observePlayerState()
            observeItemDuration(playerItem: playerItem)
        } else {
            player?.play()
        }
    }

    private func observePlayerState() {
        timeControlStatusObserver = player?.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] avplayer, _ in
            DispatchQueue.main.async {
                switch avplayer.timeControlStatus {
                case .playing:
                    self?.isPlaying = true
                    self?.isLoading = false
                case .paused:
                    self?.isPlaying = false
                    self?.isLoading = false
                case .waitingToPlayAtSpecifiedRate:
                    if let error = avplayer.error {
                        self?.isPlaying = false
                        self?.isLoading = false
                        self?.errorMessage = "Error playing audio: \(error.localizedDescription)"
                         print("Player error: \(error.localizedDescription)")
                    } else {
                         self?.isLoading = true
                    }
                @unknown default:
                    self?.isPlaying = false
                    self?.isLoading = false
                }
            }
        }
    }
    
    private func observeItemDuration(playerItem: AVPlayerItem) {
        currentItemStatusObserver = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self = self else { return }
            if item.status == .readyToPlay {
                let durationSeconds = CMTimeGetSeconds(item.duration)
                DispatchQueue.main.async {
                    self.duration = durationSeconds > 0 ? durationSeconds : 0.0
                    print("AudioPlayerService: Duration set to \(self.duration) seconds")
                    self.updateNowPlayingInfo()
                }
                self.setupPeriodicTimeObserver()
            } else if item.status == .failed {
                DispatchQueue.main.async {
                    self.errorMessage = item.error?.localizedDescription ?? "Failed to load audio item."
                    self.isLoading = false
                }
            }
        }
    }

    private func setupPeriodicTimeObserver() {
        if let existingObserver = periodicTimeObserver {
            player?.removeTimeObserver(existingObserver)
            periodicTimeObserver = nil
        }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        periodicTimeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let currentTimeSeconds = CMTimeGetSeconds(time)
            if self.duration > 0 {
                self.currentTime = currentTimeSeconds
                self.updateNowPlayingInfo()
            }
        }
    }

    func pauseAudio() {
        player?.pause()
    }

    func stopAudio() {
        player?.pause()
        player = nil
        resetPlaybackState()
        updateNowPlayingInfo(isStopping: true)
        if let existingObserver = periodicTimeObserver {
            periodicTimeObserver = nil
        }
        print("AudioPlayerService: Audio stopped and player reset.")
    }
    
    // MARK: - Audio Player Controls
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func skipForward(_ seconds: Double) {
        guard let player = player else { return }
        
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = min(currentTime + seconds, duration)
        let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
        
        player.seek(to: targetTime) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateNowPlayingInfo()
            }
        }
    }
    
    func skipBackward(_ seconds: Double) {
        guard let player = player else { return }
        
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = max(currentTime - seconds, 0)
        let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
        
        player.seek(to: targetTime) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateNowPlayingInfo()
            }
        }
    }
    
    func seek(to timeInSeconds: Double) {
        guard let player = player else { return }
        
        let targetTime = CMTime(seconds: timeInSeconds, preferredTimescale: 600)
        player.seek(to: targetTime) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateNowPlayingInfo()
            }
        }
    }
    
    var isPlayerAvailable: Bool {
        return player != nil && duration > 0
    }
    
    private func resetPlaybackState() {
        isPlaying = false
        isLoading = false
        currentTime = 0.0
        duration = 0.0
        
        currentItemStatusObserver?.invalidate()
        currentItemStatusObserver = nil
    }

    // MARK: - MPRemoteCommandCenter & MPNowPlayingInfoCenter

    func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying {
                self.player?.play()
                return .success
            }
            return .commandFailed
        }

        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.player?.pause()
                return .success
            }
            return .commandFailed
        }
        
        // Optionnel: ajouter d'autres commandes comme next/previous si pertinent
        // commandCenter.nextTrackCommand.addTarget { ... }
        // commandCenter.previousTrackCommand.addTarget { ... }
        print("AudioPlayerService: Remote transport controls configured.")
    }

    func updateNowPlayingInfo(isStopping: Bool = false) {
        var nowPlayingInfo = [String: Any]()
        
        if isStopping || player == nil {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            print("AudioPlayerService: Cleared Now Playing Info.")
            return
        }

        // Utiliser un titre générique pour l'instant
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Prysm News Summary"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "PrysmIOS"
        
        // Placeholder pour l'artwork, vous pourrez l'ajouter plus tard
        // if let image = UIImage(named: "AppIcon") { // Assurez-vous que "AppIcon" est dans vos assets
        //     nowPlayingInfo[MPMediaItemPropertyArtwork] = 
        //         MPMediaItemArtwork(boundsSize: image.size) { size in
        //             return image
        //         }
        // }

        if duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("AudioPlayerService: Updated Now Playing Info - Time: \(currentTime), Duration: \(duration)")
    }

    deinit {
        timeControlStatusObserver?.invalidate()
        currentItemStatusObserver?.invalidate()
        if let periodicObserver = periodicTimeObserver {
            player?.removeTimeObserver(periodicObserver)
        }
        print("AudioPlayerService deinitialized")
    }
} 