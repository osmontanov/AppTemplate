nonisolated
protocol ILocalDatabaseService: Sendable {
    func fetchRecord(id: String) async throws -> ExampleRecord?
    func fetchRecords(
        matching query: ExampleQuery
    ) async throws -> [ExampleRecord]
    func upsert(_ record: ExampleRecord) async throws
    func upsert(_ records: [ExampleRecord]) async throws

    @discardableResult
    func deleteRecord(id: String) async throws -> Bool

    @discardableResult
    func deleteAllRecords() async throws -> Int
}
