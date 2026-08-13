import Foundation
import Testing
@testable import AppTemplate

struct SessionSecureStoreTests {
    private let sessionKey = KeychainKey.data("Store.AuthSession")

    @Test func missingRecordUsesExactPhysicalAccountWithoutMutatingStorage() async throws {
        let keychain = KeychainServiceSpy()
        let store = SessionSecureStore(keychain: keychain)

        #expect(try await store.read() == .missing)
        #expect(await keychain.reads.map(\.account) == ["Store.AuthSession"])
        #expect(await keychain.callCounts().removals == 0)
    }

    @Test func currentEnvelopeRoundTripsThroughSchemaStoredInsideRawBytes() async throws {
        let expected = fixtureEnvelope()
        let keychain = KeychainServiceSpy()
        let store = SessionSecureStore(keychain: keychain)

        try await store.write(expected)

        let writes = await keychain.writes
        #expect(writes.count == 1)
        #expect(writes.first?.0.account == "Store.AuthSession")
        let writtenData = try #require(writes.first?.1)
        let object = try #require(
            try JSONSerialization.jsonObject(with: writtenData) as? [String: Any]
        )
        #expect(object["schemaVersion"] as? Int == 1)

        guard case let .envelope(actual) = try await store.read() else {
            Issue.record("Expected a current session envelope")
            return
        }
        #expect(actual.profile == expected.profile)
        #expect(actual.accessExpiresAt == expected.accessExpiresAt)
        #expect(actual.refreshExpiresAt == expected.refreshExpiresAt)
        #expect(tokensMatch(actual, expected))
        #expect(await keychain.callCounts().removals == 0)
    }

    @Test func futureHeaderWinsOverIncompatiblePayloadAndPreservesExactBytes() async throws {
        let bytes = Data(
            #"{"schemaVersion":2,"profile":"future-shape","accessToken":{"opaque":true}}"#.utf8
        )
        let keychain = KeychainServiceSpy(storage: [sessionKey: bytes])
        let store = SessionSecureStore(keychain: keychain)

        #expect(try await store.read() == .unsupportedSchema(2))
        #expect(await keychain.storedData(for: sessionKey) == bytes)
        #expect(await keychain.callCounts().removals == 0)
    }

    @Test func malformedMissingAndNonCurrentHeadersAreCorruptWithoutCleanup() async throws {
        let corruptRecords = [
            Data("not-json".utf8),
            Data(#"{"profile":{}}"#.utf8),
            Data(#"{"schemaVersion":"1"}"#.utf8),
            Data(#"{"schemaVersion":0}"#.utf8),
            Data(#"{"schemaVersion":1}"#.utf8)
        ]

        for bytes in corruptRecords {
            let keychain = KeychainServiceSpy(storage: [sessionKey: bytes])
            let store = SessionSecureStore(keychain: keychain)

            #expect(try await store.read() == .corruptEnvelope)
            #expect(await keychain.storedData(for: sessionKey) == bytes)
            #expect(await keychain.callCounts().removals == 0)
        }
    }

    @Test func removeDelegatesExactAccountAndReturnsPresence() async throws {
        let bytes = Data("record".utf8)
        let keychain = KeychainServiceSpy(storage: [sessionKey: bytes])
        let store = SessionSecureStore(keychain: keychain)

        #expect(try await store.remove())
        #expect(try await !store.remove())
        #expect(await keychain.removals.map(\.account) == [
            "Store.AuthSession", "Store.AuthSession"
        ])
    }

    @Test func keychainFailuresRemainThrownForEveryOperation() async {
        let store = SessionSecureStore(keychain: ThrowingSessionKeychain())

        await #expect(throws: SessionStoreFailure.unavailable) {
            _ = try await store.read()
        }
        await #expect(throws: SessionStoreFailure.unavailable) {
            try await store.write(fixtureEnvelope())
        }
        await #expect(throws: SessionStoreFailure.unavailable) {
            _ = try await store.remove()
        }
    }

    private func fixtureEnvelope() -> StoredSessionEnvelope {
        StoredSessionEnvelope(
            schemaVersion: 1,
            profile: UserProfile(
                id: 7,
                username: "reader",
                firstName: "Ada",
                lastName: "Lovelace",
                imageURL: URL(string: "https://example.test/avatar.png")
            ),
            accessToken: "fixture-access-value",
            refreshToken: "fixture-refresh-value",
            accessExpiresAt: Date(timeIntervalSince1970: 1_735_689_600),
            refreshExpiresAt: Date(timeIntervalSince1970: 1_738_281_600)
        )
    }

    private func tokensMatch(
        _ actual: StoredSessionEnvelope,
        _ expected: StoredSessionEnvelope
    ) -> Bool {
        actual.accessToken == expected.accessToken
            && actual.refreshToken == expected.refreshToken
    }
}

private enum SessionStoreFailure: Error, Equatable {
    case unavailable
}

private actor ThrowingSessionKeychain: IKeychainService {
    func data(for key: KeychainKey) async throws -> Data? {
        throw SessionStoreFailure.unavailable
    }

    func set(_ data: Data, for key: KeychainKey) async throws {
        throw SessionStoreFailure.unavailable
    }

    func remove(_ key: KeychainKey) async throws -> Bool {
        throw SessionStoreFailure.unavailable
    }
}
