import Foundation
import SwiftData

@ModelActor
actor SwiftDataLocalStore {
    private typealias StoredRecord =
        LocalDatabaseSchemaV1.StoredExampleRecord

    private var hooks: LocalDatabaseStoreHooks = .production

    init(
        modelContainer: ModelContainer,
        hooks: LocalDatabaseStoreHooks
    ) {
        let executorContext = ModelContext(modelContainer)
        executorContext.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(
            modelContext: executorContext
        )
        self.modelContainer = modelContainer
        self.hooks = hooks
    }

    func fetchRecord(id: String) throws -> ExampleRecord? {
        let operation = LocalDatabaseReadOperation.fetchOne
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.read(operation))
            try Task.checkCancellation()
            return try storedRecord(id: id, in: context).map(value(from:))
        } catch {
            throw mapReadFailure(
                error,
                operation: operation,
                recordCount: 1
            )
        }
    }

    func upsert(_ record: ExampleRecord) throws {
        let operation = LocalDatabaseWriteOperation.upsertOne
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.writePreparation(operation))
            try Task.checkCancellation()

            if let stored = try storedRecord(id: record.id, in: context) {
                guard stored.payload != record.payload else { return }
                stored.payload = record.payload
            } else {
                context.insert(
                    StoredRecord(id: record.id, payload: record.payload)
                )
            }

            try save(context: context, operation: operation)
        } catch {
            throw rollbackAndMapWriteFailure(
                error,
                context: context,
                operation: operation,
                recordCount: 1
            )
        }
    }

    func deleteRecord(id: String) throws -> Bool {
        let operation = LocalDatabaseWriteOperation.deleteOne
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.writePreparation(operation))
            try Task.checkCancellation()
            guard let stored = try storedRecord(id: id, in: context) else {
                return false
            }
            context.delete(stored)
            try save(context: context, operation: operation)
            return true
        } catch {
            throw rollbackAndMapWriteFailure(
                error,
                context: context,
                operation: operation,
                recordCount: 1
            )
        }
    }

    private func makeOperationContext() -> ModelContext {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        return context
    }

    private func storedRecord(
        id: String,
        in context: ModelContext
    ) throws -> StoredRecord? {
        var descriptor = FetchDescriptor<StoredRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func value(from stored: StoredRecord) -> ExampleRecord {
        ExampleRecord(id: stored.id, payload: stored.payload)
    }

    private func save(
        context: ModelContext,
        operation: LocalDatabaseWriteOperation
    ) throws {
        try hooks.checkpoint(.beforeSave(operation))
        try Task.checkCancellation()
        try context.save()
        hooks.didSave(operation)
    }

    private func mapReadFailure(
        _ error: any Error,
        operation: LocalDatabaseReadOperation,
        recordCount: Int
    ) -> any Error {
        if error is CancellationError { return error }
        LocalDatabaseDiagnostics.report(
            operation: .read(operation),
            recordCount: recordCount,
            error: error
        )
        return LocalDatabaseError.read(
            operation: operation,
            underlying: error
        )
    }

    private func rollbackAndMapWriteFailure(
        _ error: any Error,
        context: ModelContext,
        operation: LocalDatabaseWriteOperation,
        recordCount: Int
    ) -> any Error {
        context.rollback()
        hooks.didRollback(operation)
        if error is CancellationError { return error }
        LocalDatabaseDiagnostics.report(
            operation: .write(operation),
            recordCount: recordCount,
            error: error
        )
        return LocalDatabaseError.write(
            operation: operation,
            underlying: error
        )
    }
}
