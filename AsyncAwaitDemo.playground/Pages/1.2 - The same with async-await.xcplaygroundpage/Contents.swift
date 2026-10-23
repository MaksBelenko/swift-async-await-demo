/*
 The same with async/await

 Same service, same flow as 1.1.
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
enum ServiceError: Error {
    case notFound, avatarMissing
}


final class ProfileService {
    func fetchUser(id: Int) async throws -> User {
        try await Task.sleep(for: .seconds(0.3))
        guard id > 0 else {
            throw ServiceError.notFound
        }
        return User(id: id, name: "User \(id)", avatarURL: URL(string: "https://example.com/\(id).png")!)
    }

    func fetchPosts(userID: Int) async throws -> [Post] {
        try await Task.sleep(for: .seconds(0.3))
        return [Post(title: "Hello"), Post(title: "async/await")]
    }

    func fetchAvatar(url: URL) async throws -> Data {
        try await Task.sleep(for: .seconds(0.3))
        // User 2 has no avatar, therefore failure
        guard url.lastPathComponent != "2.png" else {
            throw ServiceError.avatarMissing
        }
        return Data()
    }
}

let profileService = ProfileService()

func loadProfile(id: Int) async throws -> Profile {
    let user = try await profileService.fetchUser(id: id)
    let posts = try await profileService.fetchPosts(userID: user.id)
    let avatar = try await profileService.fetchAvatar(url: user.avatarURL)
    return Profile(user: user, posts: posts, avatar: avatar)
}


/*
 * User `1` works.
 * User `2` has no avatar - error always reaches the caller now.
 */
Demo.section("1.2 async/await")

Task {
    do {
        print("Start Loading Profile 1")
        let profile = try await loadProfile(id: 1)
        print("Profile 1:", profile.user.name)

        print("Start Loading Profile 2")
        let profile2 = try await loadProfile(id: 2)
        print("Profile 2:", profile2.user.name)
    } catch {
        print("Profile 2 failed:", error)
    }
}

// posts and avatar don't depend on each other but still run one after another -> 3.2
