import AVFoundation
import Combine
import Foundation

struct PlaybackHistory: Codable, Identifiable {
    let dramaId: String
    var title: String
    var poster: String
    var episodeNumber: Int
    var currentTime: Double
    var duration: Double
    var updatedAt: Date

    var id: String { dramaId }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }
}

@MainActor
final class PlaybackManager: ObservableObject, @unchecked Sendable {
    let player = AVPlayer()

    @Published private(set) var currentDramaId: String?
    @Published private(set) var currentEpisodeNumber: Int?
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var history: [PlaybackHistory] = []
    @Published var playbackRate: Float = 1

    private var currentDrama: Drama?
    private var currentEpisode: Episode?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var positions: [String: Double] = [:]
    private let historyKey = "drama.playback.history"
    private let positionsKey = "drama.playback.positions"

    init() {
        restoreState()
        player.actionAtItemEnd = .pause
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                self?.handleTimeUpdate(time.seconds)
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isPlaying = false
                self?.saveCurrentState()
            }
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func play(drama: Drama, episode: Episode) {
        let key = positionKey(dramaId: drama.dramaId, episodeNumber: episode.episodeNumber)
        let isCurrent = currentDramaId == drama.dramaId &&
            currentEpisodeNumber == episode.episodeNumber &&
            player.currentItem != nil

        if !isCurrent {
            saveCurrentState()
            currentDrama = drama
            currentEpisode = episode
            currentDramaId = drama.dramaId
            currentEpisodeNumber = episode.episodeNumber
            currentTime = positions[key] ?? 0
            duration = episode.duration

            guard let url = MediaURL.resolve(episode.videoUrl) else {
                player.replaceCurrentItem(with: nil)
                isPlaying = false
                return
            }

            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            let startTime = min(currentTime, max(episode.duration - 1, 0))
            player.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
        }

        player.defaultRate = playbackRate
        player.playImmediately(atRate: playbackRate)
        isPlaying = true
        updateHistory()
    }

    func pause() {
        player.pause()
        isPlaying = false
        saveCurrentState()
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            if duration > 0, currentTime >= duration - 0.5 {
                seek(to: 0)
            }
            player.playImmediately(atRate: playbackRate)
            isPlaying = true
        }
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        player.defaultRate = rate
        if isPlaying {
            player.rate = rate
        }
    }

    func seek(to seconds: Double) {
        let target = min(max(seconds, 0), duration)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        saveCurrentState()
    }

    func preferredEpisodeNumber(for dramaId: String) -> Int? {
        if currentDramaId == dramaId {
            return currentEpisodeNumber
        }
        return history.first(where: { $0.dramaId == dramaId })?.episodeNumber
    }

    private func handleTimeUpdate(_ seconds: Double) {
        guard seconds.isFinite, currentEpisode != nil else { return }
        currentTime = seconds
        duration = player.currentItem?.duration.seconds.isFinite == true
            ? player.currentItem?.duration.seconds ?? currentEpisode?.duration ?? 0
            : currentEpisode?.duration ?? 0
        saveCurrentState()
    }

    private func saveCurrentState() {
        guard let drama = currentDrama, let episode = currentEpisode else { return }
        let seconds = player.currentTime().seconds
        if seconds.isFinite {
            currentTime = seconds
        }
        positions[positionKey(dramaId: drama.dramaId, episodeNumber: episode.episodeNumber)] = currentTime
        updateHistory()
        persistState()
    }

    private func updateHistory() {
        guard let drama = currentDrama, let episode = currentEpisode else { return }
        let record = PlaybackHistory(
            dramaId: drama.dramaId,
            title: drama.title,
            poster: drama.poster,
            episodeNumber: episode.episodeNumber,
            currentTime: currentTime,
            duration: duration > 0 ? duration : episode.duration,
            updatedAt: Date()
        )
        history.removeAll(where: { $0.dramaId == drama.dramaId })
        history.insert(record, at: 0)
    }

    private func positionKey(dramaId: String, episodeNumber: Int) -> String {
        "\(dramaId)#\(episodeNumber)"
    }

    private func restoreState() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let savedHistory = try? decoder.decode([PlaybackHistory].self, from: data) {
            history = savedHistory
        }
        if let data = UserDefaults.standard.data(forKey: positionsKey),
           let savedPositions = try? decoder.decode([String: Double].self, from: data) {
            positions = savedPositions
        }
    }

    private func persistState() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
        if let data = try? encoder.encode(positions) {
            UserDefaults.standard.set(data, forKey: positionsKey)
        }
    }
}
