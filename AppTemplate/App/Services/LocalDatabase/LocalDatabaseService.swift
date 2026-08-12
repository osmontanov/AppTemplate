actor LocalDatabaseService: ILocalDatabaseService {
    private enum State {
        case uninitialized(LocalDatabaseContainerFactory)
        case ready(SwiftDataLocalStore)
        case failed(LocalDatabaseError)
    }

    private var state: State
    private let modelRegistry: LocalDatabaseModelRegistry
    private let hooks: LocalDatabaseStoreHooks

    init(
        configuration: LocalDatabaseStoreConfiguration,
        hooks: LocalDatabaseStoreHooks = .production
    ) {
        state = .uninitialized(configuration.containerFactory)
        modelRegistry = configuration.modelRegistry
        self.hooks = hooks
    }

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Model? {
        try Task.checkCancellation()
        try mapValidation(Model.self) {
            try Model.Persistence.validate(id: id)
        }
        try validateRegistration(Model.self)
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.fetch(Model.self, id: id)
    }

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        matching query: Model.Query
    ) async throws -> [Model] {
        try Task.checkCancellation()
        try mapValidation(Model.self) {
            try Model.Persistence.validate(query: query)
        }
        try validateRegistration(Model.self)
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.fetch(Model.self, matching: query)
    }

    func upsert<Model: LocalDatabaseModel>(
        _ value: Model
    ) async throws {
        try Task.checkCancellation()
        try mapValidation(Model.self) {
            try Model.Persistence.validate(value: value)
        }
        try validateRegistration(Model.self)
        let store = try resolveStore()
        try Task.checkCancellation()
        try await store.upsert(value)
    }

    func upsert<Model: LocalDatabaseModel>(
        _ values: [Model]
    ) async throws {
        try Task.checkCancellation()
        try mapValidation(Model.self) {
            try LocalDatabaseValidator.validate(values: values)
        }
        try validateRegistration(Model.self)
        guard !values.isEmpty else { return }
        let store = try resolveStore()
        try Task.checkCancellation()
        try await store.upsert(values)
    }

    func delete<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Bool {
        try Task.checkCancellation()
        try mapValidation(Model.self) {
            try Model.Persistence.validate(id: id)
        }
        try validateRegistration(Model.self)
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.delete(Model.self, id: id)
    }

    func deleteAll<Model: LocalDatabaseModel>(
        _ type: Model.Type
    ) async throws -> Int {
        try Task.checkCancellation()
        try validateRegistration(Model.self)
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.deleteAll(Model.self)
    }

    private func resolveStore() throws -> SwiftDataLocalStore {
        switch state {
        case let .ready(store):
            return store
        case let .failed(error):
            throw error
        case let .uninitialized(factory):
            do {
                let container = try factory()
                try Task.checkCancellation()
                let store = SwiftDataLocalStore(
                    modelContainer: container,
                    hooks: hooks
                )
                state = .ready(store)
                return store
            } catch let error as CancellationError {
                state = .uninitialized(factory)
                throw error
            } catch {
                LocalDatabaseDiagnostics.report(
                    operation: .initialization,
                    entityType: "LocalDatabase",
                    recordCount: 0,
                    error: error
                )
                let mapped = LocalDatabaseError.initialization(
                    underlying: error
                )
                state = .failed(mapped)
                throw mapped
            }
        }
    }

    private func mapValidation<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        _ operation: () throws -> Void
    ) throws {
        do {
            try operation()
        } catch let reason as LocalDatabaseValidationError {
            throw LocalDatabaseError.validation(
                model: Model.Persistence.diagnosticName,
                reason: reason
            )
        }
    }

    private func validateRegistration<Model: LocalDatabaseModel>(
        _ type: Model.Type
    ) throws {
        do {
            try modelRegistry.validateIntegrity()
        } catch {
            LocalDatabaseDiagnostics.report(
                operation: .initialization,
                entityType: "LocalDatabase",
                recordCount: 0,
                error: error
            )
            throw LocalDatabaseError.initialization(underlying: error)
        }
        guard modelRegistry.contains(Model.Persistence.self) else {
            throw LocalDatabaseError.validation(
                model: Model.Persistence.diagnosticName,
                reason: .unregisteredModel
            )
        }
    }
}
