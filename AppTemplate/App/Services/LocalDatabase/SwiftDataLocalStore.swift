import Foundation
import SwiftData

@ModelActor
actor SwiftDataLocalStore {
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

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) throws -> Model? {
        let operation = LocalDatabaseReadOperation.fetchOne
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.read(operation))
            try Task.checkCancellation()
            return try Model.Persistence.fetch(id: id, in: context)
                .map(Model.Persistence.value(from:))
        } catch {
            throw mapReadFailure(
                error,
                model: Model.Persistence.diagnosticName,
                operation: operation,
                recordCount: 1
            )
        }
    }

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        matching query: Model.Query
    ) throws -> [Model] {
        let operation = LocalDatabaseReadOperation.fetchMany
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.read(operation))
            try Task.checkCancellation()
            let entities = try Model.Persistence.fetch(
                matching: query,
                in: context,
                progress: { _ in
                    try hooks.checkpoint(.readProgress(operation))
                    try Task.checkCancellation()
                }
            )
            try Task.checkCancellation()
            return entities.map(Model.Persistence.value(from:))
        } catch {
            throw mapReadFailure(
                error,
                model: Model.Persistence.diagnosticName,
                operation: operation,
                recordCount:
                    Model.Persistence.attemptedRecordCount(for: query)
            )
        }
    }

    func existingIDs<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        ids: [Model.ID]
    ) throws -> Set<Model.ID> {
        let operation = LocalDatabaseReadOperation.fetchMany
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.read(operation))
            try Task.checkCancellation()
            let entities = try Model.Persistence.fetchExisting(
                ids: ids,
                in: context
            )
            return Set(entities.map(Model.Persistence.id(of:)))
        } catch {
            throw mapReadFailure(
                error,
                model: Model.Persistence.diagnosticName,
                operation: operation,
                recordCount: ids.count
            )
        }
    }

    func upsert<Model: LocalDatabaseModel>(_ value: Model) throws {
        let operation = LocalDatabaseWriteOperation.upsertOne
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.writePreparation(operation))
            try Task.checkCancellation()

            if let entity = try Model.Persistence.fetch(
                id: value.id,
                in: context
            ) {
                guard Model.Persistence.update(entity, from: value) else {
                    return
                }
            } else {
                context.insert(Model.Persistence.makeEntity(from: value))
            }

            try save(context: context, operation: operation)
        } catch {
            throw rollbackAndMapWriteFailure(
                error,
                model: Model.Persistence.diagnosticName,
                context: context,
                operation: operation,
                recordCount: 1
            )
        }
    }

    func upsert<Model: LocalDatabaseModel>(_ values: [Model]) throws {
        guard !values.isEmpty else { return }
        let operation = LocalDatabaseWriteOperation.upsertBatch
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.writePreparation(operation))
            try Task.checkCancellation()

            let entities = try Model.Persistence.fetchExisting(
                ids: values.map(\.id),
                in: context
            )
            let entitiesByID = try Model.Persistence.entitiesByID(entities)
            var changed = false

            for value in values {
                if let entity = entitiesByID[value.id] {
                    changed = Model.Persistence.update(
                        entity,
                        from: value
                    ) || changed
                } else {
                    context.insert(Model.Persistence.makeEntity(from: value))
                    changed = true
                }
            }

            guard changed else { return }
            try save(context: context, operation: operation)
        } catch {
            throw rollbackAndMapWriteFailure(
                error,
                model: Model.Persistence.diagnosticName,
                context: context,
                operation: operation,
                recordCount: values.count
            )
        }
    }

    func delete<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) throws -> Bool {
        let operation = LocalDatabaseWriteOperation.deleteOne
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.writePreparation(operation))
            try Task.checkCancellation()
            guard let entity = try Model.Persistence.fetchEntityForRemoval(
                id: id,
                in: context
            ) else {
                return false
            }
            context.delete(entity)
            try save(context: context, operation: operation)
            return true
        } catch {
            throw rollbackAndMapWriteFailure(
                error,
                model: Model.Persistence.diagnosticName,
                context: context,
                operation: operation,
                recordCount: 1
            )
        }
    }

    func deleteAll<Model: LocalDatabaseModel>(
        _ type: Model.Type
    ) throws -> Int {
        let operation = LocalDatabaseWriteOperation.deleteAll
        try Task.checkCancellation()
        let context = makeOperationContext()
        var recordCount = 0
        do {
            try hooks.checkpoint(.writePreparation(operation))
            try Task.checkCancellation()
            recordCount = try context.fetchCount(
                FetchDescriptor<Model.Persistence.Entity>()
            )
            guard recordCount > 0 else { return 0 }
            try hooks.checkpoint(.beforeBatchDelete(operation))
            try Task.checkCancellation()
            try context.delete(
                model: Model.Persistence.Entity.self,
                where: nil,
                includeSubclasses: false
            )
            return recordCount
        } catch {
            throw rollbackAndMapWriteFailure(
                error,
                model: Model.Persistence.diagnosticName,
                context: context,
                operation: operation,
                recordCount: recordCount
            )
        }
    }

    private func makeOperationContext() -> ModelContext {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        return context
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
        model: String,
        operation: LocalDatabaseReadOperation,
        recordCount: Int
    ) -> any Error {
        if error is CancellationError { return error }
        LocalDatabaseDiagnostics.report(
            operation: .read(operation),
            entityType: model,
            recordCount: recordCount,
            error: error
        )
        return LocalDatabaseError.read(
            model: model,
            operation: operation,
            underlying: error
        )
    }

    private func rollbackAndMapWriteFailure(
        _ error: any Error,
        model: String,
        context: ModelContext,
        operation: LocalDatabaseWriteOperation,
        recordCount: Int
    ) -> any Error {
        context.rollback()
        hooks.didRollback(operation)
        if error is CancellationError { return error }
        LocalDatabaseDiagnostics.report(
            operation: .write(operation),
            entityType: model,
            recordCount: recordCount,
            error: error
        )
        return LocalDatabaseError.write(
            model: model,
            operation: operation,
            underlying: error
        )
    }
}
