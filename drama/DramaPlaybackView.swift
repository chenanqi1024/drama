import AVFoundation
import SwiftUI

struct DramaPlaybackView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var playbackManager: PlaybackManager

    let drama: Drama
    @State private var selectedEpisodeNumber: Int?
    @State private var isVisible = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(drama.episodes) { episode in
                            EpisodePage(
                                drama: drama,
                                episode: episode,
                                isActive: isVisible && selectedEpisodeNumber == episode.episodeNumber
                            )
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .id(episode.episodeNumber)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $selectedEpisodeNumber)

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
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
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
            playbackManager.pause()
        }
        .onChange(of: selectedEpisodeNumber) {
            activateSelectedEpisode()
        }
    }

    private func activateSelectedEpisode() {
        guard isVisible,
              let selectedEpisodeNumber,
              let episode = drama.episodes.first(where: { $0.episodeNumber == selectedEpisodeNumber }) else {
            return
        }
        playbackManager.play(drama: drama, episode: episode)
    }
}

private struct EpisodePage: View {
    @EnvironmentObject private var playbackManager: PlaybackManager

    let drama: Drama
    let episode: Episode
    let isActive: Bool
    @State private var showsFullscreen = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black

            VStack(spacing: 16) {
                Spacer(minLength: 0)

                PlaybackCanvas(
                    drama: drama,
                    episode: episode,
                    isActive: isActive && !showsFullscreen,
                    gravity: episode.aspectRatio < 1 ? .resizeAspectFill : .resizeAspect
                )
                .aspectRatio(max(episode.aspectRatio, 0.2), contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()

                if episode.aspectRatio >= 4.0 / 3.0 {
                    Button {
                        showsFullscreen = true
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
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
        .fullScreenCover(isPresented: $showsFullscreen) {
            LandscapePlayerView(drama: drama, episode: episode)
        }
        .onChange(of: showsFullscreen) {
            if !showsFullscreen, isActive {
                playbackManager.play(drama: drama, episode: episode)
            }
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
