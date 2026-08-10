import Foundation
import Testing
@testable import AppTemplate

struct SwiftDataLocalStoreQueryTests {
    @Test
    func unfilteredResultsUseStoreIDOrderAndLimit() async throws {
        let store = try makeInMemoryLocalStore()
        try await store.upsert([
            ExampleRecord(id: "c", payload: "three"),
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])

        let records = try await store.fetchRecords(
            matching: ExampleQuery(limit: 2)
        )

        #expect(records.map(\.id) == ["a", "b"])
    }

    @Test
    func searchUsesTrimmedCaseDiacriticAndWidthInsensitiveSubstring() async throws {
        let store = try makeInMemoryLocalStore()
        try await store.upsert([
            ExampleRecord(id: "a", payload: "Résumé Café"),
            ExampleRecord(id: "b", payload: "ＰＡＹＬＯＡＤ value"),
            ExampleRecord(id: "c", payload: "other")
        ])

        #expect(
            try await store.fetchRecords(
                matching: ExampleQuery(searchText: "  cafe  ")
            ).map(\.id) == ["a"]
        )
        #expect(
            try await store.fetchRecords(
                matching: ExampleQuery(searchText: "payload")
            ).map(\.id) == ["b"]
        )
        #expect(
            try await store.fetchRecords(
                matching: ExampleQuery(searchText: "   ")
            ).count == 3
        )
    }

    @Test
    func filteredSearchContinuesPastFirstStorageBatch() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let records = (0..<130).map { index in
            ExampleRecord(
                id: String(format: "item-%03d", index),
                payload: index == 129 ? "needle" : "haystack"
            )
        }
        try await store.upsert(records)

        let result = try await store.fetchRecords(
            matching: ExampleQuery(searchText: "needle", limit: 1)
        )

        #expect(result.map(\.id) == ["item-129"])
        #expect(
            recorder.checkpoints.contains(.readProgress(.fetchMany))
        )
    }

    @Test
    func filteredSearchDoesNotCheckpointBeforeExamining128Entities() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        try await store.upsert(
            (0..<127).map {
                ExampleRecord(
                    id: String(format: "item-%03d", $0),
                    payload: "haystack"
                )
            }
        )

        let result = try await store.fetchRecords(
            matching: ExampleQuery(searchText: "missing")
        )

        #expect(result.isEmpty)
        #expect(
            !recorder.checkpoints.contains(.readProgress(.fetchMany))
        )
    }

    @Test
    func cancellationAt128thMatchingEntityPrecedesLimitReturn() async throws {
        let recorder = LocalDatabaseHookRecorder(
            cancellingCheckpoint: .readProgress(.fetchMany)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        try await store.upsert(
            (0..<128).map { index in
                ExampleRecord(
                    id: String(format: "item-%03d", index),
                    payload: index == 127 ? "needle" : "haystack"
                )
            }
        )
        let request = Task { () -> Result<[ExampleRecord], any Error> in
            do {
                return .success(
                    try await store.fetchRecords(
                        matching: ExampleQuery(
                            searchText: "needle",
                            limit: 1
                        )
                    )
                )
            } catch {
                return .failure(error)
            }
        }

        switch await request.value {
        case .success:
            Issue.record("Expected cancellation before limit return")
        case let .failure(error):
            #expect(error is CancellationError)
        }
    }

    @Test
    func filteredSearchStopsBeforeUnneededProgressCheckpoint() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        try await store.upsert(
            (0..<130).map { index in
                ExampleRecord(
                    id: String(format: "item-%03d", index),
                    payload: index == 0 ? "needle" : "haystack"
                )
            }
        )

        let result = try await store.fetchRecords(
            matching: ExampleQuery(searchText: "needle", limit: 1)
        )

        #expect(result.map(\.id) == ["item-000"])
        #expect(
            !recorder.checkpoints.contains(.readProgress(.fetchMany))
        )
    }

    @Test
    func filteredSearchReturnsEmptyWhenNothingMatches() async throws {
        let store = try makeInMemoryLocalStore()
        try await store.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])

        #expect(
            try await store.fetchRecords(
                matching: ExampleQuery(searchText: "missing", limit: 1)
            ).isEmpty
        )
    }

    @Test
    func filteredReadCancellationUsesChildAndLeavesStoreUsable() async throws {
        let recorder = LocalDatabaseHookRecorder(
            cancellingCheckpoint: .readProgress(.fetchMany)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        try await store.upsert(
            (0..<130).map {
                ExampleRecord(
                    id: String(format: "item-%03d", $0),
                    payload: "haystack"
                )
            }
        )
        let request = Task { () -> Result<[ExampleRecord], any Error> in
            do {
                return .success(
                    try await store.fetchRecords(
                        matching: ExampleQuery(searchText: "missing")
                    )
                )
            } catch {
                return .failure(error)
            }
        }

        switch await request.value {
        case .success:
            Issue.record("Expected cancellation")
        case let .failure(error):
            #expect(error is CancellationError)
        }
        #expect(
            try await store.fetchRecords(
                matching: ExampleQuery(limit: 1)
            ).count == 1
        )
    }

    @Test
    func fetchManyCheckpointFailureMapsReadOperation() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .read(.fetchMany)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        do {
            _ = try await store.fetchRecords(matching: ExampleQuery())
            Issue.record("Expected read failure")
        } catch let error as LocalDatabaseError {
            guard case let .read(operation, _) = error else {
                Issue.record("Expected LocalDatabaseError.read")
                return
            }
            #expect(operation == .fetchMany)
        }
    }
}
