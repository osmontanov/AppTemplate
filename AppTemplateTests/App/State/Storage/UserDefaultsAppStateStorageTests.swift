import Foundation
import Testing
@testable import AppTemplate

struct UserDefaultsAppStateStorageTests {
    @Test
    func dataRoundTripsUnderTheStableKeyAndCanBeRemoved() throws {
        let suiteName = "AppTemplateTests.AppState.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storage = UserDefaultsAppStateStorage(userDefaults: defaults)
        let data = Data([0x01, 0x02, 0x03])

        #expect(storage.load() == .missing)

        storage.save(data)

        #expect(storage.load() == .data(data))
        #expect(
            defaults.data(forKey: UserDefaultsAppStateStorage.key) == data
        )

        storage.remove()

        #expect(storage.load() == .missing)
    }

    @Test
    func existingNonDataValueIsReportedAsInvalid() throws {
        let suiteName = "AppTemplateTests.AppState.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            "not-data",
            forKey: UserDefaultsAppStateStorage.key
        )
        let storage = UserDefaultsAppStateStorage(userDefaults: defaults)

        #expect(storage.load() == .invalidValue)
    }
}
