import AVFoundation
import SwiftUI

struct PlayerView: UIViewRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = gravity
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Void) {
        uiView.playerLayer.player = nil
    }
}

final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

struct PlaybackCanvas: View {
    @EnvironmentObject private var playbackManager: PlaybackManager

    let drama: Drama
    let episode: Episode
    let isActive: Bool
    var gravity: AVLayerVideoGravity = .resizeAspect

    private var isCurrentPlayback: Bool {
        playbackManager.currentDramaId == drama.dramaId &&
            playbackManager.currentEpisodeNumber == episode.episodeNumber
    }

    var body: some View {
        ZStack {
            Color.black

            if isActive && isCurrentPlayback {
                PlayerView(player: playbackManager.player, gravity: gravity)
                    .id("\(drama.dramaId)#\(episode.episodeNumber)")
            } else {
                RemotePoster(path: drama.poster, contentMode: .fit)
            }

            Button {
                playbackManager.togglePlayback()
            } label: {
                Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .opacity(isActive && isCurrentPlayback && !playbackManager.isPlaying ? 1 : 0.001)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isActive, isCurrentPlayback else { return }
            playbackManager.togglePlayback()
        }
    }
}

struct PlaybackProgressControl: View {
    @EnvironmentObject private var playbackManager: PlaybackManager

    let isActive: Bool
    let fallbackDuration: Double
    var showsTimes = true

    @State private var isSeeking = false
    @State private var seekTime: Double = 0

    private var duration: Double {
        guard isActive else { return max(fallbackDuration, 1) }
        return max(playbackManager.duration, fallbackDuration, 1)
    }

    private var displayedTime: Double {
        guard isActive else { return 0 }
        return isSeeking ? seekTime : playbackManager.currentTime
    }

    var body: some View {
        HStack(spacing: 10) {
            if showsTimes {
                Text(displayedTime.playbackTimeText)
                    .frame(width: 42, alignment: .leading)
            }

            Slider(
                value: Binding(
                    get: { min(displayedTime, duration) },
                    set: {
                        seekTime = $0
                        if isActive {
                            isSeeking = true
                        }
                    }
                ),
                in: 0...duration,
                onEditingChanged: handleEditingChanged
            )
            .tint(.red)
            .disabled(!isActive)

            if showsTimes {
                Text(duration.playbackTimeText)
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.white.opacity(isActive ? 0.9 : 0.45))
    }

    private func handleEditingChanged(_ editing: Bool) {
        guard isActive else { return }

        if editing {
            if !isSeeking {
                seekTime = playbackManager.currentTime
            }
            isSeeking = true
        } else {
            playbackManager.seek(to: seekTime)
            isSeeking = false
        }
    }
}

struct RemotePoster: View {
    let path: String
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: MediaURL.resolve(path)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder
            case .empty:
                ZStack {
                    placeholder
                    ProgressView()
                        .tint(.white)
                }
            @unknown default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: "play.rectangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}

extension Double {
    var playbackTimeText: String {
        guard isFinite else { return "00:00" }
        let value = max(Int(self), 0)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
