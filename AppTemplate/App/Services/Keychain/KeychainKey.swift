import Foundation
import Security

nonisolated struct KeychainKey: Hashable, Sendable {
    let account: String

    private init(logicalName: String) {
        KeychainComponent.validateKey(logicalName)
        account = logicalName
    }

    init(validatedPhysicalAccount account: String) { self.account = account }

    static func data(_ name: String) -> Self { Self(logicalName: name) }
}

nonisolated struct KeychainCodableKey<Value: Codable & Sendable>: Sendable {
    let account: String

    static func codable(_ name: String, schemaVersion: UInt) -> Self {
        KeychainComponent.validateKey(name)
        KeychainComponent.validateSchema(schemaVersion)
        return Self(account: "\(name).schema-\(schemaVersion)")
    }

    var rawKey: KeychainKey { KeychainKey(validatedPhysicalAccount: account) }
}

nonisolated enum KeychainValidationFailure: String, Equatable, Sendable {
    case blankKey = "Keychain key must not be blank."
    case nulKey = "Keychain key must not contain NUL."
    case reservedSchemaMarker = "Keychain key must not contain '.schema-'."
    case nonpositiveSchemaVersion =
        "Keychain schema version must be greater than zero."
    case blankService = "Keychain service must not be blank."
    case nulService = "Keychain service must not contain NUL."
}

nonisolated enum KeychainComponent {
    static func keyFailure(_ name: String) -> KeychainValidationFailure? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .blankKey
        }
        if name.contains("\0") { return .nulKey }
        if name.contains(".schema-") { return .reservedSchemaMarker }
        return nil
    }

    static func schemaFailure(_ version: UInt) -> KeychainValidationFailure? {
        version > 0 ? nil : .nonpositiveSchemaVersion
    }

    static func serviceFailure(_ service: String) -> KeychainValidationFailure? {
        if service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .blankService
        }
        if service.contains("\0") { return .nulService }
        return nil
    }

    static func validateKey(_ name: String) {
        let failure = keyFailure(name)
        precondition(failure == nil, failure!.rawValue)
    }

    static func validateSchema(_ version: UInt) {
        let failure = schemaFailure(version)
        precondition(failure == nil, failure!.rawValue)
    }

    static func validateService(_ service: String) {
        let failure = serviceFailure(service)
        precondition(failure == nil, failure!.rawValue)
    }
}
