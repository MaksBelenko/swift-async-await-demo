/*
 MainActor

 Global actor that runs on the main thread. Replaces DispatchQueue.main.async.
 New screens: view models @MainActor, stateful services actors, models structs.
 */
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

struct Article: Decodable {
    let id: Int
    let title: String
}

func currentThread() -> String {
    Thread.isMainThread ? "main" : "background"
}

actor ArticleRepository {
    private var cache: [Article]?

    func articles() async throws -> [Article] {
        if let cache { return cache }
        try await Task.sleep(for: .seconds(0.3))
        let json = Data(#"[{"id":1,"title":"async/await"},{"id":2,"title":"Actors"}]"#.utf8)
        let articles = try await Self.decode(json)
        cache = articles
        return articles
    }

    // nonisolated async runs in the background, doesn't block main or the actor
    nonisolated static func decode(_ data: Data) async throws -> [Article] {
        print("decode on:", currentThread())
        return try JSONDecoder().decode([Article].self, from: data)
    }
}

@MainActor
final class ArticlesViewModel {
    private let repository = ArticleRepository()
    private(set) var titles: [String] = []
    private(set) var isLoading = false

    func load() async {
        isLoading = true
        defer { isLoading = false }
        print("load starts on:", currentThread())
        do {
            let articles = try await repository.articles()
            titles = articles.map(\.title)
            print("load continues on:", currentThread(), titles)
        } catch {
            titles = []
        }
    }

    nonisolated func analyticsName() -> String { "articles_screen" }
}

@MainActor func updateBadge(_ count: Int) {
    print("badge \(count) on:", currentThread())
}

func backgroundJob() async {
    await updateBadge(3)

    await MainActor.run {
        print("MainActor.run on:", currentThread())
    }
}

Demo.section("4.3 MainActor")

Task { @MainActor in
    let viewModel = ArticlesViewModel()
    await viewModel.load()
    print("analytics:", viewModel.analyticsName())

    await Task.detached { await backgroundJob() }.value
}

// Old:  DispatchQueue.main.async { ... }
// New:  @MainActor on the type/method, or await MainActor.run { ... }, or Task { @MainActor in ... }
// @MainActor is only checked from async code, old GCD callbacks still need to hop to main themselves
