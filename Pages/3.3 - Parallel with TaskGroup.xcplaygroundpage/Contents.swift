/*
 TaskGroup

 Dynamic number of parallel tasks.
 Results come in the order they finish, not the order they were added.
 */
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

struct Thumbnail {
    let id: Int
    let bytes: Int
}
enum APIError: Error { case serverDown }

func downloadThumbnail(id: Int) async throws -> Thumbnail {
    let seconds = [1: 0.6, 2: 0.2, 3: 0.4, 4: 0.1, 5: 0.3][id] ?? 0.5
    return try await Demo.work("thumbnail \(id)", seconds: seconds, returning: Thumbnail(id: id, bytes: id * 100))
}

Demo.section("3.3 TaskGroup")

Task {
    let ids = [1, 2, 3, 4, 5]

    let thumbnails = try await measure("task group") {
        try await withThrowingTaskGroup(of: Thumbnail.self) { group in
            for id in ids {
                group.addTask { try await downloadThumbnail(id: id) }
            }
            var result: [Int: Thumbnail] = [:]
            for try await thumbnail in group {
                result[thumbnail.id] = thumbnail
            }
            return result
        }
    }
    print("in input order:", ids.compactMap { thumbnails[$0]?.bytes })

    // max 2 at a time
    try await measure("limited") {
        try await withThrowingTaskGroup(of: Thumbnail.self) { group in
            let maxConcurrent = 2
            var iterator = ids.makeIterator()

            for _ in 0..<maxConcurrent {
                guard let id = iterator.next() else { break }
                group.addTask { try await downloadThumbnail(id: id) }
            }
            while try await group.next() != nil {
                if let id = iterator.next() {
                    group.addTask { try await downloadThumbnail(id: id) }
                }
            }
        }
    }

    // one fails -> rest gets cancelled
    // note: group.waitForAll() waits for everything before throwing
    do {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { _ = try await Demo.work("long A", seconds: 2, returning: ()) }
            group.addTask { _ = try await Demo.work("long B", seconds: 2, returning: ()) }
            group.addTask {
                try await Task.sleep(for: .seconds(0.3))
                throw APIError.serverDown
            }
            for try await _ in group {}
        }
    } catch {
        print("group failed:", error)
    }
}

// async let     - fixed number, structured
// TaskGroup     - dynamic number, structured
// Task {}       - from sync code (viewDidLoad, button tap), keep it and cancel it yourself
// Task {} per item in a loop: nothing waits for them, nothing cancels them, errors get lost
