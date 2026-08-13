import Foundation
import SwiftData
import Testing
@testable import AppTemplate

struct SwiftDataLocalStoreBatchTests {
    @Test
    func genericBatchInsertsAndUpdatesWithOneSave() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        try await store.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])

        #expect(recorder.saves == [.upsertBatch])
        #expect(
            try await store.fetch(ExampleRecord.self, id: "a")
                == ExampleRecord(id: "a", payload: "one")
        )

        try await store.upsert([
            ExampleRecord(id: "a", payload: "updated"),
            ExampleRecord(id: "c", payload: "three")
        ])
        #expect(recorder.saves == [.upsertBatch, .upsertBatch])
    }

    @Test
    func emptyAndFullyUnchangedGenericBatchesDoNotSave() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let records = [ExampleRecord(id: "a", payload: "same")]

        try await store.upsert([ExampleRecord]())
        #expect(recorder.saves.isEmpty)
        try await store.upsert(records)
        try await store.upsert(records)
        #expect(recorder.saves == [.upsertBatch])
    }

    @Test
    func failedGenericBatchRollsBackEveryPendingChange() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .beforeSave(.upsertBatch)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        do {
            try await store.upsert([
                ExampleRecord(id: "a", payload: "one"),
                ExampleRecord(id: "b", payload: "two")
            ])
            Issue.record("Expected batch write failure")
        } catch let error as LocalDatabaseError {
            guard case let .write(model, operation, _) = error else {
                Issue.record("Expected LocalDatabaseError.write")
                return
            }
            #expect(model == ExampleRecordAdapter.diagnosticName)
            #expect(operation == .upsertBatch)
        }

        #expect(recorder.rollbacks == [.upsertBatch])
        #expect(try await store.fetch(ExampleRecord.self, id: "a") == nil)
        #expect(try await store.fetch(ExampleRecord.self, id: "b") == nil)
    }

    @Test
    func genericDeleteAllReturnsCountUsesOneCheckpointAndNeverSaves() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        #expect(try await store.deleteAll(ExampleRecord.self) == 0)
        #expect(recorder.saves.isEmpty)
        #expect(
            !recorder.checkpoints.contains(
                .beforeBatchDelete(.deleteAll)
            )
        )
        try await store.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])

        #expect(try await store.deleteAll(ExampleRecord.self) == 2)
        #expect(recorder.saves == [.upsertBatch])
        #expect(
            recorder.checkpoints.filter {
                $0 == .beforeBatchDelete(.deleteAll)
            }.count == 1
        )
        #expect(try await store.fetch(ExampleRecord.self, id: "a") == nil)
    }

    @Test
    func cancellationAtPreSaveCheckpointRollsBackChildTask() async throws {
        let recorder = LocalDatabaseHookRecorder(
            cancellingCheckpoint: .beforeSave(.upsertBatch)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let request = Task { () -> Result<Void, any Error> in
            do {
                try await store.upsert([
                    ExampleRecord(id: "a", payload: "one")
                ])
                return .success(())
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
        #expect(recorder.rollbacks == [.upsertBatch])
        #expect(try await store.fetch(ExampleRecord.self, id: "a") == nil)
    }

    @Test
    func failedDeleteOneKeepsDurableRecord() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .beforeSave(.deleteOne)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let record = ExampleRecord(id: "a", payload: "durable")
        try await store.upsert(record)

        do {
            _ = try await store.delete(ExampleRecord.self, id: record.id)
            Issue.record("Expected delete failure")
        } catch let error as LocalDatabaseError {
            guard case let .write(model, operation, _) = error else {
                Issue.record("Expected LocalDatabaseError.write")
                return
            }
            #expect(model == ExampleRecordAdapter.diagnosticName)
            #expect(operation == .deleteOne)
        }
        #expect(recorder.rollbacks == [.deleteOne])
        #expect(
            try await store.fetch(ExampleRecord.self, id: record.id) == record
        )
    }

    @Test
    func preCallCancelledDeleteAllKeepsEveryDurableRecord() async throws {
        let recorder = LocalDatabaseHookRecorder(
            cancellingCheckpoint: .beforeBatchDelete(.deleteAll)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let records = [
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ]
        try await store.upsert(records)
        let request = Task { () -> Result<Int, any Error> in
            do {
                return .success(try await store.deleteAll(ExampleRecord.self))
            }
            catch { return .failure(error) }
        }

        guard case let .failure(error) = await request.value else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(error is CancellationError)
        #expect(recorder.rollbacks == [.deleteAll])
        #expect(
            try await store.fetch(ExampleRecord.self, id: "a") == records[0]
        )
        #expect(
            try await store.fetch(ExampleRecord.self, id: "b") == records[1]
        )
    }

    @Test
    func preCallFailedDeleteAllMapsOperationAndKeepsDurableRecords() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .beforeBatchDelete(.deleteAll)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let records = [
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ]
        try await store.upsert(records)

        do {
            _ = try await store.deleteAll(ExampleRecord.self)
            Issue.record("Expected delete-all failure")
        } catch let error as LocalDatabaseError {
            guard case let .write(model, operation, _) = error else {
                Issue.record("Expected LocalDatabaseError.write")
                return
            }
            #expect(model == ExampleRecordAdapter.diagnosticName)
            #expect(operation == .deleteAll)
        }
        #expect(recorder.rollbacks == [.deleteAll])
        #expect(
            try await store.fetch(ExampleRecord.self, id: "a") == records[0]
        )
        #expect(
            try await store.fetch(ExampleRecord.self, id: "b") == records[1]
        )
    }

    @Test
    func diskBatchDeleteIsDurableBeforeSaveAndRollbackCannotRestore() throws {
        typealias StoredRecord =
            LocalDatabaseSchemaV2.StoredExampleRecord
        let url = try uniqueLocalDatabaseStoreURL(
            label: "batch-delete-boundary"
        )
        let container = try LocalDatabaseContainerFactories.disk(url: url)()
        let seedContext = ModelContext(container)
        seedContext.autosaveEnabled = false
        seedContext.insert(StoredRecord(id: "a", payload: "one"))
        seedContext.insert(StoredRecord(id: "b", payload: "two"))
        try seedContext.save()

        let deleteContext = ModelContext(container)
        deleteContext.autosaveEnabled = false
        try deleteContext.delete(
            model: StoredRecord.self,
            where: nil,
            includeSubclasses: false
        )

        #expect(!deleteContext.hasChanges)
        let beforeSaveContainer =
            try LocalDatabaseContainerFactories.disk(url: url)()
        let beforeSaveObserver = ModelContext(beforeSaveContainer)
        #expect(
            try beforeSaveObserver.fetchCount(
                FetchDescriptor<StoredRecord>()
            ) == 0
        )

        deleteContext.rollback()
        #expect(!deleteContext.hasChanges)
        let afterRollbackContainer =
            try LocalDatabaseContainerFactories.disk(url: url)()
        let afterRollbackObserver = ModelContext(afterRollbackContainer)
        #expect(
            try afterRollbackObserver.fetchCount(
                FetchDescriptor<StoredRecord>()
            ) == 0
        )

        try deleteContext.save()
        #expect(!deleteContext.hasChanges)
    }
}
