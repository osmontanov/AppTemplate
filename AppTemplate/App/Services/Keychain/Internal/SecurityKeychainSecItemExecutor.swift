import CoreFoundation
import Foundation
import Security

actor SecurityKeychainSecItemExecutor: KeychainSecItemExecuting {
    private let security: KeychainSecurityAPI

    init(security: KeychainSecurityAPI = .live) { self.security = security }

    func copy(service: String, account: String) async throws -> KeychainSecItemCopyResult {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData] = requiredCFBoolean(true)
        query[kSecMatchLimit] = kSecMatchLimitOne
        var object: CFTypeRef?
        try Task.checkCancellation()
        let status = security.copyMatching(query as CFDictionary, &object)
        guard status == errSecSuccess else { return .status(status) }
        guard let object, CFGetTypeID(object) == CFDataGetTypeID() else { return .invalid }
        let source = unsafeDowncast(object, to: CFData.self)
        let count = CFDataGetLength(source)
        guard count > 0 else { return .data(Data()) }
        guard let bytes = CFDataGetBytePtr(source) else { return .invalid }
        return .data(Data(bytes: bytes, count: count))
    }

    func update(service: String, account: String, data: Data) async throws -> OSStatus {
        let query = baseQuery(service: service, account: account)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        try Task.checkCancellation()
        return security.update(query as CFDictionary, attributes as CFDictionary)
    }

    func add(service: String, account: String, data: Data) async throws -> OSStatus {
        var attributes = baseQuery(service: service, account: account)
        attributes[kSecValueData] = data
        attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        try Task.checkCancellation()
        return security.add(attributes as CFDictionary, nil)
    }

    func delete(service: String, account: String) async throws -> OSStatus {
        let query = baseQuery(service: service, account: account)
        try Task.checkCancellation()
        return security.delete(query as CFDictionary)
    }

    private func baseQuery(service: String, account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: requiredCFBoolean(false),
            kSecUseDataProtectionKeychain: requiredCFBoolean(true)
        ]
    }
}

nonisolated private func requiredCFBoolean(_ value: Bool) -> CFBoolean {
    value ? kCFBooleanTrue! : kCFBooleanFalse!
}
