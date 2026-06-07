import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: DramaStore
    @EnvironmentObject private var playbackManager: PlaybackManager

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
