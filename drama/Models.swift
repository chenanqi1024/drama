import Foundation

struct DramaResponse: Decodable {
    let dramas: [Drama]
}

struct TheaterResponse: Decodable {
    let categories: [TheaterCategory]
    let sections: [TheaterSection]
}

struct Drama: Codable, Hashable, Identifiable {
    let dramaId: String
    let title: String
    let poster: String
    let tags: [String]
    let description: String
    let totalEpisodes: Int
    let episodes: [Episode]

    var id: String { dramaId }
}

struct Episode: Codable, Hashable, Identifiable {
    let episodeNumber: Int
    let title: String
    let videoUrl: String
    let duration: Double
    let aspectRatio: Double

    var id: Int { episodeNumber }
}

struct TheaterCategory: Codable, Hashable, Identifiable {
    let categoryId: String
    let title: String
    let titleZh: String

    var id: String { categoryId }
}

struct TheaterSection: Codable, Hashable {
    let categoryId: String
    let dramas: [Drama]
}

enum MediaURL {
    private static let baseURL = URL(string: "https://zzz-pet.oss-cn-hangzhou.aliyuncs.com/api/")!

    static func resolve(_ path: String) -> URL? {
        URL(string: path, relativeTo: baseURL)?.absoluteURL
    }
}
