actor LocalDatabaseExampleRepository: ILocalDatabaseExampleRepository {
    private let database: any ILocalDatabaseService
    private let mutationGate = AsyncOperationGate()

    init(database: any ILocalDatabaseService) {
        self.database = database
    }

    func fetch(id: String) async throws -> ExampleRecord? {
        try await database.fetch(ExampleRecord.self, id: id)
    }

    func page(
        searchText: String?,
        afterID: String?,
        pageSize: Int
    ) async throws -> LocalDatabasePage<ExampleRecord, String> {
        guard (1...50).contains(pageSize) else {
            throw ExampleRecordRepositoryError.invalidPageSize
        }
        let fetched = try await database.fetch(
            ExampleRecord.self,
            matching: ExampleQuery(
                searchText: searchText,
                afterID: afterID,
                limit: pageSize + 1
            )
        )
        let hasMore = fetched.count > pageSize
        let visible = Array(fetched.prefix(pageSize))
        return LocalDatabasePage(
            values: visible,
            nextCursor: hasMore ? visible.last?.id : nil,
            hasMore: hasMore
        )
    }

    func create(id: String, payload: String) async throws {
        let database = database
        try await mutationGate.withExclusiveAccess {
            try await Self.create(
                id: id,
                payload: payload,
                database: database
            )
        }
    }

    func update(id: String, payload: String) async throws {
        let database = database
        try await mutationGate.withExclusiveAccess {
            try await Self.update(
                id: id,
                payload: payload,
                database: database
            )
        }
    }

    func upsert(_ record: ExampleRecord) async throws {
        let database = database
        try await mutationGate.withExclusiveAccess {
            try await Self.upsert(record, database: database)
        }
    }

    func upsertBatch(_ records: [ExampleRecord]) async throws {
        let database = database
        try await mutationGate.withExclusiveAccess {
            try await Self.upsertBatch(records, database: database)
        }
    }

    func delete(id: String) async throws -> Bool {
        let database = database
        return try await mutationGate.withExclusiveAccess {
            try await database.delete(ExampleRecord.self, id: id)
        }
    }

    func deleteAll() async throws -> Int {
        let database = database
        return try await mutationGate.withExclusiveAccess {
            try await database.deleteAll(ExampleRecord.self)
        }
    }

    func waitUntilQueuedMutationCountForTesting(_ expectedCount: Int) async {
        await mutationGate.waitUntilWaiterCountForTesting(expectedCount)
    }

    private nonisolated static func create(
        id: String,
        payload: String,
        database: any ILocalDatabaseService
    ) async throws {
        guard id.contains(where: { !$0.isWhitespace }) else {
            throw ExampleRecordRepositoryError.invalidID
        }
        guard try await database.fetch(ExampleRecord.self, id: id) == nil else {
            throw ExampleRecordRepositoryError.alreadyExists
        }
        try ExampleRecordCreationValidator.validateNewID(id)
        try await database.upsert(ExampleRecord(id: id, payload: payload))
    }

    private nonisolated static func update(
        id: String,
        payload: String,
        database: any ILocalDatabaseService
    ) async throws {
        guard try await database.fetch(ExampleRecord.self, id: id) != nil else {
            throw ExampleRecordRepositoryError.notFound
        }
        try await database.upsert(ExampleRecord(id: id, payload: payload))
    }

    private nonisolated static func upsert(
        _ record: ExampleRecord,
        database: any ILocalDatabaseService
    ) async throws {
        guard record.id.contains(where: { !$0.isWhitespace }) else {
            throw ExampleRecordRepositoryError.invalidID
        }
        if try await database.fetch(ExampleRecord.self, id: record.id) == nil {
            try ExampleRecordCreationValidator.validateNewID(record.id)
        }
        try await database.upsert(record)
    }

    private nonisolated static func upsertBatch(
        _ records: [ExampleRecord],
        database: any ILocalDatabaseService
    ) async throws {
        do {
            try LocalDatabaseValidator.validate(values: records)
        } catch let reason as LocalDatabaseValidationError {
            throw LocalDatabaseError.validation(
                model: ExampleRecordAdapter.diagnosticName,
                reason: reason
            )
        }
        for record in records {
            if try await database.fetch(
                ExampleRecord.self,
                id: record.id
            ) == nil {
                try ExampleRecordCreationValidator.validateNewID(record.id)
            }
        }
        try await database.upsert(records)
    }
}
