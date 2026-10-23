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
//
// Twice -> crash:
// legacy.fetch { result in
//     if case .failure(let error) = result { continuation.resume(throwing: error) }
//     continuation.resume(with: result)
// }
//
// Never -> "SWIFT TASK CONTINUATION MISUSE: ... leaked its continuation", task hangs forever:
// legacy.fetch { result in
//     guard case .success(let value) = result else { return }
//     continuation.resume(returning: value)
// }

// set to true to see the "leaked continuation" warning in the console
let showLeakDemo = false

// buggy old API, never calls completion
func legacyFetchThatNeverCallsBack(completion: @escaping (Int) -> Void) {
    DispatchQueue.global().async { _ = completion }
}

func leakyWrapper() async -> Int {
    await withCheckedContinuation { continuation in
        legacyFetchThatNeverCallsBack { continuation.resume(returning: $0) }
    }
}

// MARK: - 2. Cancellation
// Task.cancel() doesn't reach old code by itself, continuation just keeps waiting

// old request with start/cancel, like URLSessionDataTask
final class LegacyRequest {
    private let lock = NSLock()
    private var workItem: DispatchWorkItem?
    private var completion: ((Result<String, Error>) -> Void)?

    func start(completion: @escaping (Result<String, Error>) -> Void) {
        let item = DispatchWorkItem { [weak self] in self?.finish(.success("payload")) }
        lock.lock()
        self.completion = completion
        self.workItem = item
        lock.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: item)
    }

    func cancel() {
        // on cancel it still calls completion, so the continuation is resumed
        lock.lock()
        workItem?.cancel()
        lock.unlock()
        finish(.failure(CancellationError()))
    }

    // completion is called only once, success or cancel
    private func finish(_ result: Result<String, Error>) {
        lock.lock()
        let completion = self.completion
        self.completion = nil
        lock.unlock()
        completion?(result)
    }
}

// wrapper: onCancel tells the old request to stop
func download() async throws -> String {
    let request = LegacyRequest()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            request.start { continuation.resume(with: $0) }
        }
    } onCancel: {
        request.cancel()
    }
}

// MARK: - 3. Delegates (CLLocationManager etc.)
// no closure to resume in, the answer comes later in a delegate method

struct Coordinate {
    let lat: Double
    let lon: Double
}
enum LocationError: Error { case alreadyInProgress }

@MainActor protocol LegacyLocationManagerDelegate: AnyObject {
    func locationManager(didUpdate location: Coordinate)
    func locationManager(didFailWith error: Error)
}

// pretend CLLocationManager
@MainActor final class LegacyLocationManager {
    weak var delegate: LegacyLocationManagerDelegate?

    func requestLocation() {
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            delegate?.locationManager(didUpdate: Coordinate(lat: 52.37, lon: 4.89))
        }
    }
}

// wrapper: keeps the continuation until the delegate is called
@MainActor final class LocationProvider: LegacyLocationManagerDelegate {
    private let manager = LegacyLocationManager()
    private var continuation: CheckedContinuation<Coordinate, Error>?

    init() { manager.delegate = self }

    func currentLocation() async throws -> Coordinate {
        // second call would overwrite the first continuation
        guard continuation == nil else { throw LocationError.alreadyInProgress }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    // resume and nil it out, so it can't be resumed twice
    func locationManager(didUpdate location: Coordinate) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(didFailWith error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// MARK: - 4. Many callbacks -> AsyncStream
// continuation can give back only one value, progress gives many

// old uploader, calls progress several times and then completion
final class LegacyUploader {
    func upload(progress: @escaping (Double) -> Void, completion: @escaping () -> Void) {
        DispatchQueue.global().async {
            for step in 1...4 {
                Thread.sleep(forTimeInterval: 0.1)
                progress(Double(step) / 4)
            }
            completion()
        }
    }
}

// wrapper: progress -> yield, completion -> finish
extension LegacyUploader {
    func upload() -> AsyncStream<Double> {
        AsyncStream { continuation in
            upload(progress: { continuation.yield($0) },
                   completion: { continuation.finish() })
            // called when the for await loop stops or the task is cancelled
            continuation.onTermination = { _ in
                // cancel the upload here
            }
        }
    }
}

Demo.section("2.3 Continuation pitfalls")

Task {
    // 2. cancel after 0.3s, without the handler it would wait 2s
    let downloadTask = Task { try await download() }
    try? await Task.sleep(for: .seconds(0.3))
    downloadTask.cancel()
    do {
        _ = try await downloadTask.value
    } catch {
        print("download cancelled:", error)
    }

    // 3.
    let location = try await LocationProvider().currentLocation()
    print("location:", location)

    // 4.
    for await value in LegacyUploader().upload() {
        print("upload \(Int(value * 100))%")
    }
    print("upload finished")

    // 1.
    if showLeakDemo {
        print("calling leaky wrapper, never returns")
        _ = await leakyWrapper()
    }
}
