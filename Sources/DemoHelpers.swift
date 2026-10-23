import Foundation

public enum Demo {
    // Fake network call
    public static func work<T>(_ label: String, seconds: Double, returning value: T) async throws -> T {
        print("start \(label)")
        try await Task.sleep(for: .seconds(seconds))
        print("done \(label)")
        return value
    }

    public static func section(_ title: String) {
        print("\n--- \(title) ---")
    }
}

@discardableResult
public func measure<T>(_ title: String, _ body: () async throws -> T) async rethrows -> T {
    let clock = ContinuousClock()
    let start = clock.now
    let result = try await body()
    let elapsed = clock.now - start
    let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    print("\(title) took \(String(format: "%.1f", seconds))s")
    return result
}
