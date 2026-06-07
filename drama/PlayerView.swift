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

    var body: some View {
        ZStack {
            Color.black

            if isActive {
                PlayerView(player: playbackManager.player, gravity: gravity)
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
            .opacity(isActive && !playbackManager.isPlaying ? 1 : 0.001)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isActive else { return }
            playbackManager.togglePlayback()
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
