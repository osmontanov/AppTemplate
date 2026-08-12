#if KEYCHAIN_CODABLE_TYPE_MISMATCH_COMPILE_FIXTURE
@testable import AppTemplate

nonisolated func keychainCodableTypeMismatch(
    service: any IKeychainService,
    key: KeychainCodableKey<FirstSecret>
) async throws {
    let _: SecondSecret? = try await service.value(for: key)
}
#endif
