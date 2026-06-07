import AVFoundation
import SwiftUI

struct DramaPlaybackView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var playbackManager: PlaybackManager

    let drama: Drama
    @State private var selectedEpisodeNumber: Int?
    @State private var isVisible = false
    @State private var playbackOwnerID = UUID()
    @State private var fullscreenPlayback: FullscreenPlayback?
    @State private var lockedEpisodeNumber: Int?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if fullscreenPlayback == nil {
                VerticalPager(items: drama.episodes, selection: selectedEpisodePosition) { episode in
                    EpisodePage(
                        drama: drama,
                        episode: episode,
                        isActive: isVisible &&
                            lockedEpisodeNumber == nil &&
                            selectedEpisodeNumber == episode.episodeNumber,
                        presentFullscreen: presentFullscreen
                    )
                }
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.45), in: Circle())
                    }

                    Spacer()

                    PlaybackRateMenu()
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(item: $fullscreenPlayback, onDismiss: resumeAfterFullscreen) { playback in
            LandscapePlayerView(drama: playback.drama, episode: playback.episode)
        }
        .onAppear {
            isVisible = true
            if selectedEpisodeNumber == nil {
                let preferred = playbackManager.preferredEpisodeNumber(for: drama.dramaId)
                selectedEpisodeNumber = drama.episodes.contains(where: { $0.episodeNumber == preferred })
                    ? preferred
                    : drama.episodes.first?.episodeNumber
            }
            activateSelectedEpisode()
        }
        .onDisappear {
            isVisible = false
            playbackManager.pause(ownerID: playbackOwnerID)
        }
        .onChange(of: selectedEpisodeNumber) {
            activateSelectedEpisode()
        }
    }

    private func activateSelectedEpisode() {
        guard isVisible, lockedEpisodeNumber == nil,
              let selectedEpisodeNumber,
              let episode = drama.episodes.first(where: { $0.episodeNumber == selectedEpisodeNumber }) else {
            return
        }
        playbackManager.play(drama: drama, episode: episode, ownerID: playbackOwnerID)
    }

    private func presentFullscreen(drama: Drama, episode: Episode) {
        lockedEpisodeNumber = episode.episodeNumber
        selectedEpisodeNumber = episode.episodeNumber
        fullscreenPlayback = FullscreenPlayback(drama: drama, episode: episode)
    }

    private func resumeAfterFullscreen() {
        guard let lockedEpisodeNumber,
              let episode = drama.episodes.first(where: { $0.episodeNumber == lockedEpisodeNumber }) else {
            return
        }

        isVisible = true
        selectedEpisodeNumber = lockedEpisodeNumber
        playbackManager.play(drama: drama, episode: episode, ownerID: playbackOwnerID)
        self.lockedEpisodeNumber = nil
    }

    private var selectedEpisodePosition: Binding<Int?> {
        Binding(
            get: { selectedEpisodeNumber },
            set: { newValue in
                guard lockedEpisodeNumber == nil else { return }
                selectedEpisodeNumber = newValue
            }
        )
    }
}

private struct EpisodePage: View {
    let drama: Drama
    let episode: Episode
    let isActive: Bool
    let presentFullscreen: (Drama, Episode) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black

            VStack(spacing: 16) {
                Spacer(minLength: 0)

                PlaybackCanvas(
                    drama: drama,
                    episode: episode,
                    isActive: isActive,
                    gravity: episode.aspectRatio < 1 ? .resizeAspectFill : .resizeAspect
                )
                .aspectRatio(max(episode.aspectRatio, 0.2), contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()

                if episode.aspectRatio >= 4.0 / 3.0 {
                    Button {
                        presentFullscreen(drama, episode)
                    } label: {
                        Label("全屏观看", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.15), in: Capsule())
                    }
                }

                Spacer(minLength: 80)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 8) {
                Text(drama.title)
                    .font(.headline)
                Text(episodeInfoText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))

                PlaybackProgressControl(
                    isActive: isActive,
                    fallbackDuration: episode.duration
                )
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
    }

    private var episodeInfoText: String {
        let progress = "第\(episode.episodeNumber)集 / 共\(drama.totalEpisodes)集"
        let defaultTitle = "第\(episode.episodeNumber)集"
        let title = episode.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty || title == defaultTitle {
            return "\(progress) · \(episode.duration.playbackTimeText)"
        }
        return "\(title) · \(progress) · \(episode.duration.playbackTimeText)"
    }
}

private struct PlaybackRateMenu: View {
    @EnvironmentObject private var playbackManager: PlaybackManager
    private let rates: [Float] = [0.75, 1, 1.25, 1.5, 2, 3]

    var body: some View {
        Menu {
            ForEach(rates, id: \.self) { rate in
                Button {
                    playbackManager.setRate(rate)
                } label: {
                    if playbackManager.playbackRate == rate {
                        Label(rateText(rate), systemImage: "checkmark")
                    } else {
                        Text(rateText(rate))
                    }
                }
            }
        } label: {
            Text("倍速 \(rateText(playbackManager.playbackRate))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .frame(height: 42)
                .background(.black.opacity(0.45), in: Capsule())
        }
    }

    private func rateText(_ rate: Float) -> String {
        rate == 1 ? "1.0x" : "\(rate.formatted())x"
    }
}
