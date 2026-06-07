import AVFoundation
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: DramaStore
    @EnvironmentObject private var playbackManager: PlaybackManager
    @State private var selectedDramaId: String?
    @State private var isVisible = false
    @State private var playbackOwnerID = UUID()
    @State private var fullscreenPlayback: FullscreenPlayback?
    @State private var lockedDramaId: String?

    var body: some View {
        Group {
            if store.isLoading && store.homeDramas.isEmpty {
                LoadingView()
            } else if let errorMessage = store.errorMessage, store.homeDramas.isEmpty {
                LoadErrorView(message: errorMessage) {
                    Task { await store.load() }
                }
            } else if fullscreenPlayback != nil {
                Color.black
            } else {
                VerticalPager(items: store.homeDramas, selection: selectedDramaPosition) { drama in
                    HomeDramaPage(
                        drama: drama,
                        isActive: isVisible &&
                            lockedDramaId == nil &&
                            selectedDramaId == drama.id,
                        presentFullscreen: presentFullscreen
                    )
                }
                .background(.black)
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $fullscreenPlayback, onDismiss: resumeAfterFullscreen) { playback in
            LandscapePlayerView(drama: playback.drama, episode: playback.episode)
        }
        .onAppear {
            isVisible = true
            if selectedDramaId == nil {
                selectedDramaId = store.homeDramas.first?.id
            }
            activateSelectedDrama()
        }
        .onDisappear {
            isVisible = false
            playbackManager.pause(ownerID: playbackOwnerID)
        }
        .onChange(of: selectedDramaId) {
            activateSelectedDrama()
        }
        .onChange(of: store.homeDramas) {
            if selectedDramaId == nil {
                selectedDramaId = store.homeDramas.first?.id
                activateSelectedDrama()
            }
        }
    }

    private func activateSelectedDrama() {
        guard isVisible, lockedDramaId == nil,
              let selectedDramaId,
              let drama = store.homeDramas.first(where: { $0.id == selectedDramaId }),
              let episode = drama.episodes.first else {
            return
        }
        playbackManager.play(drama: drama, episode: episode, ownerID: playbackOwnerID)
    }

    private func presentFullscreen(drama: Drama, episode: Episode) {
        lockedDramaId = drama.dramaId
        selectedDramaId = drama.dramaId
        fullscreenPlayback = FullscreenPlayback(drama: drama, episode: episode)
    }

    private func resumeAfterFullscreen() {
        guard let lockedDramaId,
              let drama = store.homeDramas.first(where: { $0.dramaId == lockedDramaId }),
              let episode = drama.episodes.first else {
            return
        }

        isVisible = true
        selectedDramaId = lockedDramaId
        playbackManager.play(drama: drama, episode: episode, ownerID: playbackOwnerID)
        self.lockedDramaId = nil
    }

    private var selectedDramaPosition: Binding<String?> {
        Binding(
            get: { selectedDramaId },
            set: { newValue in
                guard lockedDramaId == nil else { return }
                selectedDramaId = newValue
            }
        )
    }
}

private struct HomeDramaPage: View {
    let drama: Drama
    let isActive: Bool
    let presentFullscreen: (Drama, Episode) -> Void
    @State private var isDescriptionExpanded = false

    private var episode: Episode? {
        drama.episodes.first
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black

            if let episode {
                VStack(spacing: 14) {
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

                    Spacer(minLength: 88)
                }
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: isDescriptionExpanded ? 340 : 260)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 12) {
                Text(drama.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !drama.tags.isEmpty {
                    Text(drama.tags.map { "#\($0)" }.joined(separator: "  "))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                if !drama.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(drama.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(isDescriptionExpanded ? nil : 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDescriptionExpanded.toggle()
                            }
                        }
                }

                if let episode {
                    PlaybackProgressControl(
                        isActive: isActive,
                        fallbackDuration: episode.duration
                    )
                }

                NavigationLink(value: drama) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("观看完整短剧 · 全\(drama.totalEpisodes)集")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.16))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView("正在加载短剧…")
                .tint(.white)
                .foregroundStyle(.white)
        }
    }
}

struct LoadErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("加载失败", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("重新加载", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
    }
}
