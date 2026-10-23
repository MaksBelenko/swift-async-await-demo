/*
 The same flow with async/await

 - reads top to bottom
 - one do/catch instead of error handling on every level
 - compiler forces return or throw on every path, so "forgot completion" can't happen
 */
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

struct User {
    let id: Int
    let name: String
    let avatarURL: URL
}
struct Post {
    let title: String
}
struct Profile {
    let user: User
    let posts: [Post]
    let avatar: Data
}
enum ServiceError: Error { case notFound, avatarMissing }

final class ProfileService {
    func fetchUser(id: Int) async throws -> User {
        try await Task.sleep(for: .seconds(0.3))
        guard id > 0 else { throw ServiceError.notFound }
        return User(id: id, name: "User \(id)", avatarURL: URL(string: "https://example.com/\(id).png")!)
    }

    func fetchPosts(userID: Int) async throws -> [Post] {
        try await Task.sleep(for: .seconds(0.3))
        return [Post(title: "Hello"), Post(title: "async/await")]
    }

    func fetchAvatar(url: URL) async throws -> Data {
        try await Task.sleep(for: .seconds(0.3))
        guard url.lastPathComponent != "2.png" else { throw ServiceError.avatarMissing }
        return Data()
    }
}

func loadProfile(id: Int, service: ProfileService) async throws -> Profile {
    let user = try await service.fetchUser(id: id)
    let posts = try await service.fetchPosts(userID: user.id)
    let avatar = try await service.fetchAvatar(url: user.avatarURL)
    return Profile(user: user, posts: posts, avatar: avatar)
}

@MainActor
final class ProfileViewModel {
    private let service = ProfileService()
    private var loadTask: Task<Void, Never>?

    private(set) var title = "Loading..."

    // viewDidLoad / onAppear
    func onAppear(userID: Int) {
        loadTask?.cancel()
        loadTask = Task { await load(userID: userID) }
    }

    func onDisappear() {
        loadTask?.cancel()
    }

    func load(userID: Int) async {
        do {
            let profile = try await loadProfile(id: userID, service: service)
            title = "\(profile.user.name), \(profile.posts.count) posts" // main thread
        } catch is CancellationError {
            return
        } catch {
            title = "Error: \(error)"
        }
        print("title:", title)
    }
}

Demo.section("1.2 async/await")

Task { @MainActor in
    let viewModel = ProfileViewModel()
    await viewModel.load(userID: 1)
    await viewModel.load(userID: 2) // error now always reaches the UI
}

// posts and avatar don't depend on each other but still run one after another -> 3.2
