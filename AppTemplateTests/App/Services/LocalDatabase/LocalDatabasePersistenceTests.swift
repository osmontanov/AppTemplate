import Testing
@testable import AppTemplate

struct LocalDatabasePersistenceTests {
    @Test
    func reopeningDiskStoreRetainsMutations() async throws {
        let url = try uniqueLocalDatabaseStoreURL(label: "reopen")
        var firstService: LocalDatabaseService? = LocalDatabaseService(
            configuration: .disk(url: url)
        )
        weak let releasedService = firstService
        try await firstService?.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])
        try await firstService?.upsert(
            ExampleRecord(id: "a", payload: "updated")
        )
        _ = try await firstService?.delete(ExampleRecord.self, id: "b")
        let detachedValue = try #require(
            try await firstService?.fetch(ExampleRecord.self, id: "a")
        )
        firstService = nil
        #expect(releasedService == nil)
        #expect(detachedValue == ExampleRecord(id: "a", payload: "updated"))

        let reopened = LocalDatabaseService(
            configuration: .disk(url: url)
        )
        #expect(
            try await reopened.fetch(ExampleRecord.self, id: "a")
                == ExampleRecord(id: "a", payload: "updated")
        )
        #expect(
            try await reopened.fetch(ExampleRecord.self, id: "b") == nil
        )
    }

    @Test
    func reopeningDiskStoreRetainsDeleteAll() async throws {
        let url = try uniqueLocalDatabaseStoreURL(label: "reopen-delete-all")
        var firstService: LocalDatabaseService? = LocalDatabaseService(
            configuration: .disk(url: url)
        )
        weak let releasedService = firstService
        try await firstService?.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])
        #expect(
            try await firstService?.deleteAll(ExampleRecord.self) == 2
        )
        firstService = nil
        #expect(releasedService == nil)

        let reopened = LocalDatabaseService(
            configuration: .disk(url: url)
        )
        #expect(
            try await reopened.fetch(
                ExampleRecord.self,
                matching: ExampleQuery(limit: 10)
            ).isEmpty
        )
    }
}
