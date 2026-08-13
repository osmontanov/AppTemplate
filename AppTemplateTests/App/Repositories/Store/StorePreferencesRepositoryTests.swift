import Foundation
import Synchronization
import Testing
@testable import AppTemplate

struct StorePreferencesRepositoryTests {
    @Test
    func defaultsAndEveryAcceptedChoicePersistWithExactKinds() async throws {
        let defaults = PreferencesDefaultsFake()
        let repository = StorePreferencesRepository(userDefaults: defaults)
        #expect(await repository.current() == .defaults)

        for layout in StoreCatalogLayout.allCases { try await repository.setLayout(layout) }
        for sort in StoreCatalogSort.allCases { try await repository.setSort(sort) }
        for size in [10, 20, 30, 50] { try await repository.setPreferredRemotePageSize(size) }

        #expect(defaults.kind(for: "Store.CatalogLayout") == .string)
        #expect(defaults.kind(for: "Store.CatalogSort") == .string)
        #expect(defaults.kind(for: "Store.RemotePageSize") == .int)
        #expect(await repository.current().preferredRemotePageSize == 50)
    }

    @Test
    func invalidPageSizeDoesNotWriteOrPublish() async throws {
        let defaults = PreferencesDefaultsFake()
        let repository = StorePreferencesRepository(userDefaults: defaults)
        let before = await repository.publishedSnapshotCountForTesting

        await #expect(throws: StorePreferencesError.invalidRemotePageSize) {
            try await repository.setPreferredRemotePageSize(25)
        }

        #expect(defaults.writeCount == 0)
        #expect(await repository.publishedSnapshotCountForTesting == before)
    }

    @Test
    func eachCorruptKeyIsRepairedWithoutResettingValidNeighbors() async {
        let defaults = PreferencesDefaultsFake()
        defaults.seed(.string("list"), name: "Store.CatalogLayout")
        defaults.seed(.string("priceDescending"), name: "Store.CatalogSort")
        defaults.seed(.int(30), name: "Store.RemotePageSize")
        defaults.seed(.int(1), name: "Store.CatalogLayout")
        let repository = StorePreferencesRepository(userDefaults: defaults)

        #expect(await repository.current() == StorePreferences(layout: .grid, sort: .priceDescending, preferredRemotePageSize: 30))
        #expect(defaults.wasRemoved("Store.CatalogLayout"))
        #expect(!defaults.wasRemoved("Store.CatalogSort"))
        #expect(!defaults.wasRemoved("Store.RemotePageSize"))
    }

    @Test
    func multipleSubscribersReceiveImmediateAndMatchingPersistedSnapshots() async throws {
        let defaults = PreferencesDefaultsFake()
        let repository = StorePreferencesRepository(userDefaults: defaults)
        let firstStream = await repository.updates()
        let secondStream = await repository.updates()
        await repository.waitUntilSubscriptionCountForTesting(2)
        var first = firstStream.makeAsyncIterator()
        var second = secondStream.makeAsyncIterator()
        #expect(await first.next() == .defaults)
        #expect(await second.next() == .defaults)

        try await repository.setLayout(.list)
        let expected = StorePreferences(layout: .list, sort: .featured, preferredRemotePageSize: 20)
        #expect(await first.next() == expected)
        #expect(await second.next() == expected)
    }

    @Test
    func newestBufferDropsIntermediateSnapshotsAndTerminationRemovesSubscriber() async throws {
        let repository = StorePreferencesRepository(userDefaults: PreferencesDefaultsFake())
        var stream: AsyncStream<StorePreferences>? = await repository.updates()
        await repository.waitUntilSubscriptionCountForTesting(1)
        var iterator = stream?.makeAsyncIterator()
        _ = await iterator?.next()
        try await repository.setLayout(.list)
        try await repository.setSort(.titleDescending)
        try await repository.setPreferredRemotePageSize(50)

        #expect(await iterator?.next() == StorePreferences(layout: .list, sort: .titleDescending, preferredRemotePageSize: 50))
        iterator = nil
        stream = nil
        await repository.waitUntilSubscriptionCountForTesting(0)
    }

    @Test
    func failedWriteLeavesCurrentValueAndPublishesNothing() async {
        let defaults = PreferencesDefaultsFake()
        let repository = StorePreferencesRepository(userDefaults: defaults)
        defaults.failNextWrite()
        let before = await repository.publishedSnapshotCountForTesting

        await #expect(throws: PreferencesDefaultsFake.Failure.write) {
            try await repository.setLayout(.list)
        }

        #expect(await repository.current() == .defaults)
        #expect(await repository.publishedSnapshotCountForTesting == before)
    }
}

private final class PreferencesDefaultsFake: IUserDefaultsService, @unchecked Sendable {
    enum Failure: Error { case write }
    private struct State {
        var values: [String: UserDefaultsEncodedValue] = [:]
        var kinds: [String: UserDefaultsPhysicalKind] = [:]
        var removed: Set<String> = []
        var failWrite = false
        var writeCount = 0
    }
    private let state = Mutex(State())

    var writeCount: Int { state.withLock { $0.writeCount } }
    func kind(for name: String) -> UserDefaultsPhysicalKind? { state.withLock { $0.kinds[name] } }
    func wasRemoved(_ name: String) -> Bool { state.withLock { $0.removed.contains(name) } }
    func seed(_ value: UserDefaultsEncodedValue, name: String) { state.withLock { $0.values[name] = value } }
    func failNextWrite() { state.withLock { $0.failWrite = true } }

    func value<Value: Sendable>(for key: UserDefaultsKey<Value>) throws -> Value? {
        try state.withLock { state in try state.values[key.logicalName].map(key.decode) }
    }
    func set<Value: Sendable>(_ value: Value, for key: UserDefaultsKey<Value>) throws {
        try state.withLock { state in
            if state.failWrite { state.failWrite = false; throw Failure.write }
            state.values[key.logicalName] = try key.encode(value)
            state.kinds[key.logicalName] = key.physicalKind
            state.writeCount += 1
        }
    }
    func remove<Value: Sendable>(_ key: UserDefaultsKey<Value>) {
        state.withLock { state in
            state.values[key.logicalName] = nil
            state.removed.insert(key.logicalName)
        }
    }
}
