import Foundation

nonisolated enum SessionSecureStoreReadResult: Equatable, Sendable {
    case missing
    case envelope(StoredSessionEnvelope)
    case corruptEnvelope
    case unsupportedSchema(Int)
}

actor SessionSecureStore {
    private let keychain: any IKeychainService
    private let key = KeychainKey.data("Store.AuthSession")

    init(keychain: any IKeychainService) {
        self.keychain = keychain
    }

    func read() async throws -> SessionSecureStoreReadResult {
        guard let data = try await keychain.data(for: key) else {
            return .missing
        }

        guard let header = try? JSONDecoder().decode(
            SessionEnvelopeHeader.self,
            from: data
        ) else {
            return .corruptEnvelope
        }

        if header.schemaVersion > StoredSessionEnvelope.currentSchemaVersion {
            return .unsupportedSchema(header.schemaVersion)
        }
        guard header.schemaVersion == StoredSessionEnvelope.currentSchemaVersion,
              let envelope = try? JSONDecoder().decode(
                StoredSessionEnvelope.self,
                from: data
              ),
              envelope.schemaVersion == StoredSessionEnvelope.currentSchemaVersion
        else {
            return .corruptEnvelope
        }

        return .envelope(envelope)
    }

    func write(_ envelope: StoredSessionEnvelope) async throws {
        let data = try JSONEncoder().encode(envelope)
        try await keychain.set(data, for: key)
    }

    @discardableResult
    func remove() async throws -> Bool {
        try await keychain.remove(key)
    }
}

private nonisolated struct SessionEnvelopeHeader: Decodable {
    let schemaVersion: Int
}
