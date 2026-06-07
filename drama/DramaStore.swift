import Combine
import Foundation

@MainActor
final class DramaStore: ObservableObject {
    @Published private(set) var homeDramas: [Drama] = []
    @Published private(set) var categories: [TheaterCategory] = []
    @Published private(set) var theaterSections: [TheaterSection] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let homeURL = URL(string: "https://zzz-pet.oss-cn-hangzhou.aliyuncs.com/api/drama.json")!
    private let theaterURL = URL(string: "https://zzz-pet.oss-cn-hangzhou.aliyuncs.com/api/theater.json")!

    var allDramas: [Drama] {
        var seen = Set<String>()
        return (homeDramas + theaterSections.flatMap(\.dramas)).filter {
            seen.insert($0.dramaId).inserted
        }
    }

    func dramas(in categoryId: String) -> [Drama] {
        theaterSections.first(where: { $0.categoryId == categoryId })?.dramas ?? []
    }

    func drama(id: String) -> Drama? {
        allDramas.first(where: { $0.dramaId == id })
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let homeResponse = try await fetch(DramaResponse.self, from: homeURL)
            homeDramas = homeResponse.dramas
        } catch {
            errorMessage = "首页内容加载失败，请稍后重试"
        }

        do {
            let theaterResponse = try await fetch(TheaterResponse.self, from: theaterURL)
            categories = theaterResponse.categories
            theaterSections = theaterResponse.sections
        } catch {
            errorMessage = errorMessage ?? "剧场内容加载失败，请稍后重试"
        }

        isLoading = false
    }

    private func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(type, from: data)
    }
}
