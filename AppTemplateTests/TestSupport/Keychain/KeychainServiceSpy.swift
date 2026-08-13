import Foundation
@testable import AppTemplate

actor KeychainServiceSpy: IKeychainService {
    private var storage: [KeychainKey: Data]
    private(set) var reads: [KeychainKey] = []
    private(set) var writes: [(KeychainKey, Data)] = []
    private(set) var removals: [KeychainKey] = []
    private let beforeRead: @Sendable () throws -> Void
    private let beforeReadAsync: @Sendable () async throws -> Void
    private let beforeWrite: @Sendable () throws -> Void
    private let beforeRemove: @Sendable () throws -> Void

    init(
        storage: [KeychainKey: Data] = [:],
        beforeRead: @escaping @Sendable () throws -> Void = {},
        beforeReadAsync: @escaping @Sendable () async throws -> Void = {},
        beforeWrite: @escaping @Sendable () throws -> Void = {},
        beforeRemove: @escaping @Sendable () throws -> Void = {}
    ) {
        self.storage = storage
        self.beforeRead = beforeRead
        self.beforeReadAsync = beforeReadAsync
        self.beforeWrite = beforeWrite
        self.beforeRemove = beforeRemove
    }

    func data(for key: KeychainKey) async throws -> Data? {
        reads.append(key)
        let data = storage[key]
        try beforeRead()
        try await beforeReadAsync()
        return data
    }

    func set(_ data: Data, for key: KeychainKey) async throws {
        writes.append((key, data))
        try beforeWrite()
        storage[key] = data
    }

    func remove(_ key: KeychainKey) async throws -> Bool {
        removals.append(key)
        try beforeRemove()
        return storage.removeValue(forKey: key) != nil
    }

    func replaceStoredData(_ data: Data?, for key: KeychainKey) {
        storage[key] = data
    }

    func storedData(for key: KeychainKey) -> Data? { storage[key] }
    func callCounts() -> (reads: Int, writes: Int, removals: Int) {
        (reads.count, writes.count, removals.count)
    }
}
