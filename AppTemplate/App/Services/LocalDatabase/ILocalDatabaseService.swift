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

    func existingIDs<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        ids: [Model.ID]
    ) async throws -> Set<Model.ID>

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

nonisolated
extension ILocalDatabaseService {
    func existingIDs<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        ids: [Model.ID]
    ) async throws -> Set<Model.ID> {
        var existing = Set<Model.ID>()
        for id in ids {
            if try await fetch(type, id: id) != nil {
                existing.insert(id)
            }
        }
        return existing
    }
}
