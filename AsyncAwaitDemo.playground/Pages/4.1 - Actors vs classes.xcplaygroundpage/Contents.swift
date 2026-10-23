/*
 Actors vs classes

 Data race: same memory accessed from several threads at once, at least one is a write.
 Actor: reference type that only lets one task at a time inside. From outside you need await.
 */
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

final class UnsafeCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

// Old way, works but easy to forget the queue somewhere
final class LockedCounter {
    private let queue = DispatchQueue(label: "counter")
    private var _value = 0
    var value: Int { queue.sync { _value } }
    func increment() { queue.sync { _value += 1 } }
}

actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

actor BankAccount {
    enum TransferError: Error { case insufficientFunds }

    let iban: String
    private(set) var balance: Double

    init(iban: String, balance: Double) {
        self.iban = iban
        self.balance = balance
    }

    func deposit(_ amount: Double) {
        balance += amount
    }

    func transfer(_ amount: Double, to other: BankAccount) async throws {
        guard balance >= amount else { throw TransferError.insufficientFunds }
        balance -= amount
        await other.deposit(amount)
    }

    // doesn't touch mutable state, no await needed
    nonisolated var maskedIBAN: String { "****" + iban.suffix(4) }
}

Demo.section("4.1 Actors vs classes")

let iterations = 10_000

let unsafe = UnsafeCounter()
DispatchQueue.concurrentPerform(iterations: iterations) { _ in unsafe.increment() }
print("class counter: \(unsafe.value) / \(iterations)")

Task {
    let counter = Counter()
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<iterations {
            group.addTask { await counter.increment() }
        }
    }
    print("actor counter: \(await counter.value) / \(iterations)")

    let alice = BankAccount(iban: "NL00BANK0123456789", balance: 100)
    let bob = BankAccount(iban: "NL00BANK9876543210", balance: 0)

    print(alice.iban, alice.maskedIBAN) // let and nonisolated, no await
    // alice.balance = 1_000_000 // doesn't compile
    // print(alice.balance)      // needs await

    try await alice.transfer(30, to: bob)
    print("alice:", await alice.balance, "bob:", await bob.balance)

    do {
        try await bob.transfer(500, to: alice)
    } catch {
        print("bob -> alice:", error)
    }
}

/*
 class vs actor
 - both reference types
 - actor protects its state, class doesn't (locks/queues by hand)
 - actor from outside needs await, except let and nonisolated
 - actor has no inheritance
 - actor is reentrant at every await, see 4.2

 Use actors for shared mutable state: caches, token storage, download managers.
 UI state -> @MainActor (4.3), models -> structs.
 */
