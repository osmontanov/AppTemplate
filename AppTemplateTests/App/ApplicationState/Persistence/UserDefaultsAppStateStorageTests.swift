import Foundation
import Testing
@testable import AppTemplate

@Suite(.serialized)
struct UserDefaultsAppStateStorageTests {
    private let appStateKey = UserDefaultsServiceSpy.KeyRecord(
        logicalName: "AppState",
        physicalKind: .data
    )

    @Test
    func missingServiceValueMapsToMissing() throws {
        let service = UserDefaultsServiceSpy()
        let storage = UserDefaultsAppStateStorage(userDefaults: service)

        #expect(try storage.load() == .missing)
        #expect(service.requestedValueKeys == [appStateKey])
        #expect(service.requestedSetKeys.isEmpty)
        #expect(service.requestedRemoveKeys.isEmpty)
    }

    @Test
    func serviceDataLoadsByteForByteThroughFixedAppStateKey() throws {
        let sentinel = Data([0x00, 0x01, 0x7F, 0x80, 0xFF])
        let service = UserDefaultsServiceSpy(value: sentinel)
        let storage = UserDefaultsAppStateStorage(userDefaults: service)

        #expect(try storage.load() == .data(sentinel))
        #expect(service.requestedValueKeys == [appStateKey])
        #expect(service.requestedSetKeys.isEmpty)
        #expect(service.requestedRemoveKeys.isEmpty)
    }

    @Test
    func invalidStoredValueMapsToInvalidValue() throws {
        let service = UserDefaultsServiceSpy(
            valueError: UserDefaultsServiceError.invalidStoredValue
        )
        let storage = UserDefaultsAppStateStorage(userDefaults: service)

        #expect(try storage.load() == .invalidValue)
        #expect(service.requestedValueKeys == [appStateKey])
    }

    @Test
    func encodingFailurePropagatesUnchanged() {
        let service = UserDefaultsServiceSpy(
            valueError: UserDefaultsServiceError.encodingFailed
        )
        let storage = UserDefaultsAppStateStorage(userDefaults: service)

        expectLoadError(.encodingFailed, from: storage)
    }

    @Test
    func decodingFailurePropagatesUnchanged() {
        let service = UserDefaultsServiceSpy(
            valueError: UserDefaultsServiceError.decodingFailed
        )
        let storage = UserDefaultsAppStateStorage(userDefaults: service)

        expectLoadError(.decodingFailed, from: storage)
    }

    @Test
    func nonServiceFailurePropagatesUnchanged() {
        let service = UserDefaultsServiceSpy(
            valueError: AppStateStorageFixtureError.sentinel
        )
        let storage = UserDefaultsAppStateStorage(userDefaults: service)

        do {
            _ = try storage.load()
            Issue.record("Expected the sentinel error")
        } catch let error as AppStateStorageFixtureError {
            #expect(error == .sentinel)
        } catch {
            Issue.record("Unexpected error: \(type(of: error))")
        }
    }

    @Test
    func saveForwardsExactBytesThroughFixedAppStateKey() throws {
        let sentinel = Data([0x00, 0x01, 0x7F, 0x80, 0xFF])
        let service = UserDefaultsServiceSpy()
        let storage = UserDefaultsAppStateStorage(userDefaults: service)

        try storage.save(sentinel)

        #expect(service.requestedSetKeys == [appStateKey])
        #expect(service.savedValues == [sentinel])
        #expect(service.requestedValueKeys.isEmpty)
        #expect(service.requestedRemoveKeys.isEmpty)
    }

    @Test
    func removeDelegatesThroughFixedAppStateKey() throws {
        let service = UserDefaultsServiceSpy(value: Data([0x01]))
        let storage = UserDefaultsAppStateStorage(userDefaults: service)

        try storage.remove()

        #expect(service.requestedRemoveKeys == [appStateKey])
        #expect(service.requestedValueKeys.isEmpty)
        #expect(service.requestedSetKeys.isEmpty)
    }

    @Test
    func existingStablePhysicalRecordLoadsByteForByte() throws {
        let sentinel = Data([0x00, 0x01, 0x7F, 0x80, 0xFF])
        let fixture = try makeStableRecordFixture(label: "Existing")
        defer {
            fixture.defaults.removePersistentDomain(forName: fixture.suiteName)
        }
        fixture.defaults.seed(sentinel, forKey: "AppTemplate.AppState")
        let storage = UserDefaultsAppStateStorage(
            userDefaults: UserDefaultsService(
                namespace: "AppTemplate",
                userDefaults: fixture.defaults
            )
        )

        #expect(try storage.load() == .data(sentinel))
        expectOnlyStableRecord(in: fixture.defaults, bytes: sentinel)
        #expect(fixture.defaults.setCallCount == 0)
        #expect(fixture.defaults.removeCallCount == 0)
    }

    @Test
    func saveKeepsStablePhysicalKeyAndRawDataRepresentation() throws {
        let sentinel = Data([0x00, 0x01, 0x7F, 0x80, 0xFF])
        let fixture = try makeStableRecordFixture(label: "Save")
        defer {
            fixture.defaults.removePersistentDomain(forName: fixture.suiteName)
        }
        let storage = UserDefaultsAppStateStorage(
            userDefaults: UserDefaultsService(
                namespace: "AppTemplate",
                userDefaults: fixture.defaults
            )
        )

        try storage.save(sentinel)

        expectOnlyStableRecord(in: fixture.defaults, bytes: sentinel)
        #expect(fixture.defaults.physicalKind(forKey: "AppTemplate.AppState") == .data)
        #expect(fixture.defaults.setCallCount == 1)
        #expect(fixture.defaults.removeCallCount == 0)
    }

    @Test
    func wrongStablePhysicalRecordRemainsInvalidAndUnchanged() throws {
        let fixture = try makeStableRecordFixture(label: "Wrong")
        defer {
            fixture.defaults.removePersistentDomain(forName: fixture.suiteName)
        }
        fixture.defaults.seed("not-data", forKey: "AppTemplate.AppState")
        let storage = UserDefaultsAppStateStorage(
            userDefaults: UserDefaultsService(
                namespace: "AppTemplate",
                userDefaults: fixture.defaults
            )
        )

        #expect(try storage.load() == .invalidValue)
        #expect(
            fixture.defaults.rawObject(forKey: "AppTemplate.AppState") as? String
                == "not-data"
        )
        #expect(fixture.defaults.storedKeys() == ["AppTemplate.AppState"])
        expectNoDuplicatedStableKey(in: fixture.defaults)
        #expect(fixture.defaults.setCallCount == 0)
        #expect(fixture.defaults.removeCallCount == 0)
    }

    @MainActor
    @Test
    func currentAppStateRecordRestoresWithoutRewritingPhysicalBytes() throws {
        let current = Data(
            #"{"schemaVersion":1,"isAuthenticated":true,"hasCompletedOnboarding":true,"isMaintenanceEnabled":false}"#.utf8
        )
        let fixture = try makeStableRecordFixture(label: "Current")
        defer {
            fixture.defaults.removePersistentDomain(forName: fixture.suiteName)
        }
        fixture.defaults.seed(current, forKey: "AppTemplate.AppState")
        let storage = UserDefaultsAppStateStorage(
            userDefaults: UserDefaultsService(
                namespace: "AppTemplate",
                userDefaults: fixture.defaults
            )
        )

        let store = AppStateStore(storage: storage)

        #expect(
            store.state == AppState(
                isAuthenticated: true,
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            )
        )
        #expect(store.persistenceStatus == .writable)
        expectOnlyStableRecord(in: fixture.defaults, bytes: current)
        #expect(fixture.defaults.setCallCount == 0)
        #expect(fixture.defaults.removeCallCount == 0)
    }

    @MainActor
    @Test
    func futureAppStateRecordRemainsByteForByteUntouched() throws {
        let future = Data(#"{"schemaVersion":2,"future":"preserve-me"}"#.utf8)
        let fixture = try makeStableRecordFixture(label: "Future")
        defer {
            fixture.defaults.removePersistentDomain(forName: fixture.suiteName)
        }
        fixture.defaults.seed(future, forKey: "AppTemplate.AppState")
        let storage = UserDefaultsAppStateStorage(
            userDefaults: UserDefaultsService(
                namespace: "AppTemplate",
                userDefaults: fixture.defaults
            )
        )

        let store = AppStateStore(storage: storage)

        #expect(store.state == .initial)
        #expect(
            store.persistenceStatus == .readOnly(
                .unsupportedFutureSchema(2)
            )
        )
        expectOnlyStableRecord(in: fixture.defaults, bytes: future)
        #expect(fixture.defaults.setCallCount == 0)
        #expect(fixture.defaults.removeCallCount == 0)
    }

    private func expectLoadError(
        _ expected: UserDefaultsServiceError,
        from storage: UserDefaultsAppStateStorage
    ) {
        do {
            _ = try storage.load()
            Issue.record("Expected UserDefaultsServiceError.\(expected)")
        } catch let error as UserDefaultsServiceError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error: \(type(of: error))")
        }
    }

    private func makeStableRecordFixture(
        label: String
    ) throws -> (suiteName: String, defaults: RecordingUserDefaults) {
        try makeRecordingUserDefaults(label: "AppState-\(label)")
    }

    private func expectOnlyStableRecord(
        in defaults: RecordingUserDefaults,
        bytes: Data
    ) {
        #expect(
            defaults.rawObject(forKey: "AppTemplate.AppState") as? Data == bytes
        )
        #expect(defaults.storedKeys() == ["AppTemplate.AppState"])
        expectNoDuplicatedStableKey(in: defaults)
    }

    private func expectNoDuplicatedStableKey(
        in defaults: RecordingUserDefaults
    ) {
        #expect(defaults.rawObject(forKey: "AppState") == nil)
        #expect(
            defaults.rawObject(forKey: "AppTemplate.AppTemplate.AppState") == nil
        )
    }
}

nonisolated
private enum AppStateStorageFixtureError: Error, Equatable, Sendable {
    case sentinel
}
