import Foundation
import SwiftData
import Testing
@testable import AppTemplate

struct SwiftDataLocalStoreMutationTests {
    @Test
    func insertAndExactFetchRoundTripValue() async throws {
        let store = try makeInMemoryLocalStore()
        let record = ExampleRecord(id: "record-1", payload: "value")

        try await store.upsert(record)

        #expect(try await store.fetchRecord(id: record.id) == record)
        #expect(try await store.fetchRecord(id: "missing") == nil)
    }

    @Test
    func emptyPayloadRoundTripsWithoutNormalization() async throws {
        let store = try makeInMemoryLocalStore()
        let record = ExampleRecord(id: "empty-payload", payload: "")

        try await store.upsert(record)

        #expect(try await store.fetchRecord(id: record.id) == record)
    }

    @Test
    func updateChangesExistingEntityWithoutDuplicate() async throws {
        let store = try makeInMemoryLocalStore()
        try await store.upsert(
            ExampleRecord(id: "record-1", payload: "before")
        )

        try await store.upsert(
            ExampleRecord(id: "record-1", payload: "after")
        )

        #expect(
            try await store.fetchRecord(id: "record-1")
                == ExampleRecord(id: "record-1", payload: "after")
        )
    }

    @Test
    func unchangedUpsertDoesNotSave() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let record = ExampleRecord(id: "record-1", payload: "same")
        try await store.upsert(record)

        try await store.upsert(record)

        #expect(recorder.saves == [.upsertOne])
    }

    @Test
    func missingDeleteIsNoOpAndPresentDeleteSaves() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        #expect(try await store.deleteRecord(id: "missing") == false)
        #expect(recorder.saves.isEmpty)

        try await store.upsert(
            ExampleRecord(id: "record-1", payload: "value")
        )
        #expect(try await store.deleteRecord(id: "record-1"))
        #expect(try await store.fetchRecord(id: "record-1") == nil)
        #expect(recorder.saves == [.upsertOne, .deleteOne])
    }

    @Test
    func beforeSaveFailureRollsBackAndMapsWriteOperation() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .beforeSave(.upsertOne)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        do {
            try await store.upsert(
                ExampleRecord(id: "record-1", payload: "secret")
            )
            Issue.record("Expected write failure")
        } catch let error as LocalDatabaseError {
            guard case let .write(operation, underlying) = error else {
                Issue.record("Expected LocalDatabaseError.write")
                return
            }
            #expect(operation == .upsertOne)
            #expect(underlying is LocalDatabaseTestError)
        }

        #expect(recorder.rollbacks == [.upsertOne])
        #expect(try await store.fetchRecord(id: "record-1") == nil)
    }

    @Test
    func realSaveFailureDiscardsStaleOperationContext() async throws {
        let url = try uniqueLocalDatabaseStoreURL(label: "read-only")
        do {
            let writable = try LocalDatabaseContainerFactories.disk(url: url)()
            let seedContext = ModelContext(writable)
            seedContext.autosaveEnabled = false
            seedContext.insert(
                LocalDatabaseSchemaV1.StoredExampleRecord(
                    id: "record-1",
                    payload: "durable"
                )
            )
            try seedContext.save()
        }

        let schema = Schema(versionedSchema: LocalDatabaseSchemaV1.self)
        let readOnlyConfiguration = ModelConfiguration(
            "LocalDatabase",
            schema: schema,
            url: url,
            allowsSave: false,
            cloudKitDatabase: .none
        )
        let readOnlyContainer = try ModelContainer(
            for: schema,
            migrationPlan: LocalDatabaseMigrationPlan.self,
            configurations: [readOnlyConfiguration]
        )
        let store = SwiftDataLocalStore(
            modelContainer: readOnlyContainer,
            hooks: .production
        )

        do {
            try await store.upsert(
                ExampleRecord(id: "record-1", payload: "unsaved")
            )
            Issue.record("Expected the read-only save to fail")
        } catch let error as LocalDatabaseError {
            guard case let .write(operation, _) = error else {
                Issue.record("Expected LocalDatabaseError.write")
                return
            }
            #expect(operation == .upsertOne)
        }

        #expect(
            try await store.fetchRecord(id: "record-1")
                == ExampleRecord(id: "record-1", payload: "durable")
        )
    }

    @Test
    func cancellationRaisedAfterSaveDoesNotReplaceSuccess() async throws {
        let hooks = LocalDatabaseStoreHooks(
            checkpoint: { _ in },
            didSave: { _ in
                withUnsafeCurrentTask { $0?.cancel() }
            },
            didRollback: { _ in }
        )
        let store = try makeInMemoryLocalStore(hooks: hooks)
        let record = ExampleRecord(id: "record-1", payload: "durable")
        let request = Task { () -> Result<Void, any Error> in
            do {
                try await store.upsert(record)
                return .success(())
            } catch {
                return .failure(error)
            }
        }

        guard case .success = await request.value else {
            Issue.record("A successful save must return success")
            return
        }
        #expect(try await store.fetchRecord(id: record.id) == record)
    }

    @Test
    func readCheckpointFailureMapsExactReadOperation() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .read(.fetchOne)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        do {
            _ = try await store.fetchRecord(id: "record-1")
            Issue.record("Expected read failure")
        } catch let error as LocalDatabaseError {
            guard case let .read(operation, underlying) = error else {
                Issue.record("Expected LocalDatabaseError.read")
                return
            }
            #expect(operation == .fetchOne)
            #expect(underlying is LocalDatabaseTestError)
        }
    }

    @Test
    func diagnosticMetadataCannotCarrySensitiveErrorDescription() {
        let sentinel = NSError(
            domain: "FixtureDomain",
            code: 73,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "id=record-1 payload=secret search=needle "
                    + "path=/Users/person/LocalDatabase.store"
            ]
        )

        let metadata = LocalDatabaseDiagnostics.metadata(
            operation: .write(.upsertOne),
            recordCount: 1,
            error: sentinel
        )

        #expect(metadata.operation == .write(.upsertOne))
        #expect(metadata.entityType == "StoredExampleRecord")
        #expect(metadata.recordCount == 1)
        #expect(metadata.errorDomain == "FixtureDomain")
        #expect(metadata.errorCode == 73)
    }
}
