import Foundation
import Testing
@testable import AppTemplate

struct LocalDatabaseExampleRepositoryTests {
    @Test(arguments: ["", " ", "\n\t"])
    func createReportsSemanticInvalidIDForPhysicallyBlankInput(
        id: String
    ) async {
        let repository = LocalDatabaseExampleRepository(
            database: makeGenericDatabase()
        )

        await #expect(throws: ExampleRecordRepositoryError.invalidID) {
            try await repository.create(id: id, payload: "value")
        }
    }

    @Test(arguments: ["a", "z", "0", "9", "-", "_", ".", "a-z_0.9"])
    func createAcceptsStrictLowercaseASCIIIDs(id: String) async throws {
        let repository = LocalDatabaseExampleRepository(
            database: makeGenericDatabase()
        )

        try await repository.create(id: id, payload: "value")

        #expect(
            try await repository.fetch(id: id)
                == ExampleRecord(id: id, payload: "value")
        )
    }

    @Test(arguments: ["", "A", "New ID", "Ж", "/", ":", "🌏"])
    func createRejectsMissingNonStrictIDsWithoutWriting(id: String) async {
        let database = RecordingExampleDatabase()
        let repository = LocalDatabaseExampleRepository(database: database)

        await #expect(throws: ExampleRecordRepositoryError.invalidID) {
            try await repository.create(id: id, payload: "value")
        }
        #expect(await database.upsertCount == 0)
        #expect(await database.record(id: id) == nil)
    }

    @Test
    func createChecksExactExistingLegacyIdentityBeforeStrictValidation() async throws {
        let database = makeGenericDatabase()
        try await database.upsert(
            ExampleRecord(id: " Legacy-Ж ", payload: "original")
        )
        let repository = LocalDatabaseExampleRepository(database: database)

        await #expect(throws: ExampleRecordRepositoryError.alreadyExists) {
            try await repository.create(
                id: " Legacy-Ж ",
                payload: "replacement"
            )
        }

        #expect(
            try await repository.fetch(id: " Legacy-Ж ")?.payload
                == "original"
        )
    }

    @Test
    func updateAndDeletePreserveExactLegacyIdentity() async throws {
        let database = makeGenericDatabase()
        try await database.upsert([
            ExampleRecord(id: " whitespace ", payload: "one"),
            ExampleRecord(id: "MiXeD", payload: "two"),
            ExampleRecord(id: "Ж", payload: "three")
        ])
        let repository = LocalDatabaseExampleRepository(database: database)

        try await repository.update(id: " whitespace ", payload: "changed")
        #expect(
            try await repository.fetch(id: " whitespace ")?.payload
                == "changed"
        )
        #expect(try await repository.delete(id: "MiXeD"))
        #expect(try await repository.fetch(id: "MiXeD") == nil)
        #expect(try await repository.fetch(id: "Ж")?.id == "Ж")
        await #expect(throws: ExampleRecordRepositoryError.notFound) {
            try await repository.update(id: "missing", payload: "value")
        }
    }

    @Test
    func singleUpsertValidatesOnlyNewIdentity() async throws {
        let database = makeGenericDatabase()
        try await database.upsert([
            ExampleRecord(id: " Legacy ", payload: "legacy"),
            ExampleRecord(id: "strict", payload: "strict")
        ])
        let repository = LocalDatabaseExampleRepository(database: database)

        try await repository.upsert(
            ExampleRecord(id: " Legacy ", payload: "changed legacy")
        )
        try await repository.upsert(
            ExampleRecord(id: "strict", payload: "changed strict")
        )
        try await repository.upsert(
            ExampleRecord(id: "new-id", payload: "inserted")
        )
        await #expect(throws: ExampleRecordRepositoryError.invalidID) {
            try await repository.upsert(
                ExampleRecord(id: "New-ID", payload: "rejected")
            )
        }

        #expect(try await repository.fetch(id: " Legacy ")?.payload == "changed legacy")
        #expect(try await repository.fetch(id: "strict")?.payload == "changed strict")
        #expect(try await repository.fetch(id: "new-id")?.payload == "inserted")
        #expect(try await repository.fetch(id: "New-ID") == nil)
    }

    @Test
    func batchUpsertPreflightsEveryNewIdentityBeforeOneAtomicWrite() async throws {
        let database = makeGenericDatabase()
        try await database.upsert([
            ExampleRecord(id: " Legacy ", payload: "legacy"),
            ExampleRecord(id: "strict", payload: "strict")
        ])
        let repository = LocalDatabaseExampleRepository(database: database)

        try await repository.upsertBatch([
            ExampleRecord(id: " Legacy ", payload: "changed legacy"),
            ExampleRecord(id: "strict", payload: "changed strict"),
            ExampleRecord(id: "new-id", payload: "inserted")
        ])
        await #expect(throws: ExampleRecordRepositoryError.invalidID) {
            try await repository.upsertBatch([
                ExampleRecord(id: " Legacy ", payload: "must not change"),
                ExampleRecord(id: "Bad New", payload: "rejected")
            ])
        }

        #expect(try await repository.fetch(id: " Legacy ")?.payload == "changed legacy")
        #expect(try await repository.fetch(id: "strict")?.payload == "changed strict")
        #expect(try await repository.fetch(id: "new-id")?.payload == "inserted")
        #expect(try await repository.fetch(id: "Bad New") == nil)
    }

    @Test
    func batchUpsertUsesOneBatchWriteAfterAllExistenceChecks() async throws {
        let database = RecordingExampleDatabase()
        await database.seed([
            ExampleRecord(id: " Legacy ", payload: "legacy"),
            ExampleRecord(id: "strict", payload: "strict")
        ])
        let repository = LocalDatabaseExampleRepository(database: database)

        try await repository.upsertBatch([
            ExampleRecord(id: " Legacy ", payload: "changed legacy"),
            ExampleRecord(id: "strict", payload: "changed strict"),
            ExampleRecord(id: "new-id", payload: "inserted")
        ])

        #expect(await database.fetchCount == 0)
        #expect(await database.existenceQueryCount == 1)
        #expect(await database.upsertCount == 0)
        #expect(await database.batchUpsertCount == 1)
    }

    @Test
    func batchUpsertPreservesLowLevelDuplicateAndMaximumGuarantees() async throws {
        let repository = LocalDatabaseExampleRepository(
            database: makeGenericDatabase()
        )

        await #expect(throws: LocalDatabaseError.self) {
            try await repository.upsertBatch([
                ExampleRecord(id: "same", payload: "one"),
                ExampleRecord(id: "same", payload: "two")
            ])
        }
        await #expect(throws: LocalDatabaseError.self) {
            try await repository.upsertBatch(
                (0...500).map {
                    ExampleRecord(id: "id-\($0)", payload: "value")
                }
            )
        }
    }

    @Test(arguments: [1, 50])
    func pageAcceptsInclusiveSizesAndUsesVisibleLookaheadCursor(
        pageSize: Int
    ) async throws {
        let database = makeGenericDatabase()
        try await database.upsert(
            (0...50).map {
                ExampleRecord(id: "id-\(String(format: "%02d", $0))", payload: "value")
            }
        )
        let repository = LocalDatabaseExampleRepository(database: database)

        let page = try await repository.page(
            searchText: nil,
            afterID: nil,
            pageSize: pageSize
        )

        #expect(page.values.count == pageSize)
        #expect(page.hasMore)
        #expect(page.nextCursor == page.values.last?.id)
        #expect(page.nextCursor != "id-\(String(format: "%02d", pageSize))")
    }

    @Test
    func emptyExactAndMultiPageResultsHaveTerminalCursorSemantics() async throws {
        let database = makeGenericDatabase()
        let repository = LocalDatabaseExampleRepository(database: database)
        let empty = try await repository.page(
            searchText: nil,
            afterID: nil,
            pageSize: 2
        )
        #expect(empty.values.isEmpty)
        #expect(!empty.hasMore)
        #expect(empty.nextCursor == nil)

        try await database.upsert([
            ExampleRecord(id: "a", payload: "value"),
            ExampleRecord(id: "b", payload: "value"),
            ExampleRecord(id: "c", payload: "value"),
            ExampleRecord(id: "d", payload: "value")
        ])
        let first = try await repository.page(searchText: nil, afterID: nil, pageSize: 2)
        let second = try await repository.page(searchText: nil, afterID: first.nextCursor, pageSize: 2)

        #expect(first.values.map(\.id) == ["a", "b"])
        #expect(first.nextCursor == "b")
        #expect(first.hasMore)
        #expect(second.values.map(\.id) == ["c", "d"])
        #expect(second.nextCursor == nil)
        #expect(!second.hasMore)
        #expect(Set(first.values.map(\.id)).isDisjoint(with: second.values.map(\.id)))
    }

    @Test(arguments: [0, 51])
    func invalidPageSizeFailsBeforeDatabaseCall(pageSize: Int) async {
        let database = RecordingExampleDatabase()
        let repository = LocalDatabaseExampleRepository(database: database)

        await #expect(throws: ExampleRecordRepositoryError.invalidPageSize) {
            _ = try await repository.page(
                searchText: nil,
                afterID: nil,
                pageSize: pageSize
            )
        }
        #expect(await database.fetchManyCount == 0)
    }

    @Test
    func concurrentCreatesSerializeTheirExistenceCheckAndWrite() async throws {
        let database = RecordingExampleDatabase(pauseFirstFetch: true)
        let repository = LocalDatabaseExampleRepository(database: database)
        let first = Task { try await repository.create(id: "same", payload: "first") }
        await database.waitUntilFetchCount(1)
        let second = Task { try await repository.create(id: "same", payload: "second") }
        await repository.waitUntilQueuedMutationCountForTesting(1)

        #expect(await database.fetchCount == 1)
        await database.releasePausedFetch()
        try await first.value
        await #expect(throws: ExampleRecordRepositoryError.alreadyExists) {
            try await second.value
        }
        #expect(await database.fetchCount == 2)
        #expect(await database.upsertCount == 1)
        #expect(await database.record(id: "same")?.payload == "first")
    }

    @Test
    func deleteCannotInterleaveInsideCreateCheckWriteWindow() async throws {
        let database = RecordingExampleDatabase(pauseFirstFetch: true)
        let repository = LocalDatabaseExampleRepository(database: database)
        let create = Task { try await repository.create(id: "same", payload: "first") }
        await database.waitUntilFetchCount(1)
        let delete = Task { try await repository.delete(id: "same") }
        await repository.waitUntilQueuedMutationCountForTesting(1)

        #expect(await database.deleteCount == 0)
        await database.releasePausedFetch()
        try await create.value
        #expect(try await delete.value)
        #expect(await database.record(id: "same") == nil)
    }

    @Test
    func deleteAllIsScopedToExampleRecordsAndReturnsDeletedCount() async throws {
        let database = makeGenericDatabase()
        try await database.upsert([
            ExampleRecord(id: "one", payload: "one"),
            ExampleRecord(id: "two", payload: "two")
        ])
        let other = TestLocalRecord(
            id: TestLocalRecordID(rawValue: 7),
            score: 1,
            title: "preserved"
        )
        try await database.upsert(other)
        let repository = LocalDatabaseExampleRepository(database: database)

        #expect(try await repository.deleteAll() == 2)
        #expect(try await repository.fetch(id: "one") == nil)
        #expect(
            try await database.fetch(TestLocalRecord.self, id: other.id)
                == other
        )
    }

    @Test
    func failureBeforePersistReleasesGateForQueuedSuccessor() async throws {
        let database = RecordingExampleDatabase(
            pauseFirstFetch: true,
            failFirstFetch: true
        )
        let repository = LocalDatabaseExampleRepository(database: database)
        let first = Task { try await repository.create(id: "first", payload: "first") }
        await database.waitUntilFetchCount(1)
        let second = Task { try await repository.create(id: "second", payload: "second") }
        await repository.waitUntilQueuedMutationCountForTesting(1)
        await database.releasePausedFetch()

        await #expect(throws: ExampleRepositoryDatabaseTestError.failed) {
            try await first.value
        }
        try await second.value
        #expect(await database.record(id: "second")?.payload == "second")
    }

    @Test
    func cancellationBeforePersistReleasesGateForQueuedSuccessor() async throws {
        let database = RecordingExampleDatabase(pauseFirstFetch: true)
        let repository = LocalDatabaseExampleRepository(database: database)
        let first = Task {
            try await repository.create(id: "first", payload: "first")
        }
        await database.waitUntilFetchCount(1)
        let second = Task {
            try await repository.create(id: "second", payload: "second")
        }
        await repository.waitUntilQueuedMutationCountForTesting(1)
        first.cancel()
        await database.releasePausedFetch()

        await #expect(throws: CancellationError.self) {
            try await first.value
        }
        try await second.value
        #expect(await database.record(id: "first") == nil)
        #expect(await database.record(id: "second")?.payload == "second")
    }
}

private enum ExampleRepositoryDatabaseTestError: Error { case failed }

private actor RecordingExampleDatabase: ILocalDatabaseService {
    private var records: [String: ExampleRecord] = [:]
    private(set) var fetchCount = 0
    private(set) var fetchManyCount = 0
    private(set) var existenceQueryCount = 0
    private(set) var upsertCount = 0
    private(set) var batchUpsertCount = 0
    private(set) var deleteCount = 0
    private var shouldPause: Bool
    private var shouldFailFirstFetch: Bool
    private var pauseContinuation: CheckedContinuation<Void, Never>?
    private var fetchWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    init(pauseFirstFetch: Bool = false, failFirstFetch: Bool = false) {
        shouldPause = pauseFirstFetch
        shouldFailFirstFetch = failFirstFetch
    }

    func record(id: String) -> ExampleRecord? { records[id] }
    func seed(_ values: [ExampleRecord]) {
        for value in values { records[value.id] = value }
    }

    func waitUntilFetchCount(_ expected: Int) async {
        guard fetchCount < expected else { return }
        await withCheckedContinuation { fetchWaiters.append((expected, $0)) }
    }

    func releasePausedFetch() {
        let continuation = pauseContinuation
        pauseContinuation = nil
        continuation?.resume()
    }

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Model? {
        guard Model.self == ExampleRecord.self, let id = id as? String else {
            return nil
        }
        fetchCount += 1
        let ready = fetchWaiters.filter { $0.0 <= fetchCount }
        fetchWaiters.removeAll { $0.0 <= fetchCount }
        for waiter in ready { waiter.1.resume() }
        if shouldPause {
            shouldPause = false
            await withCheckedContinuation { pauseContinuation = $0 }
            try Task.checkCancellation()
        }
        if shouldFailFirstFetch {
            shouldFailFirstFetch = false
            throw ExampleRepositoryDatabaseTestError.failed
        }
        return records[id] as? Model
    }

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        matching query: Model.Query
    ) async throws -> [Model] {
        fetchManyCount += 1
        return []
    }

    func existingIDs<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        ids: [Model.ID]
    ) async throws -> Set<Model.ID> {
        existenceQueryCount += 1
        guard Model.self == ExampleRecord.self else { return [] }
        return Set(ids.filter { id in
            guard let id = id as? String else { return false }
            return records[id] != nil
        })
    }

    func upsert<Model: LocalDatabaseModel>(_ value: Model) async throws {
        guard let value = value as? ExampleRecord else { return }
        records[value.id] = value
        upsertCount += 1
    }

    func upsert<Model: LocalDatabaseModel>(_ values: [Model]) async throws {
        guard let values = values as? [ExampleRecord] else { return }
        for value in values { records[value.id] = value }
        batchUpsertCount += 1
    }

    func delete<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Bool {
        guard Model.self == ExampleRecord.self, let id = id as? String else {
            return false
        }
        deleteCount += 1
        return records.removeValue(forKey: id) != nil
    }

    func deleteAll<Model: LocalDatabaseModel>(
        _ type: Model.Type
    ) async throws -> Int {
        guard Model.self == ExampleRecord.self else { return 0 }
        let count = records.count
        records.removeAll()
        return count
    }
}
