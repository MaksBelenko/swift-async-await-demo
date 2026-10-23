/*
 Actor reentrancy

 While an actor method is waiting on an await, other calls can run on the actor.
 So after an await, state you checked before may have changed. No warning, just a bug.
 */
import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

actor Network {
    private(set) var downloads = 0

    func download(_ url: String) async throws -> Data {
        downloads += 1
        try await Task.sleep(for: .seconds(0.5))
        return Data(url.utf8)
    }
}

// 3 calls at the same time: all see an empty cache, all download
actor NaiveImageCache {
    private var cache: [String: Data] = [:]
    let network: Network

    init(network: Network) {
        self.network = network
    }

    func image(for url: String) async throws -> Data {
        if let cached = cache[url] { return cached }
        let data = try await network.download(url) // other calls get in here
        cache[url] = data
        return data
    }
}

// Save the running Task before the await, other calls wait on the same task
actor ImageCache {
    private enum Entry {
        case inProgress(Task<Data, Error>)
        case ready(Data)
    }

    private var cache: [String: Entry] = [:]
    let network: Network

    init(network: Network) {
        self.network = network
    }

    func image(for url: String) async throws -> Data {
        switch cache[url] {
        case .ready(let data):
            return data
        case .inProgress(let task):
            return try await task.value
        case nil:
            let task = Task { try await network.download(url) }
            cache[url] = .inProgress(task)
            do {
                let data = try await task.value
                cache[url] = .ready(data)
                return data
            } catch {
                cache[url] = nil
                throw error
            }
        }
    }
}

actor Wallet {
    private(set) var balance = 100

    // check before await, change after await
    func buyNaive(price: Int) async -> Bool {
        guard balance >= price else { return false }
        try? await Task.sleep(for: .seconds(0.2)) // payment request
        balance -= price
        return true
    }

    // check and change with no await in between
    func buy(price: Int) async -> Bool {
        guard balance >= price else { return false }
        balance -= price
        try? await Task.sleep(for: .seconds(0.2))
        let paymentSucceeded = true
        if !paymentSucceeded { balance += price }
        return paymentSucceeded
    }
}

Demo.section("4.2 Actor reentrancy")

Task {
    let url = "https://example.com/avatar.png"

    let naiveNetwork = Network()
    let naive = NaiveImageCache(network: naiveNetwork)
    async let a = naive.image(for: url)
    async let b = naive.image(for: url)
    async let c = naive.image(for: url)
    _ = try await (a, b, c)
    print("naive cache downloads:", await naiveNetwork.downloads)

    let network = Network()
    let fixed = ImageCache(network: network)
    async let d = fixed.image(for: url)
    async let e = fixed.image(for: url)
    async let f = fixed.image(for: url)
    _ = try await (d, e, f)
    print("fixed cache downloads:", await network.downloads)

    let naiveWallet = Wallet()
    async let p1 = naiveWallet.buyNaive(price: 80)
    async let p2 = naiveWallet.buyNaive(price: 80)
    print("naive wallet:", await [p1, p2], "balance:", await naiveWallet.balance)

    let wallet = Wallet()
    async let q1 = wallet.buy(price: 80)
    async let q2 = wallet.buy(price: 80)
    print("fixed wallet:", await [q1, q2], "balance:", await wallet.balance)
}
