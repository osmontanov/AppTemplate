import Foundation

nonisolated protocol IKeychainService: Sendable {
    func data(for key: KeychainKey) async throws -> Data?
    func set(_ data: Data, for key: KeychainKey) async throws
    @discardableResult func remove(_ key: KeychainKey) async throws -> Bool
}

nonisolated extension IKeychainService {
    func string(for key: KeychainKey) async throws -> String? {
        guard let data = try await data(for: key) else { return nil }
        try Task.checkCancellation()
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainServiceError.invalidUTF8
        }
        return value
    }

    func set(_ string: String, for key: KeychainKey) async throws {
        try Task.checkCancellation()
        try await set(Data(string.utf8), for: key)
    }

    func value<Value: Codable & Sendable>(
        for key: KeychainCodableKey<Value>
    ) async throws -> Value? {
        guard let data = try await data(for: key.rawKey) else { return nil }
        try Task.checkCancellation()
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw KeychainServiceError.decodingFailed
        }
    }

    func set<Value: Codable & Sendable>(
        _ value: Value,
        for key: KeychainCodableKey<Value>
    ) async throws {
        try Task.checkCancellation()
        let data: Data
        do {
            data = try JSONEncoder().encode(value)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw KeychainServiceError.encodingFailed
        }
        try await set(data, for: key.rawKey)
    }

    @discardableResult
    func remove<Value: Codable & Sendable>(
        _ key: KeychainCodableKey<Value>
    ) async throws -> Bool {
        try await remove(key.rawKey)
    }
}
