import AVFoundation
import SwiftUI
import UIKit

struct LandscapePlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var playbackManager: PlaybackManager

    let drama: Drama
    let episode: Episode

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PlayerView(player: playbackManager.player, gravity: .resizeAspect)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Label("退出全屏", systemImage: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                            .background(.black.opacity(0.5), in: Capsule())
                    }
                    Spacer()
                }
                .padding()

                Spacer()

                HStack(spacing: 14) {
                    Button {
                        playbackManager.togglePlayback()
                    } label: {
                        Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }

                    Text(playbackManager.currentTime.playbackTimeText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)

                    Slider(
                        value: Binding(
                            get: { playbackManager.currentTime },
                            set: { playbackManager.seek(to: $0) }
                        ),
                        in: 0...max(playbackManager.duration, 1)
                    )
                    .tint(.red)

                    Text(playbackManager.duration.playbackTimeText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(.black.opacity(0.5))
            }
        }
        .onAppear {
            OrientationManager.set(.landscape)
            playbackManager.play(drama: drama, episode: episode)
        }
        .onDisappear {
            OrientationManager.set(.portrait)
        }
    }
}

enum OrientationManager {
    static func set(_ orientations: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = orientations
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
