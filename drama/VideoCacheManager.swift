import CryptoKit
import Foundation

struct VideoCacheStats: Equatable, Sendable {
    let size: Int64
    let fileCount: Int
    let maximumSize: Int64

    static let empty = VideoCacheStats(size: 0, fileCount: 0, maximumSize: 1_000_000_000)

    var usageFraction: Double {
        guard maximumSize > 0 else { return 0 }
        return min(max(Double(size) / Double(maximumSize), 0), 1)
    }
}

actor VideoCacheManager {
    static let shared = VideoCacheManager()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maximumCacheSize: Int64 = 1_000_000_000
    private var downloads: [URL: Task<URL?, Never>] = [:]

    init() {
        let root = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = root.appendingPathComponent("VideoCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func cachedURL(for remoteURL: URL) -> URL? {
        let localURL = destinationURL(for: remoteURL)
        guard fileManager.fileExists(atPath: localURL.path) else {
            return nil
        }

        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: localURL.path
        )
        return localURL
    }

    func cacheVideo(from remoteURL: URL) async -> URL? {
        if let localURL = cachedURL(for: remoteURL) {
            return localURL
        }

        if let download = downloads[remoteURL] {
            return await download.value
        }

        let localURL = destinationURL(for: remoteURL)
        let download = Task<URL?, Never> {
            do {
                let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
                guard let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode else {
                    try? fileManager.removeItem(at: temporaryURL)
                    return nil
                }

                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: localURL.path) {
                    try? fileManager.removeItem(at: temporaryURL)
                } else {
                    try fileManager.moveItem(at: temporaryURL, to: localURL)
                }
                return localURL
            } catch {
                return nil
            }
        }

        downloads[remoteURL] = download
        let result = await download.value
        downloads[remoteURL] = nil
        trimCacheIfNeeded()
        return result
    }

    func cacheStats() -> VideoCacheStats {
        let keys: Set<URLResourceKey> = [.fileSizeKey]
        let files = (try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []
        let size = files.reduce(Int64(0)) { result, url in
            let fileSize = (try? url.resourceValues(forKeys: keys).fileSize) ?? 0
            return result + Int64(fileSize)
        }
        return VideoCacheStats(
            size: size,
            fileCount: files.count,
            maximumSize: maximumCacheSize
        )
    }

    func clearCache() {
        downloads.values.forEach { $0.cancel() }
        downloads.removeAll()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func destinationURL(for remoteURL: URL) -> URL {
        let digest = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        let pathExtension = remoteURL.pathExtension.isEmpty ? "mp4" : remoteURL.pathExtension
        return cacheDirectory
            .appendingPathComponent(name)
            .appendingPathExtension(pathExtension)
    }

    private func trimCacheIfNeeded() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let entries = files.compactMap { url -> (url: URL, size: Int64, date: Date)? in
            guard let values = try? url.resourceValues(forKeys: keys),
                  let size = values.fileSize else {
                return nil
            }
            return (url, Int64(size), values.contentModificationDate ?? .distantPast)
        }

        var totalSize = entries.reduce(Int64(0)) { $0 + $1.size }
        guard totalSize > maximumCacheSize else { return }

        for entry in entries.sorted(by: { $0.date < $1.date }) {
            try? fileManager.removeItem(at: entry.url)
            totalSize -= entry.size
            if totalSize <= maximumCacheSize {
                break
            }
        }
    }
}
