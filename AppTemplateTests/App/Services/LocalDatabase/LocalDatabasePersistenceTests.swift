import Foundation
import SwiftData
import Testing
@testable import AppTemplate

@Suite(.serialized)
struct LocalDatabasePersistenceTests {
    @Test
    func genericServiceReopeningDiskStoreRetainsMutations() async throws {
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

        let reopened: any ILocalDatabaseService = LocalDatabaseService(
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
    func genericServiceReopeningDiskStoreRetainsDeleteAll() async throws {
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

        let reopened: any ILocalDatabaseService = LocalDatabaseService(
            configuration: .disk(url: url)
        )
        #expect(
            try await reopened.fetch(
                ExampleRecord.self,
                matching: ExampleQuery(limit: 10)
            ).isEmpty
        )
    }

    @Test
    func genericServiceOpensStoreSeededDirectlyThroughFrozenV1Entity()
        async throws
    {
        let url = try uniqueLocalDatabaseStoreURL(label: "direct-frozen-v1")
        let expected = [
            ExampleRecord(id: " spaced id ", payload: ""),
            ExampleRecord(id: "case", payload: "lowercase"),
            ExampleRecord(id: "Case", payload: "uppercase"),
            ExampleRecord(id: "unicode", payload: "Кыргызча 🌏")
        ]

        do {
            let container = try LocalDatabaseContainerFactories.disk(
                url: url
            )()
            let context = ModelContext(container)
            context.autosaveEnabled = false
            for record in expected {
                context.insert(
                    LocalDatabaseSchemaV1.StoredExampleRecord(
                        id: record.id,
                        payload: record.payload
                    )
                )
            }
            try context.save()
        }

        let service: any ILocalDatabaseService = LocalDatabaseService(
            configuration: .disk(url: url)
        )

        for record in expected {
            #expect(
                try await service.fetch(
                    ExampleRecord.self,
                    id: record.id
                ) == record
            )
        }
        let queried = try await service.fetch(
            ExampleRecord.self,
            matching: ExampleQuery(limit: 200)
        )
        #expect(queried.map(\.id) == expected.map(\.id))
        #expect(queried.map(\.payload) == expected.map(\.payload))
        #expect(queried == expected)
    }
}
