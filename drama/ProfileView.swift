import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: DramaStore
    @EnvironmentObject private var playbackManager: PlaybackManager
    @State private var cacheStats = VideoCacheStats.empty
    @State private var isClearingCache = false
    @State private var showsClearCacheConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.secondary)

                    Button("登录 / 注册") {}
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 180, height: 46)
                        .background(.red, in: Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 26)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("缓存管理")
                            .font(.title2.bold())

                        Spacer()

                        Button {
                            Task { await refreshCacheStats() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("刷新缓存信息")
                    }

                    CacheManagementCard(
                        stats: cacheStats,
                        isClearing: isClearingCache,
                        clearCache: {
                            showsClearCacheConfirmation = true
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("播放历史")
                        .font(.title2.bold())

                    if playbackManager.history.isEmpty {
                        ContentUnavailableView(
                            "暂无播放历史",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("看过的短剧会显示在这里")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                    } else {
                        ForEach(playbackManager.history) { history in
                            if let drama = store.drama(id: history.dramaId) {
                                NavigationLink(value: drama) {
                                    HistoryRow(history: history)
                                }
                                .buttonStyle(.plain)
                            } else {
                                HistoryRow(history: history)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await refreshCacheStats()
        }
        .alert("清理视频缓存？", isPresented: $showsClearCacheConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) {
                Task { await clearVideoCache() }
            }
        } message: {
            Text("将删除已缓存的视频，之后播放时会重新下载。")
        }
    }

    private func refreshCacheStats() async {
        cacheStats = await VideoCacheManager.shared.cacheStats()
    }

    private func clearVideoCache() async {
        isClearingCache = true
        await VideoCacheManager.shared.clearCache()
        cacheStats = await VideoCacheManager.shared.cacheStats()
        isClearingCache = false
    }
}

private struct CacheManagementCard: View {
    let stats: VideoCacheStats
    let isClearing: Bool
    let clearCache: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 13) {
                Image(systemName: "internaldrive.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .frame(width: 46, height: 46)
                    .background(.red.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.size.formattedFileSize)
                        .font(.headline)
                    Text("\(stats.fileCount) 个缓存视频 · 上限 \(stats.maximumSize.formattedFileSize)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ProgressView(value: stats.usageFraction)
                .tint(.red)

            Text("播放过的视频会自动缓存，空间超过上限后将优先清理较旧的视频。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive, action: clearCache) {
                HStack {
                    if isClearing {
                        ProgressView()
                    } else {
                        Image(systemName: "trash")
                    }
                    Text(isClearing ? "正在清理…" : "清理视频缓存")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(stats.fileCount == 0 || isClearing)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct HistoryRow: View {
    let history: PlaybackHistory

    var body: some View {
        HStack(spacing: 13) {
            RemotePoster(path: history.poster)
                .frame(width: 86, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 9) {
                Text(history.title)
                    .font(.headline)
                    .lineLimit(2)

                Text("看到第\(history.episodeNumber)集 · \(history.currentTime.playbackTimeText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ProgressView(value: history.progress)
                    .tint(.red)

                Text("已观看 \(Int(history.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private extension Int64 {
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
