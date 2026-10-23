/*
 Sequential

 await waits until the call is done, so independent calls awaited one by one add up.
 The other way around: two separate Task {} blocks are NOT sequential.
 */
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

@MainActor final class Storage {
    var values: [String] = []
}

Demo.section("3.1 Sequential")

Task {
    // ~3s, but none of these depend on each other
    try await measure("sequential") {
        let user = try await Demo.work("user", seconds: 1, returning: "John")
        let feed = try await Demo.work("feed", seconds: 1, returning: ["post 1", "post 2"])
        let promo = try await Demo.work("promo", seconds: 1, returning: "50% off")
        print(user, feed, promo)
    }

    // await in a loop is sequential too
    try await measure("loop") {
        for id in 1...3 {
            _ = try await Demo.work("image \(id)", seconds: 0.5, returning: id)
        }
    }

    // Here sequential is correct, user needs the token
    try await measure("dependent") {
        let token = try await Demo.work("login", seconds: 0.5, returning: "abc123")
        let user = try await Demo.work("user with token \(token)", seconds: 0.5, returning: "John")
        print("logged in as", user)
    }

    await separateTasks()
    await chainedTasks()
}

// save starts first, read finishes first
@MainActor func separateTasks() async {
    let storage = Storage()
    let save = Task { @MainActor in
        _ = try? await Demo.work("save", seconds: 0.5, returning: ())
        storage.values.append("saved value")
    }
    let read = Task { @MainActor in
        _ = try? await Demo.work("read", seconds: 0.1, returning: ())
        print("read sees:", storage.values) // []
    }
    _ = await (save.value, read.value)
}

// Best: one Task, await one after another.
// If they have to be separate tasks, await the previous one.
@MainActor func chainedTasks() async {
    let storage = Storage()
    let save = Task { @MainActor in
        _ = try? await Demo.work("save", seconds: 0.5, returning: ())
        storage.values.append("saved value")
    }
    let read = Task { @MainActor in
        await save.value
        _ = try? await Demo.work("read", seconds: 0.1, returning: ())
        print("read sees:", storage.values)
    }
    await read.value
}

// Actor doesn't make async work sequential either, see 4.2
