import Testing
@testable import AppTemplate

struct LocalDatabasePersistenceTests {
    @Test
    func reopeningDiskStoreRetainsMutations() async throws {
        let url = try uniqueLocalDatabaseStoreURL(label: "reopen")
        var firstService: LocalDatabaseService? = LocalDatabaseService(
            containerFactory: LocalDatabaseContainerFactories.disk(url: url)
        )
        weak let releasedService = firstService
        try await firstService?.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])
        try await firstService?.upsert(
            ExampleRecord(id: "a", payload: "updated")
        )
        _ = try await firstService?.deleteRecord(id: "b")
        let detachedValue = try #require(
            try await firstService?.fetchRecord(id: "a")
        )
        firstService = nil
        #expect(releasedService == nil)
        #expect(detachedValue == ExampleRecord(id: "a", payload: "updated"))

        let reopened = LocalDatabaseService(
            containerFactory: LocalDatabaseContainerFactories.disk(url: url)
        )
        #expect(
            try await reopened.fetchRecord(id: "a")
                == ExampleRecord(id: "a", payload: "updated")
        )
        #expect(try await reopened.fetchRecord(id: "b") == nil)
    }

    @Test
    func reopeningDiskStoreRetainsDeleteAll() async throws {
        let url = try uniqueLocalDatabaseStoreURL(label: "reopen-delete-all")
        var firstService: LocalDatabaseService? = LocalDatabaseService(
            containerFactory: LocalDatabaseContainerFactories.disk(url: url)
        )
        weak let releasedService = firstService
        try await firstService?.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])
        #expect(try await firstService?.deleteAllRecords() == 2)
        firstService = nil
        #expect(releasedService == nil)

        let reopened = LocalDatabaseService(
            containerFactory: LocalDatabaseContainerFactories.disk(url: url)
        )
        #expect(
            try await reopened.fetchRecords(
                matching: ExampleQuery(limit: 10)
            ).isEmpty
        )
    }
}
