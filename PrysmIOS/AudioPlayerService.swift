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
    private var isRemoteControlsConfigured = false
    
    // Logging service
    private let loggingService = LoggingService.shared
    
    // Track previous time for seeking
    private var previousSeekTime: Double = 0.0

    private init() {
        configureAudioSession()
        setupNotificationObservers()
    }

    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try audioSession.setActive(true)
            print("🎵 Audio session configured for playback")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    private func setupNotificationObservers() {
        // Audio session interruption notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        // Audio session route change notifications (for headphone connect/disconnect)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        print("🔔 Audio session notification observers configured")
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔕 Audio session interrupted (call, other app, etc.)")
            // Audio is automatically paused by the system
            DispatchQueue.main.async {
                self.isPlaying = false
                self.updateNowPlayingInfo()
            }
            
        case .ended:
            print("🔔 Audio session interruption ended")
            
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("📱 System suggests resuming playback")
                    // Resume playback automatically
                    DispatchQueue.main.async {
                        self.player?.play()
                    }
                }
            }
            
        @unknown default:
            print("⚠️ Unknown audio session interruption type")
        }
    }
    
    @objc private func handleAudioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones disconnected - pause playback
            print("🎧 Headphones disconnected - pausing playback")
            DispatchQueue.main.async {
                self.player?.pause()
            }
            
        case .newDeviceAvailable:
            print("🎧 New audio device connected")
            // Continue playback on the new device
            
        case .categoryChange:
            print("🔄 Audio category changed")
            
        default:
            print("🔄 Audio route changed: \(reason.rawValue)")
        }
    }

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
            
            // FORCE configure remote controls IMMEDIATELY when audio is loaded
            setupRemoteTransportControls()
            isRemoteControlsConfigured = true
            
            // FORCE activate audio session and ensure it's ready for background
            configureAudioSessionForBackground()
            
            observePlayerState()
            observeItemDuration(playerItem: playerItem)
            
            // Immediately update Now Playing Info even before playing
            updateNowPlayingInfo()
            
            print("🎵 AudioPlayerService: Audio loaded and remote controls configured for: \(urlString)")
        } else {
            player?.play()
        }
    }
    
    private func configureAudioSessionForBackground() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [
                .allowAirPlay,
                .allowBluetooth,
                .allowBluetoothA2DP
            ])
            try audioSession.setActive(true)
            print("🎵 Audio session activated for background playback")
        } catch {
            print("❌ Failed to configure audio session for background: \(error)")
        }
    }

    private func observePlayerState() {
        timeControlStatusObserver = player?.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] avplayer, _ in
            DispatchQueue.main.async {
                switch avplayer.timeControlStatus {
                case .playing:
                    self?.isPlaying = true
                    self?.isLoading = false
                    self?.updateNowPlayingInfo()
                    
                    // Log podcast play
                    if let self = self {
                        self.loggingService.logPodcastPlayed(
                            podcastUrl: self.currentUrl?.absoluteString,
                            duration: self.duration
                        )
                    }
                case .paused:
                    self?.isPlaying = false
                    self?.isLoading = false
                    self?.updateNowPlayingInfo()
                    
                    // Log podcast pause
                    if let self = self {
                        self.loggingService.logPodcastPaused(
                            currentTime: self.currentTime,
                            totalDuration: self.duration
                        )
                    }
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
                // Update Now Playing Info less frequently to avoid performance issues
                if Int(currentTimeSeconds) % 2 == 0 {
                    self.updateNowPlayingInfo()
                }
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
    
    func skipForward(_ seconds: Double = 15.0) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    func skipBackward(_ seconds: Double = 15.0) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        // Log the seek action
        loggingService.logPodcastSeeked(
            fromTime: currentTime,
            toTime: time
        )
        
        player.seek(to: cmTime) { [weak self] finished in
            if finished {
                print("AudioPlayerService: Seek completed to \(time) seconds")
                DispatchQueue.main.async {
                    self?.currentTime = time
                    self?.updateNowPlayingInfo()
                }
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

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        print("🎛️ Configuring remote transport controls...")
        
        // Clear all existing targets first
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)

        // Enable and configure play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self, let player = self.player else { 
                print("❌ Play command failed - no player available")
                return .commandFailed 
            }
            if !self.isPlaying {
                player.play()
                print("▶️ Remote play command executed successfully")
                DispatchQueue.main.async {
                    self.updateNowPlayingInfo()
                }
                return .success
            }
            return .commandFailed
        }

        // Enable and configure pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self, let player = self.player else { 
                print("❌ Pause command failed - no player available")
                return .commandFailed 
            }
            if self.isPlaying {
                player.pause()
                print("⏸️ Remote pause command executed successfully")
                DispatchQueue.main.async {
                    self.updateNowPlayingInfo()
                }
                return .success
            }
            return .commandFailed
        }
        
        // Enable and configure skip forward command (15 seconds)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if let skipEvent = event as? MPSkipIntervalCommandEvent {
                self.skipForward(skipEvent.interval)
            } else {
                self.skipForward(15.0)
            }
            print("⏭️ Remote skip forward command executed (15s)")
            return .success
        }
        
        // Enable and configure skip backward command (15 seconds)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if let skipEvent = event as? MPSkipIntervalCommandEvent {
                self.skipBackward(skipEvent.interval)
            } else {
                self.skipBackward(15.0)
            }
            print("⏮️ Remote skip backward command executed (15s)")
            return .success
        }
        
        // Enable and configure scrubbing support for lock screen
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            self.seek(to: positionEvent.positionTime)
            print("🔄 Remote seek command executed to: \(positionEvent.positionTime)s")
            return .success
        }
        
        // DISABLE next/previous track commands since we have a single podcast
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        
        // ENABLE stop command
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.stopAudio()
            print("⏹️ Remote stop command executed")
            return .success
        }
        
        print("✅ Remote transport controls configured successfully with all commands enabled")
    }

    private func updateNowPlayingInfo(isStopping: Bool = false) {
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        
        if isStopping || player == nil {
            nowPlayingInfoCenter.nowPlayingInfo = nil
            print("🧹 Cleared Now Playing Info")
            return
        }

        var nowPlayingInfo = [String: Any]()
        
        // Basic media information - IMPORTANT for Control Center display
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Your Daily News Briefing"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Orel AI"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Daily Podcast"
        nowPlayingInfo[MPMediaItemPropertyGenre] = "News & Politics"
        
        // Add playback information - CRITICAL for Control Center
        if duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            print("📊 Set playback duration: \(Int(duration))s")
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // Media type - helps iOS identify this as a podcast
        nowPlayingInfo[MPMediaItemPropertyMediaType] = MPMediaType.podcast.rawValue
        
        // Add episode number and season (helps with podcast identification)
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = 1
        nowPlayingInfo[MPMediaItemPropertyAlbumTrackCount] = 1
        
        // Add artwork - IMPORTANT for visual identification
        if let appIcon = UIImage(named: "AppIcon") ?? UIImage(named: "orel_logo") {
            let artwork = MPMediaItemArtwork(boundsSize: appIcon.size) { size in
                return appIcon
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            print("🎨 Set artwork from app icon")
        } else {
            // Create a distinctive artwork if no app icon
            let artworkSize = CGSize(width: 400, height: 400)
            let renderer = UIGraphicsImageRenderer(size: artworkSize)
            let artwork = renderer.image { context in
                // Create a professional gradient background
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [
                                            UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0).cgColor,
                                            UIColor(red: 0.4, green: 0.2, blue: 0.7, alpha: 1.0).cgColor
                                        ] as CFArray,
                                        locations: [0.0, 1.0])!
                context.cgContext.drawLinearGradient(gradient,
                                                   start: CGPoint(x: 0, y: 0),
                                                   end: CGPoint(x: artworkSize.width, y: artworkSize.height),
                                                   options: [])
                
                // Add professional text
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 60, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraphStyle
                ]
                
                let subtitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                    .paragraphStyle: paragraphStyle
                ]
                
                let titleText = "OREL"
                let subtitleText = "AI NEWS"
                
                let titleRect = CGRect(x: 0, y: artworkSize.height/2 - 60, width: artworkSize.width, height: 80)
                let subtitleRect = CGRect(x: 0, y: artworkSize.height/2 + 20, width: artworkSize.width, height: 40)
                
                titleText.draw(in: titleRect, withAttributes: titleAttributes)
                subtitleText.draw(in: subtitleRect, withAttributes: subtitleAttributes)
            }
            
            let mediaArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { size in
                return artwork
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork
            print("🎨 Created custom artwork")
        }

        // Set the Now Playing Info
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
        
        print("📱 Updated Now Playing Info - Title: 'Your Daily News Briefing', Playing: \(isPlaying), Time: \(Int(currentTime))s/\(Int(duration))s")
        print("🎛️ Control Center should now display the player!")
    }

    deinit {
        timeControlStatusObserver?.invalidate()
        currentItemStatusObserver?.invalidate()
        if let periodicObserver = periodicTimeObserver {
            player?.removeTimeObserver(periodicObserver)
        }
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        
        // Clear remote commands
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        
        // Clear now playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        print("AudioPlayerService deinitialized")
    }
} 