/*
 Callback hell

 Profile screen needs user -> posts -> avatar, each call depends on the previous one.
 */
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

struct User  {
    let id: Int;
    let name: String;
    let avatarURL: URL
}
struct Post {
    let title: String
}
struct Profile  {
    let user: User
    let posts: [Post]
    let avatar: Data
}
enum ServiceError: Error {
    case notFound, avatarMissing
}


final class LegacyProfileService {
    private let queue = DispatchQueue.global()

    func fetchUser(id: Int, completion: @escaping (Result<User, Error>) -> Void) {
        queue.asyncAfter(deadline: .now() + 0.3) {
            guard id > 0 else {
                return completion(.failure(ServiceError.notFound))
            }
            completion(.success(User(id: id, name: "User \(id)", avatarURL: URL(string: "https://example.com/\(id).png")!)))
        }
    }

    func fetchPosts(userID: Int, completion: @escaping (Result<[Post], Error>) -> Void) {
        queue.asyncAfter(deadline: .now() + 0.3) {
            completion(.success([Post(title: "Hello"), Post(title: "async/await")]))
        }
    }

    func fetchAvatar(url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        queue.asyncAfter(deadline: .now() + 0.3) {
            // User 2 has no avatar, therefore failure
            url.lastPathComponent == "2.png"
                ? completion(.failure(ServiceError.avatarMissing))
                : completion(.success(Data()))
        }
    }
}

let profileService = LegacyProfileService()

func loadProfile(id: Int, completion: @escaping (Result<Profile, Error>) -> Void) {
    profileService.fetchUser(id: id) { userResult in
        switch userResult {
        case .failure(let error):
            completion(.failure(error))
        case .success(let user):
            profileService.fetchPosts(userID: user.id) { postsResult in
                switch postsResult {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let posts):
                    profileService.fetchAvatar(url: user.avatarURL) { avatarResult in
                        guard case .success(let avatar) = avatarResult else {
                            // BUG: forgot "completion(.failure(...))".
                            // It compiles just fine and the caller waits forever (spinner never stops).
                            return
                        }
                        completion(.success(Profile(user: user, posts: posts, avatar: avatar)))
                    }
                }
            }
        }
    }
}


/*
 * User `1` works.
 * User `2` has no avatar - because of the bug "nothing is printed", ever.
 * Also notice: the completion runs on a background thread, updating UI here would be a bug too.
 */
Demo.section("1.1 Callback hell")

print("Start Loading Profile 1")
loadProfile(id: 1) { result in
    print("Profile 1:", (try? result.get().user.name) ?? "failed", "| main thread?", Thread.isMainThread)
}

print("Start Loading Profile 2")
loadProfile(id: 2) { result in
    print("Profile 2:", result) // NEVER CALLED!!!
}

// Next page: the same flow with async/await
