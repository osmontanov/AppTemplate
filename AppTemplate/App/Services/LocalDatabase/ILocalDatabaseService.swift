nonisolated
protocol ILocalDatabaseService: Sendable {
    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Model?

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        matching query: Model.Query
    ) async throws -> [Model]

    func upsert<Model: LocalDatabaseModel>(
        _ value: Model
    ) async throws

    func upsert<Model: LocalDatabaseModel>(
        _ values: [Model]
    ) async throws

    @discardableResult
    func delete<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Bool

    @discardableResult
    func deleteAll<Model: LocalDatabaseModel>(
        _ type: Model.Type
    ) async throws -> Int
}
