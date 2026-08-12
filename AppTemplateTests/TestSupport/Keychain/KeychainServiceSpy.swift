import Foundation
@testable import AppTemplate

actor KeychainServiceSpy: IKeychainService {
    private var storage: [KeychainKey: Data]
    private(set) var reads: [KeychainKey] = []
    private(set) var writes: [(KeychainKey, Data)] = []
    private(set) var removals: [KeychainKey] = []
    private let beforeRead: @Sendable () throws -> Void
    private let beforeWrite: @Sendable () throws -> Void

    init(
        storage: [KeychainKey: Data] = [:],
        beforeRead: @escaping @Sendable () throws -> Void = {},
        beforeWrite: @escaping @Sendable () throws -> Void = {}
    ) {
        self.storage = storage
        self.beforeRead = beforeRead
        self.beforeWrite = beforeWrite
    }

    func data(for key: KeychainKey) async throws -> Data? {
        reads.append(key)
        try beforeRead()
        return storage[key]
    }

    func set(_ data: Data, for key: KeychainKey) async throws {
        writes.append((key, data))
        try beforeWrite()
        storage[key] = data
    }

    func remove(_ key: KeychainKey) async throws -> Bool {
        removals.append(key)
        return storage.removeValue(forKey: key) != nil
    }

    func storedData(for key: KeychainKey) -> Data? { storage[key] }
    func callCounts() -> (reads: Int, writes: Int, removals: Int) {
        (reads.count, writes.count, removals.count)
    }
}
