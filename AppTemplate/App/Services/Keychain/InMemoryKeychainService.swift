import Foundation

actor InMemoryKeychainService: IKeychainService {
    private var storage: [KeychainKey: Data] = [:]

    init() {}

    func data(for key: KeychainKey) async throws -> Data? {
        try Task.checkCancellation()
        return storage[key]
    }

    func set(_ data: Data, for key: KeychainKey) async throws {
        try Task.checkCancellation()
        storage[key] = data
    }

    func remove(_ key: KeychainKey) async throws -> Bool {
        try Task.checkCancellation()
        return storage.removeValue(forKey: key) != nil
    }
}
