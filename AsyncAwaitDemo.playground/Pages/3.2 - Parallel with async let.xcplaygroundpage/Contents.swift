/*
 async let

 Starts the work right away, you await the result later.
 For a fixed number of calls. Dynamic number (array of ids) -> TaskGroup.
 */
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

struct HomeScreen {
    let user: String
    let feed: [String]
    let promo: String
}
enum APIError: Error { case serverDown }

Demo.section("3.2 async let")

Task {
    // same 3 calls as 3.1, ~1s
    let screen = try await measure("async let") {
        async let user = Demo.work("user", seconds: 1, returning: "John")
        async let feed = Demo.work("feed", seconds: 1, returning: ["post 1", "post 2"])
        async let promo = Demo.work("promo", seconds: 1, returning: "50% off")
        return try await HomeScreen(user: user, feed: feed, promo: promo)
    }
    print(screen)

    // user first, then posts and avatar in parallel
    try await measure("mixed") {
        let user = try await Demo.work("user", seconds: 0.5, returning: 42)
        async let posts = Demo.work("posts for \(user)", seconds: 0.5, returning: ["Hello"])
        async let avatar = Demo.work("avatar for \(user)", seconds: 0.5, returning: Data([0xFF]))
        let (userPosts, userAvatar) = try await (posts, avatar)
        print("user \(user): \(userPosts.count) posts, avatar \(userAvatar.count) bytes")
    }

    // one fails -> the other one gets cancelled
    do {
        try await measure("failing") {
            async let slow = Demo.work("slow", seconds: 3, returning: "never")
            async let failing: String = {
                try await Task.sleep(for: .seconds(0.3))
                throw APIError.serverDown
            }()
            _ = try await (failing, slow)
        }
    } catch {
        print("error:", error) // after 0.3s, "done slow" never printed
    }
}

// - only local constants, not properties
// - not in a for loop
// - let x = await f() vs async let x = f(), easy to miss in review
