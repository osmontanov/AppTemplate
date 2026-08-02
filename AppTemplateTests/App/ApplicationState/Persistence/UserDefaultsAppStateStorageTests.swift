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

        #expect(try storage.load() == .missing)

        try storage.save(data)

        #expect(try storage.load() == .data(data))
        #expect(
            defaults.data(forKey: UserDefaultsAppStateStorage.key) == data
        )

        try storage.remove()

        #expect(try storage.load() == .missing)
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

        #expect(try storage.load() == .invalidValue)
    }
}
