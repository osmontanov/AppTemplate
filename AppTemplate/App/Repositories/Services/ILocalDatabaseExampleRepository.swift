nonisolated
enum ExampleRecordRepositoryError: Error, Equatable, Sendable {
    case invalidID
    case invalidPageSize
    case alreadyExists
    case notFound
}

nonisolated
protocol ILocalDatabaseExampleRepository: Sendable {
    func fetch(id: String) async throws -> ExampleRecord?

    func page(
        searchText: String?,
        afterID: String?,
        pageSize: Int
    ) async throws -> LocalDatabasePage<ExampleRecord, String>

    func create(id: String, payload: String) async throws
    func update(id: String, payload: String) async throws
    func upsert(_ record: ExampleRecord) async throws
    func upsertBatch(_ records: [ExampleRecord]) async throws

    @discardableResult
    func delete(id: String) async throws -> Bool

    @discardableResult
    func deleteAll() async throws -> Int
}
