/*
 Continuation pitfalls

 1. resume exactly once
 2. cancellation doesn't reach the old API by itself
 3. delegates -> store the continuation
 4. callback called many times -> AsyncStream
 */
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

// MARK: - 1. Resume exactly once
// twice -> crash, never -> task hangs forever

// wrong, resumes twice on failure
// fetch { result in
//     if case .failure(let error) = result { continuation.resume(throwing: error) }
//     continuation.resume(with: result)
// }

// wrong, never resumes on failure
// fetch { result in
//     guard case .success(let value) = result else { return }
//     continuation.resume(returning: value)
// }

// right
// fetch { result in
//     continuation.resume(with: result)
// }


// MARK: - 2. Cancellation
// Task.cancel() doesn't reach old code by itself

// old request with start/cancel, like URLSessionDataTask
final class LegacyRequest {
    private var completion: ((Result<String, Error>) -> Void)?

    func start(completion: @escaping (Result<String, Error>) -> Void) {
        self.completion = completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.finish(.success("data")) }
    }

    // still calls completion, so the continuation gets resumed
    func cancel() {
        DispatchQueue.main.async { self.finish(.failure(CancellationError())) }
    }

    private func finish(_ result: Result<String, Error>) {
        completion?(result)
        completion = nil
    }
}

func download() async throws -> String {
    let request = LegacyRequest()                       // one object
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            request.start { continuation.resume(with: $0) } // used here
        }
    } onCancel: {
        request.cancel()                                // and the same one here
    }
}


// MARK: - 3. Delegates
// no closure to resume in, the answer comes later in a delegate method

protocol LocationDelegate: AnyObject {
    func didUpdate(location: String)
}

// pretend CLLocationManager
final class LegacyLocationManager {
    weak var delegate: LocationDelegate?

    func requestLocation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.delegate?.didUpdate(location: "Amsterdam")
        }
    }
}

final class LocationProvider: LocationDelegate {
    private let manager = LegacyLocationManager()
    private var continuation: CheckedContinuation<String, Never>?

    init() {
        manager.delegate = self
    }

    func currentLocation() async -> String {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func didUpdate(location: String) {
        continuation?.resume(returning: location)
        continuation = nil // so it can't be resumed twice
    }
}


// MARK: - 4. Many callbacks -> AsyncStream
// continuation gives back one value, progress gives many

// old uploader, calls progress several times then completion
final class LegacyUploader {
    func upload(progress: @escaping (Double) -> Void, completion: @escaping () -> Void) {
        for step in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 * Double(step)) {
                progress(Double(step) / 4)
                if step == 4 { completion() }
            }
        }
    }
}

extension LegacyUploader {
    func upload() -> AsyncStream<Double> {
        AsyncStream { continuation in
            upload(progress: { continuation.yield($0) },
                   completion: { continuation.finish() })
        }
    }
}


Demo.section("2.3 Continuation pitfalls")

Task {
    // 2. cancel after 0.3s, without the handler it would wait 2s
    let downloadTask = Task { try await download() }
    try await Task.sleep(for: .seconds(0.3))
    downloadTask.cancel()
    do {
        _ = try await downloadTask.value
    } catch {
        print("download cancelled:", error)
    }

    // 3.
    let location = await LocationProvider().currentLocation()
    print("location:", location)

    // 4.
    for await value in LegacyUploader().upload() {
        print("upload \(Int(value * 100))%")
    }
    print("upload finished")
}
