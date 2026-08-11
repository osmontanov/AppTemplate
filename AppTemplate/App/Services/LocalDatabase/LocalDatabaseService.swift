actor LocalDatabaseService: ILocalDatabaseService {
    private enum State {
        case uninitialized(LocalDatabaseContainerFactory)
        case ready(SwiftDataLocalStore)
        case failed(LocalDatabaseError)
    }

    private var state: State
    private let hooks: LocalDatabaseStoreHooks

    init(
        containerFactory: @escaping LocalDatabaseContainerFactory,
        hooks: LocalDatabaseStoreHooks = .production
    ) {
        state = .uninitialized(containerFactory)
        self.hooks = hooks
    }

    func fetchRecord(id: String) async throws -> ExampleRecord? {
        try Task.checkCancellation()
        try mapValidation(model: ExampleRecordAdapter.diagnosticName) {
            try LocalDatabaseValidator.validate(id: id)
        }
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.fetchRecord(id: id)
    }

    func fetchRecords(
        matching query: ExampleQuery
    ) async throws -> [ExampleRecord] {
        try Task.checkCancellation()
        try mapValidation(model: ExampleRecordAdapter.diagnosticName) {
            try LocalDatabaseValidator.validate(query: query)
        }
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.fetchRecords(matching: query)
    }

    func upsert(_ record: ExampleRecord) async throws {
        try Task.checkCancellation()
        try mapValidation(model: ExampleRecordAdapter.diagnosticName) {
            try LocalDatabaseValidator.validate(record: record)
        }
        let store = try resolveStore()
        try Task.checkCancellation()
        try await store.upsert(record)
    }

    func upsert(_ records: [ExampleRecord]) async throws {
        try Task.checkCancellation()
        try mapValidation(model: ExampleRecordAdapter.diagnosticName) {
            try LocalDatabaseValidator.validate(records: records)
        }
        guard !records.isEmpty else { return }
        let store = try resolveStore()
        try Task.checkCancellation()
        try await store.upsert(records)
    }

    func deleteRecord(id: String) async throws -> Bool {
        try Task.checkCancellation()
        try mapValidation(model: ExampleRecordAdapter.diagnosticName) {
            try LocalDatabaseValidator.validate(id: id)
        }
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.deleteRecord(id: id)
    }

    func deleteAllRecords() async throws -> Int {
        try Task.checkCancellation()
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.deleteAllRecords()
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

    private func mapValidation(
        model: String,
        _ operation: () throws -> Void
    ) throws {
        do {
            try operation()
        } catch let error as LocalDatabaseValidationError {
            throw LocalDatabaseError.validation(
                model: model,
                reason: error
            )
        }
    }
}
