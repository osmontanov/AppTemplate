import Foundation
import Testing
@testable import AppTemplate

struct InMemoryAppStateStorageTests {
    @Test
    func missingInitialDataLoadsAsMissing() throws {
        let storage = InMemoryAppStateStorage()

        #expect(try storage.load() == .missing)
    }

    @Test
    func savedDataLoadsFromTheSameInstance() throws {
        let storage = InMemoryAppStateStorage()
        let data = Data([0x01, 0x02, 0x03])

        try storage.save(data)

        #expect(try storage.load() == .data(data))
    }

    @Test
    func removedDataLoadsAsMissing() throws {
        let storage = InMemoryAppStateStorage(initialData: Data([0x01]))

        try storage.remove()

        #expect(try storage.load() == .missing)
    }

    @Test
    func separateInstancesDoNotShareData() throws {
        let first = InMemoryAppStateStorage()
        let second = InMemoryAppStateStorage()
        let data = Data([0x01, 0x02, 0x03])

        try first.save(data)

        #expect(try first.load() == .data(data))
        #expect(try second.load() == .missing)
    }

    @Test
    func initialStateEncodesForDeterministicFixtures() throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let storage = InMemoryAppStateStorage(initialState: state)

        let data = try #require({
            if case let .data(data) = try storage.load() {
                return data
            }
            return nil
        }())

        #expect(try JSONDecoder().decode(AppState.self, from: data) == state)
    }
}
