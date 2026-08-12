import CoreFoundation
import Security

nonisolated struct KeychainSecurityAPI: Sendable {
    typealias CopyMatching = @Sendable (
        CFDictionary,
        UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus
    typealias Update = @Sendable (CFDictionary, CFDictionary) -> OSStatus
    typealias Add = @Sendable (
        CFDictionary,
        UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus
    typealias Delete = @Sendable (CFDictionary) -> OSStatus

    let copyMatching: CopyMatching
    let update: Update
    let add: Add
    let delete: Delete

    static let live = Self(
        copyMatching: { SecItemCopyMatching($0, $1) },
        update: { SecItemUpdate($0, $1) },
        add: { SecItemAdd($0, $1) },
        delete: { SecItemDelete($0) }
    )
}
