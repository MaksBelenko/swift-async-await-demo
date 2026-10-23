/*
 Wrappers and deprecation

 Phase 1  - closure is the implementation, add async wrapper
 Phase 1b - same, plus deprecate the closure method
 Phase 2  - async is the implementation, closure method is a deprecated wrapper
 Phase 3  - delete the closure method
 */
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

struct User {
    let id: Int
    let name: String
}

// Phase1 / Phase1b / Phase2 enums are just namespaces, so the 3 versions of the same service don't clash

// MARK: - Phase 1 (now)
// old method untouched
enum Phase1 {
    final class UserService {
        func fetchUser(id: Int, completion: @escaping (Result<User, Error>) -> Void) {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                completion(.success(User(id: id, name: "Phase 1 user")))
            }
        }
    }
}

// new code only calls this one
extension Phase1.UserService {
    func fetchUser(id: Int) async throws -> User {
        try await withCheckedThrowingContinuation { continuation in
            fetchUser(id: id) { continuation.resume(with: $0) }
        }
    }
}

// MARK: - Phase 1b (now, if we want warnings already)
// If the wrapper called the deprecated method we'd get a warning inside the wrapper,
// so the body moves to a private method
enum Phase1b {
    final class UserService {
        // old method, now only forwards
        @available(*, deprecated, renamed: "fetchUser(id:)")
        func fetchUser(id: Int, completion: @escaping (Result<User, Error>) -> Void) {
            _fetchUser(id: id, completion: completion)
        }

        // async wrapper
        func fetchUser(id: Int) async throws -> User {
            try await withCheckedThrowingContinuation { continuation in
                _fetchUser(id: id) { continuation.resume(with: $0) }
            }
        }

        // original code, just renamed and private
        private func _fetchUser(id: Int, completion: @escaping (Result<User, Error>) -> Void) {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                completion(.success(User(id: id, name: "Phase 1b user")))
            }
        }
    }
}

// MARK: - Phase 2 (later, bulk conversion)
enum Phase2 {
    final class UserService {
        // real implementation is async now
        func fetchUser(id: Int) async throws -> User {
            try await Task.sleep(for: .seconds(0.2)) // URLSession.shared.data(for:)
            return User(id: id, name: "Phase 2 user")
        }

        // other way around: closure method is the wrapper, kept only for old call sites
        @available(*, deprecated, renamed: "fetchUser(id:)")
        func fetchUser(id: Int, completion: @escaping (Result<User, Error>) -> Void) {
            Task {
                do {
                    completion(.success(try await fetchUser(id: id)))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
}

Demo.section("2.2 Wrappers and deprecation")

// old call site - warning + fix-it
Phase1b.UserService().fetchUser(id: 1) { result in
    print("old call site:", (try? result.get().name) ?? "error")
}

// new call sites look the same in every phase
Task {
    let one = try await Phase1.UserService().fetchUser(id: 1)
    let oneB = try await Phase1b.UserService().fetchUser(id: 1)
    let two = try await Phase2.UserService().fetchUser(id: 1)
    print("new call sites:", one.name, oneB.name, two.name)
}

// renamed: alone gives no warning, it needs deprecated too
// Task {} in phase 2 isn't cancelled with the caller and calls completion on a background thread
