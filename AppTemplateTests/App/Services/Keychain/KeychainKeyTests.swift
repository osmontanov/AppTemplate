import Testing
@testable import AppTemplate

struct KeychainKeyTests {
    @Test func factoriesWorkFromNonisolatedContextAndPreserveExactSpelling() {
        constructKeychainKeysFromNonisolatedContext()
        #expect(KeychainKey.data("  Session Token  ").account == "  Session Token  ")
        let key: KeychainCodableKey<FirstSecret> =
            .codable("Session", schemaVersion: 12)
        #expect(key.account == "Session.schema-12")
    }

    @Test func schemaVersionsProduceDifferentPhysicalAccounts() {
        let first: KeychainCodableKey<FirstSecret> = .codable("Session", schemaVersion: 1)
        let second: KeychainCodableKey<FirstSecret> = .codable("Session", schemaVersion: 2)
        #expect(first.account == "Session.schema-1")
        #expect(second.account == "Session.schema-2")
        #expect(first.account != second.account)
    }

    @Test func everyValidationBranchBindsItsExactFixedDiagnostic() {
        #expect(KeychainComponent.keyFailure(" \n\t ") == .blankKey)
        #expect(KeychainValidationFailure.blankKey.rawValue ==
            "Keychain key must not be blank.")
        #expect(KeychainComponent.keyFailure("Bad\0Name") == .nulKey)
        #expect(KeychainValidationFailure.nulKey.rawValue ==
            "Keychain key must not contain NUL.")
        #expect(KeychainComponent.keyFailure("Bad.schema-Name") == .reservedSchemaMarker)
        #expect(KeychainValidationFailure.reservedSchemaMarker.rawValue ==
            "Keychain key must not contain '.schema-'.")
        #expect(KeychainComponent.schemaFailure(0) == .nonpositiveSchemaVersion)
        #expect(KeychainValidationFailure.nonpositiveSchemaVersion.rawValue ==
            "Keychain schema version must be greater than zero.")
        #expect(KeychainComponent.serviceFailure(" \n\t ") == .blankService)
        #expect(KeychainValidationFailure.blankService.rawValue ==
            "Keychain service must not be blank.")
        #expect(KeychainComponent.serviceFailure("Bad\0Service") == .nulService)
        #expect(KeychainValidationFailure.nulService.rawValue ==
            "Keychain service must not contain NUL.")
        #expect(KeychainComponent.keyFailure("  Exact Name  ") == nil)
        #expect(KeychainComponent.serviceFailure("  Exact Service  ") == nil)
        #expect(KeychainComponent.schemaFailure(1) == nil)
    }

    #if os(macOS)
    @Test func blankLogicalNameTerminates() async {
        await #expect(processExitsWith: .failure) {
            _ = KeychainKey.data(" \n\t ")
        }
    }

    @Test func nulLogicalNameTerminates() async {
        await #expect(processExitsWith: .failure) {
            _ = KeychainKey.data("Bad\0Name")
        }
    }

    @Test func reservedSchemaMarkerLogicalNameTerminates() async {
        await #expect(processExitsWith: .failure) {
            _ = KeychainKey.data("Bad.schema-Name")
        }
    }

    @Test func zeroSchemaVersionTerminates() async {
        await #expect(processExitsWith: .failure) {
            let _: KeychainCodableKey<FirstSecret> = .codable("Session", schemaVersion: 0)
        }
    }
    #endif
}

nonisolated private func constructKeychainKeysFromNonisolatedContext() {
    _ = KeychainKey.data("Raw")
    let _: KeychainCodableKey<FirstSecret> = .codable("Model", schemaVersion: 1)
}
