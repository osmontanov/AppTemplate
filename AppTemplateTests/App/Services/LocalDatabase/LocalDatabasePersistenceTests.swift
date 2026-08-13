import Foundation
import SwiftData
import Testing
@testable import AppTemplate

@Suite(.serialized)
struct LocalDatabasePersistenceTests {
    @Test
    func cursorOrderAndLegacyFacadeMutationsRemainStableAcrossReopen()
        async throws
    {
        let url = try uniqueLocalDatabaseStoreURL(label: "cursor-reopen")
        let seeded = [
            ExampleRecord(id: "ascii", payload: "ASCII"),
            ExampleRecord(id: " Legacy-ID ", payload: "spaced"),
            ExampleRecord(id: "MiXeD", payload: "mixed"),
            ExampleRecord(id: "жаз", payload: "Unicode 🌏")
        ]
        var firstService: LocalDatabaseService? = LocalDatabaseService(
            configuration: .disk(url: url)
        )
        weak let releasedService = firstService
        try await firstService?.upsert(seeded)
        let before = try #require(
            try await firstService?.fetch(
                ExampleRecord.self,
                matching: ExampleQuery(limit: 200)
            )
        )
        var firstRepository = firstService.map(
            LocalDatabaseExampleRepository.init(database:)
        )
        let firstPage = try await firstRepository?.page(
            searchText: nil,
            afterID: nil,
            pageSize: 2
        )
        let secondPage = try await firstRepository?.page(
            searchText: nil,
            afterID: firstPage?.nextCursor,
            pageSize: 2
        )

        firstRepository = nil
        firstService = nil
        #expect(releasedService == nil)

        let reopenedService: any ILocalDatabaseService = LocalDatabaseService(
            configuration: .disk(url: url)
        )
        let reopenedRepository = LocalDatabaseExampleRepository(
            database: reopenedService
        )
        let after = try await reopenedService.fetch(
            ExampleRecord.self,
            matching: ExampleQuery(limit: 200)
        )
        let reopenedFirstPage = try await reopenedRepository.page(
            searchText: nil,
            afterID: nil,
            pageSize: 2
        )
        let reopenedSecondPage = try await reopenedRepository.page(
            searchText: nil,
            afterID: reopenedFirstPage.nextCursor,
            pageSize: 2
        )

        #expect(after == before)
        #expect(reopenedFirstPage.values == firstPage?.values)
        #expect(reopenedFirstPage.nextCursor == firstPage?.nextCursor)
        #expect(reopenedSecondPage.values == secondPage?.values)

        #expect(
            try await reopenedRepository.fetch(id: " Legacy-ID ")
                == ExampleRecord(id: " Legacy-ID ", payload: "spaced")
        )
        try await reopenedRepository.update(
            id: "MiXeD",
            payload: "changed"
        )
        #expect(
            try await reopenedRepository.fetch(id: "MiXeD")?.payload
                == "changed"
        )
        #expect(try await reopenedRepository.delete(id: "жаз"))
    }

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
    func genericServiceOpensStoreSeededDirectlyThroughActiveV2Entity()
        async throws
    {
        let url = try uniqueLocalDatabaseStoreURL(label: "direct-v2")
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
                    LocalDatabaseSchemaV2.StoredExampleRecord(
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
