import SwiftUI

struct PlayPauseProgressControl: View {
    @ObservedObject var audioPlayerService: AudioPlayerService
    var action: () -> Void // Action to perform on tap (play/pause)
    
    var buttonSize: CGFloat = 28 // Size of the tappable area / icon
    var progressRingWidth: CGFloat = 2.5 // Width of the progress ring
    
    private var progress: Double {
        if audioPlayerService.duration > 0 {
            return audioPlayerService.currentTime / audioPlayerService.duration
        }
        return 0
    }
    
    var body: some View {
        ZStack {
            // Background Ring for the progress bar
            Circle()
                .stroke(lineWidth: progressRingWidth)
                .opacity(0.2)
                .foregroundColor(Color.gray)

            // Foreground Ring representing the progress
            Circle()
                .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: progressRingWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.accentColor) // Use accent color or a custom one
                .rotationEffect(Angle(degrees: 270.0)) // Start from the top
                //.animation(.linear, value: progress) // Animate progress changes

            if audioPlayerService.isLoading && audioPlayerService.duration == 0 {
                ProgressView() // Indeterminate progress if loading and duration unknown
                     .frame(width: buttonSize * 0.8, height: buttonSize * 0.8)
            } else {
                Button(action: action) {
                    Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: buttonSize * 0.55)) // Adjust icon size relative to button
                        .frame(width: buttonSize, height: buttonSize)
                        //.foregroundColor(Color.primary) // Ensure good contrast
                }
                .buttonStyle(PlainButtonStyle()) // To ensure ZStack tap works correctly and no default button styling interferes
            }
        }
        .frame(width: buttonSize + progressRingWidth * 2, height: buttonSize + progressRingWidth * 2) // Total size of the control
    }
}

// Preview (optional, for development)
// struct PlayPauseProgressControl_Previews: PreviewProvider {
//     static var previews: some View {
//         // Create a mock AudioPlayerService for preview
//         let mockAudioPlayer = AudioPlayerService.shared // Use shared if it has default states
//         // You might want to set some states for preview if needed:
//         // mockAudioPlayer.isPlaying = true
//         // mockAudioPlayer.currentTime = 15
//         // mockAudioPlayer.duration = 60
//         // mockAudioPlayer.isLoading = false
//
//         PlayPauseProgressControl(audioPlayerService: mockAudioPlayer, action: {
//             print("Preview button tapped")
//             mockAudioPlayer.isPlaying.toggle()
//             // Simulate progress for preview
//             if mockAudioPlayer.isPlaying {
//                 mockAudioPlayer.duration = 60
//                 mockAudioPlayer.currentTime = (mockAudioPlayer.currentTime + 5).truncatingRemainder(dividingBy: 60)
//             }
//         })
//         .padding()
//     }
// } 