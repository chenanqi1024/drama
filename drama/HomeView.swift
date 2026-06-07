import AVFoundation
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: DramaStore
    @EnvironmentObject private var playbackManager: PlaybackManager
    @State private var selectedDramaId: String?
    @State private var isVisible = false

    var body: some View {
        Group {
            if store.isLoading && store.homeDramas.isEmpty {
                LoadingView()
            } else if let errorMessage = store.errorMessage, store.homeDramas.isEmpty {
                LoadErrorView(message: errorMessage) {
                    Task { await store.load() }
                }
            } else {
                GeometryReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(store.homeDramas) { drama in
                                HomeDramaPage(
                                    drama: drama,
                                    isActive: isVisible && selectedDramaId == drama.id
                                )
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .id(drama.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $selectedDramaId)
                }
                .background(.black)
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            isVisible = true
            if selectedDramaId == nil {
                selectedDramaId = store.homeDramas.first?.id
            }
            activateSelectedDrama()
        }
        .onDisappear {
            isVisible = false
            playbackManager.pause()
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
        guard isVisible,
              let selectedDramaId,
              let drama = store.homeDramas.first(where: { $0.id == selectedDramaId }),
              let episode = drama.episodes.first else {
            return
        }
        playbackManager.play(drama: drama, episode: episode)
    }
}

private struct HomeDramaPage: View {
    @EnvironmentObject private var playbackManager: PlaybackManager

    let drama: Drama
    let isActive: Bool
    @State private var showsFullscreen = false

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

                    Spacer(minLength: 88)
                }
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 210)
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
        .fullScreenCover(isPresented: $showsFullscreen) {
            if let episode {
                LandscapePlayerView(drama: drama, episode: episode)
            }
        }
        .onChange(of: showsFullscreen) {
            if !showsFullscreen, isActive, let episode {
                playbackManager.play(drama: drama, episode: episode)
            }
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
