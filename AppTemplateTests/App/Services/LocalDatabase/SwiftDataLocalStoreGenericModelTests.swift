import Foundation
import Testing
@testable import AppTemplate

struct SwiftDataLocalStoreGenericModelTests {
    @Test
    func oneGenericStoreRoundTripsExampleAndDistinctIDTestValues()
        async throws
    {
        let store = try makeGenericLocalStore()
        let example = ExampleRecord(id: "example", payload: "value")
        let test = TestLocalRecord(
            id: TestLocalRecordID(rawValue: 41),
            score: 7,
            title: "distinct"
        )

        try await store.upsert(example)
        try await store.upsert(test)

        #expect(
            try await store.fetch(ExampleRecord.self, id: example.id)
                == example
        )
        #expect(
            try await store.fetch(TestLocalRecord.self, id: test.id) == test
        )
    }

    @Test
    func genericServiceExistentialRoundTripsBothRegisteredModels()
        async throws
    {
        let database: any ILocalDatabaseService = LocalDatabaseService(
            configuration: makeGenericTestConfiguration()
        )
        let example = ExampleRecord(id: "example", payload: "payload")
        let test = TestLocalRecord(
            id: TestLocalRecordID(rawValue: 73),
            score: 11,
            title: "numeric"
        )

        try await database.upsert(example)
        try await database.upsert(test)

        #expect(
            try await database.fetch(ExampleRecord.self, id: example.id)
                == example
        )
        #expect(
            try await database.fetch(TestLocalRecord.self, id: test.id)
                == test
        )
    }

    @Test
    func testModelFetchAndDeleteHandleMissingAndPresentDistinctIDs()
        async throws
    {
        let database: any ILocalDatabaseService = LocalDatabaseService(
            configuration: makeGenericTestConfiguration()
        )
        let example = ExampleRecord(id: "survivor", payload: "example")
        let test = TestLocalRecord(
            id: TestLocalRecordID(rawValue: 5),
            score: 50,
            title: "delete me"
        )
        let missingID = TestLocalRecordID(rawValue: 404)
        try await database.upsert(example)
        try await database.upsert(test)

        #expect(
            try await database.fetch(TestLocalRecord.self, id: missingID)
                == nil
        )
        #expect(
            try await database.delete(TestLocalRecord.self, id: missingID)
                == false
        )
        #expect(
            try await database.delete(TestLocalRecord.self, id: test.id)
        )
        #expect(
            try await database.fetch(TestLocalRecord.self, id: test.id)
                == nil
        )
        #expect(
            try await database.fetch(ExampleRecord.self, id: example.id)
                == example
        )
    }

    @Test
    func testAdapterRejectsOutOfRangeQueryLimits() async throws {
        let database: any ILocalDatabaseService = LocalDatabaseService(
            configuration: makeGenericTestConfiguration()
        )

        for invalidLimit in [0, 201] {
            do {
                _ = try await database.fetch(
                    TestLocalRecord.self,
                    matching: TestLocalQuery(limit: invalidLimit)
                )
                Issue.record("Expected invalid TestLocalQuery limit")
            } catch let error as LocalDatabaseError {
                guard case let .validation(model, reason) = error else {
                    Issue.record("Expected LocalDatabaseError.validation")
                    continue
                }
                #expect(model == "StoredTestLocalRecord")
                #expect(
                    reason == .invalidLimit(
                        actual: invalidLimit,
                        allowed: 1...200
                    )
                )
            }
        }

        for validLimit in [1, 200] {
            #expect(
                try await database.fetch(
                    TestLocalRecord.self,
                    matching: TestLocalQuery(limit: validLimit)
                ).isEmpty
            )
        }
    }

    @Test
    func testModelBatchMixesInsertAndUpdate() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeGenericLocalStore(hooks: recorder.hooks())
        try await store.upsert([
            testRecord(id: 1, score: 10, title: "one"),
            testRecord(id: 2, score: 20, title: "two")
        ])
        let saveCountBeforeMutation = recorder.saves.count

        try await store.upsert([
            testRecord(id: 1, score: 100, title: "updated"),
            testRecord(id: 3, score: 30, title: "three")
        ])

        #expect(recorder.saves.count - saveCountBeforeMutation == 1)
        #expect(
            try await store.fetch(
                TestLocalRecord.self,
                matching: TestLocalQuery(limit: 200)
            ) == [
                testRecord(id: 2, score: 20, title: "two"),
                testRecord(id: 3, score: 30, title: "three"),
                testRecord(id: 1, score: 100, title: "updated")
            ]
        )
    }

    @Test
    func testModelValuesRemainDetachedAfterOperation() async throws {
        var store: SwiftDataLocalStore? = try makeGenericLocalStore()
        weak let releasedStore = store
        let expected = testRecord(id: 9, score: 90, title: "detached")
        try await store?.upsert(expected)
        let detached = try #require(
            try await store?.fetch(TestLocalRecord.self, id: expected.id)
        )

        store = nil

        #expect(releasedStore == nil)
        #expect(detached == expected)
    }

    @Test
    func deleteAllIsScopedToRequestedModel() async throws {
        let store = try makeGenericLocalStore()
        let example = ExampleRecord(id: "survivor", payload: "example")
        try await store.upsert(example)
        try await store.upsert([
            testRecord(id: 1, score: 10, title: "one"),
            testRecord(id: 2, score: 20, title: "two")
        ])

        #expect(try await store.deleteAll(TestLocalRecord.self) == 2)
        #expect(
            try await store.fetch(ExampleRecord.self, id: example.id)
                == example
        )
        #expect(
            try await store.fetch(
                TestLocalRecord.self,
                matching: TestLocalQuery(limit: 200)
            ).isEmpty
        )
    }

    @Test
    func testModelWriteFailureUsesItsOwnDiagnosticName() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .beforeSave(.upsertOne)
        )
        let store = try makeGenericLocalStore(hooks: recorder.hooks())
        let record = testRecord(id: 8, score: 80, title: "rollback")

        do {
            try await store.upsert(record)
            Issue.record("Expected TestLocalRecord write failure")
        } catch let error as LocalDatabaseError {
            guard case let .write(model, operation, underlying) = error else {
                Issue.record("Expected LocalDatabaseError.write")
                return
            }
            #expect(model == "StoredTestLocalRecord")
            #expect(operation == .upsertOne)
            #expect(
                (underlying as? LocalDatabaseTestError) == .injectedFailure
            )
        }

        #expect(
            try await store.fetch(TestLocalRecord.self, id: record.id) == nil
        )
    }

    @Test
    func testQueryFiltersMinimumScoreSortsByScoreThenIDAndHonorsLimit()
        async throws
    {
        let store = try makeGenericLocalStore()
        try await store.upsert(
            testRecord(id: 9, score: 10, title: "below")
        )
        try await store.upsert(
            testRecord(id: 4, score: 20, title: "tie-high-id")
        )
        try await store.upsert(
            testRecord(id: 2, score: 20, title: "tie-low-id")
        )
        try await store.upsert(
            testRecord(id: 1, score: 30, title: "highest")
        )

        #expect(
            try await store.fetch(
                TestLocalRecord.self,
                matching: TestLocalQuery(minimumScore: 20, limit: 3)
            ) == [
                testRecord(id: 2, score: 20, title: "tie-low-id"),
                testRecord(id: 4, score: 20, title: "tie-high-id"),
                testRecord(id: 1, score: 30, title: "highest")
            ]
        )
    }

    @Test
    func testQueryReturnsEmptyWhenNothingQualifies() async throws {
        let store = try makeGenericLocalStore()
        try await store.upsert([
            testRecord(id: 1, score: 10, title: "one"),
            testRecord(id: 2, score: 20, title: "two")
        ])

        #expect(
            try await store.fetch(
                TestLocalRecord.self,
                matching: TestLocalQuery(minimumScore: 21, limit: 200)
            ).isEmpty
        )
    }

    @Test
    func testQueryDoesNotReportProgressBefore128Examined() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeGenericLocalStore(hooks: recorder.hooks())
        try await store.upsert(testRecords(in: 0..<127))

        #expect(
            try await store.fetch(
                TestLocalRecord.self,
                matching: TestLocalQuery(
                    minimumScore: 1_000,
                    limit: 200
                )
            ).isEmpty
        )
        #expect(
            !recorder.checkpoints.contains(.readProgress(.fetchMany))
        )
    }

    @Test
    func testQueryReportsProgressAtExactly128Examined() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeGenericLocalStore(hooks: recorder.hooks())
        try await store.upsert(testRecords(in: 0..<128))

        #expect(
            try await store.fetch(
                TestLocalRecord.self,
                matching: TestLocalQuery(
                    minimumScore: 1_000,
                    limit: 200
                )
            ).isEmpty
        )
        #expect(
            recorder.checkpoints.filter {
                $0 == .readProgress(.fetchMany)
            }.count == 1
        )
    }

    @Test
    func testQueryStopsBeforeUnneededProgressCheckpoint() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeGenericLocalStore(hooks: recorder.hooks())
        try await store.upsert(testRecords(in: 0..<130))

        #expect(
            try await store.fetch(
                TestLocalRecord.self,
                matching: TestLocalQuery(limit: 1)
            ) == [testRecord(id: 0, score: 0, title: "record-0")]
        )
        #expect(
            !recorder.checkpoints.contains(.readProgress(.fetchMany))
        )
    }

    @Test
    func testQueryCancellationAt128PrecedesLimitReturn() async throws {
        let recorder = LocalDatabaseHookRecorder(
            cancellingCheckpoint: .readProgress(.fetchMany)
        )
        let store = try makeGenericLocalStore(hooks: recorder.hooks())
        try await store.upsert(testRecords(in: 0..<128))

        let result: Result<[TestLocalRecord], any Error> =
            await resultOfChildTask {
                try await store.fetch(
                    TestLocalRecord.self,
                    matching: TestLocalQuery(
                        minimumScore: 127,
                        limit: 1
                    )
                )
            }

        guard case let .failure(error) = result else {
            Issue.record("Expected cancellation before limit return")
            return
        }
        #expect(error is CancellationError)
    }

    @Test
    func testQueryCancellationLeavesGenericStoreUsable() async throws {
        let recorder = LocalDatabaseHookRecorder(
            cancellingCheckpoint: .readProgress(.fetchMany)
        )
        let store = try makeGenericLocalStore(hooks: recorder.hooks())
        try await store.upsert(testRecords(in: 0..<128))

        let result: Result<[TestLocalRecord], any Error> =
            await resultOfChildTask {
                try await store.fetch(
                    TestLocalRecord.self,
                    matching: TestLocalQuery(
                        minimumScore: 1_000,
                        limit: 200
                    )
                )
            }

        guard case let .failure(error) = result else {
            Issue.record("Expected cancelled generic query")
            return
        }
        #expect(error is CancellationError)
        #expect(
            try await store.fetch(
                TestLocalRecord.self,
                id: TestLocalRecordID(rawValue: 64)
            ) == testRecord(id: 64, score: 64, title: "record-64")
        )
    }
}

private func makeGenericLocalStore(
    hooks: LocalDatabaseStoreHooks = .production
) throws -> SwiftDataLocalStore {
    SwiftDataLocalStore(
        modelContainer: try makeGenericInMemoryLocalDatabaseContainer(),
        hooks: hooks
    )
}

private func testRecord(
    id: Int,
    score: Int,
    title: String
) -> TestLocalRecord {
    TestLocalRecord(
        id: TestLocalRecordID(rawValue: id),
        score: score,
        title: title
    )
}

private func testRecords(in range: Range<Int>) -> [TestLocalRecord] {
    range.map { index in
        testRecord(
            id: index,
            score: index,
            title: "record-\(index)"
        )
    }
}
