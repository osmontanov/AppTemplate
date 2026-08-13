import Foundation

nonisolated enum StorePreferencesError: Error, Equatable, Sendable {
    case invalidRemotePageSize
}

actor StorePreferencesRepository: IStorePreferencesRepository {
    private static let layoutKey = UserDefaultsKey<String>.string("Store.CatalogLayout")
    private static let sortKey = UserDefaultsKey<String>.string("Store.CatalogSort")
    private static let pageSizeKey = UserDefaultsKey<Int>.int("Store.RemotePageSize")
    private static let allowedPageSizes: Set<Int> = [10, 20, 30, 50]

    private let userDefaults: any IUserDefaultsService
    private var continuations: [UUID: AsyncStream<StorePreferences>.Continuation] = [:]
    private var subscriptionCountWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var publishedSnapshotCountForTesting = 0

    init(userDefaults: any IUserDefaultsService) {
        self.userDefaults = userDefaults
    }

    func current() -> StorePreferences {
        let layout: StoreCatalogLayout
        do {
            if let raw = try userDefaults.value(for: Self.layoutKey) {
                if let value = StoreCatalogLayout(rawValue: raw) { layout = value }
                else { userDefaults.remove(Self.layoutKey); layout = .grid }
            } else { layout = .grid }
        } catch {
            userDefaults.remove(Self.layoutKey)
            layout = .grid
        }

        let sort: StoreCatalogSort
        do {
            if let raw = try userDefaults.value(for: Self.sortKey) {
                if let value = StoreCatalogSort(rawValue: raw) { sort = value }
                else { userDefaults.remove(Self.sortKey); sort = .featured }
            } else { sort = .featured }
        } catch {
            userDefaults.remove(Self.sortKey)
            sort = .featured
        }

        let pageSize: Int
        do {
            if let value = try userDefaults.value(for: Self.pageSizeKey) {
                if Self.allowedPageSizes.contains(value) { pageSize = value }
                else { userDefaults.remove(Self.pageSizeKey); pageSize = 20 }
            } else { pageSize = 20 }
        } catch {
            userDefaults.remove(Self.pageSizeKey)
            pageSize = 20
        }
        return StorePreferences(layout: layout, sort: sort, preferredRemotePageSize: pageSize)
    }

    func updates() -> AsyncStream<StorePreferences> {
        let id = UUID()
        let pair = AsyncStream.makeStream(
            of: StorePreferences.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        pair.continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeContinuation(id) }
        }
        continuations[id] = pair.continuation
        resumeSubscriptionWaiters()
        pair.continuation.yield(current())
        return pair.stream
    }

    func setLayout(_ layout: StoreCatalogLayout) throws {
        try userDefaults.set(layout.rawValue, for: Self.layoutKey)
        publish(current())
    }

    func setSort(_ sort: StoreCatalogSort) throws {
        try userDefaults.set(sort.rawValue, for: Self.sortKey)
        publish(current())
    }

    func setPreferredRemotePageSize(_ size: Int) throws {
        guard Self.allowedPageSizes.contains(size) else {
            throw StorePreferencesError.invalidRemotePageSize
        }
        try userDefaults.set(size, for: Self.pageSizeKey)
        publish(current())
    }

    func waitUntilSubscriptionCountForTesting(_ expectedCount: Int) async {
        guard continuations.count != expectedCount else { return }
        await withCheckedContinuation { subscriptionCountWaiters.append((expectedCount, $0)) }
    }

    private func publish(_ snapshot: StorePreferences) {
        publishedSnapshotCountForTesting += 1
        for continuation in Array(continuations.values) { continuation.yield(snapshot) }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
        resumeSubscriptionWaiters()
    }

    private func resumeSubscriptionWaiters() {
        let count = continuations.count
        let ready = subscriptionCountWaiters.filter { $0.0 == count }
        subscriptionCountWaiters.removeAll { $0.0 == count }
        for waiter in ready { waiter.1.resume() }
    }
}

nonisolated final class InMemoryUserDefaultsService: IUserDefaultsService, @unchecked Sendable {
    private var values: [String: UserDefaultsEncodedValue] = [:]
    private let lock = NSLock()

    func value<Value: Sendable>(for key: UserDefaultsKey<Value>) throws -> Value? {
        try lock.withLock { try values[key.logicalName].map(key.decode) }
    }

    func set<Value: Sendable>(_ value: Value, for key: UserDefaultsKey<Value>) throws {
        let encoded = try key.encode(value)
        lock.withLock { values[key.logicalName] = encoded }
    }

    func remove<Value: Sendable>(_ key: UserDefaultsKey<Value>) {
        lock.withLock { values[key.logicalName] = nil }
    }
}
