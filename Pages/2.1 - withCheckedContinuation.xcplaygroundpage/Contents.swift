/*
 Wrapping closures with continuations

 withCheckedContinuation          - callback can't fail
 withCheckedThrowingContinuation  - callback can fail

 Resume exactly once on every path. Twice = crash, never = task hangs forever.
 */
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

struct User {
    let id: Int
    let name: String
}
enum ServiceError: Error { case notFound, emptyResponse }

// Old service we don't want to touch
final class LegacyUserService {
    private let queue = DispatchQueue.global()

    func fetchUser(id: Int, completion: @escaping (Result<User, Error>) -> Void) {
        queue.asyncAfter(deadline: .now() + 0.3) {
            id > 0 ? completion(.success(User(id: id, name: "User \(id)")))
                   : completion(.failure(ServiceError.notFound))
        }
    }

    func fetchAvatar(userID: Int, completion: @escaping (Data?, Error?) -> Void) {
        queue.asyncAfter(deadline: .now() + 0.3) {
            completion(Data([0xFF, 0xD8]), nil)
        }
    }

    func isFeatureEnabled(_ name: String, completion: @escaping (Bool) -> Void) {
        queue.asyncAfter(deadline: .now() + 0.1) { completion(name == "newProfile") }
    }

    func logout(completion: @escaping () -> Void) {
        queue.asyncAfter(deadline: .now() + 0.1) { completion() }
    }
}

extension LegacyUserService {
    func fetchUser(id: Int) async throws -> User {
        try await withCheckedThrowingContinuation { continuation in
            fetchUser(id: id) { result in
                continuation.resume(with: result)
            }
        }
    }

    func fetchAvatar(userID: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            fetchAvatar(userID: userID) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: ServiceError.emptyResponse) // easy to forget
                }
            }
        }
    }

    func isFeatureEnabled(_ name: String) async -> Bool {
        await withCheckedContinuation { continuation in
            isFeatureEnabled(name) { isEnabled in
                continuation.resume(returning: isEnabled)
            }
        }
    }

    func logout() async {
        await withCheckedContinuation { continuation in
            logout { continuation.resume() }
        }
    }
}

// Xcode can generate this: right click method > Refactor > Add Async Wrapper

Demo.section("2.1 Wrapping closures")

Task {
    let service = LegacyUserService()
    do {
        let user = try await service.fetchUser(id: 7)
        let avatar = try await service.fetchAvatar(userID: user.id)
        let isNewProfile = await service.isFeatureEnabled("newProfile")
        print(user.name, "avatar:", avatar.count, "bytes", "newProfile:", isNewProfile)

        await service.logout()
        print("logged out")

        _ = try await service.fetchUser(id: -1)
    } catch {
        print("error:", error)
    }
}
