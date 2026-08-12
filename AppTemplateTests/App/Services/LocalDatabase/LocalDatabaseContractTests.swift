import SwiftData
import Testing
@testable import AppTemplate

struct LocalDatabaseContractTests {
    @Test
    func exampleQueryDefaultsToUnfilteredFiftyRecordLimit() {
        let query = ExampleQuery()

        #expect(query.searchText == nil)
        #expect(query.limit == 50)
    }

    @Test
    func exampleRecordUsesStringIDExampleQueryAndExampleAdapter() {
        requireModelAssociation(
            ExampleRecord.self,
            id: String.self,
            query: ExampleQuery.self,
            adapter: ExampleRecordAdapter.self
        )
    }

    @Test
    func schemaRemainsFrozenAtV1WithoutMigrationStages() {
        #expect(
            LocalDatabaseSchemaV1.versionIdentifier
                == Schema.Version(1, 0, 0)
        )
        #expect(LocalDatabaseSchemaV1.models.count == 1)
        #expect(LocalDatabaseMigrationPlan.schemas.count == 1)
        #expect(LocalDatabaseMigrationPlan.stages.isEmpty)
    }

    @Test
    func genericServiceContractIsCallableThroughExistential() async throws {
        let service: any ILocalDatabaseService = GenericNoOpDatabase()
        #expect(
            try await service.fetch(ExampleRecord.self, id: "id") == nil
        )
        #expect(
            try await service.fetch(
                TestLocalRecord.self,
                matching: TestLocalQuery()
            ).isEmpty
        )
    }
}

actor GenericNoOpDatabase: ILocalDatabaseService {
    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Model? { nil }

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        matching query: Model.Query
    ) async throws -> [Model] { [] }

    func upsert<Model: LocalDatabaseModel>(
        _ value: Model
    ) async throws {}

    func upsert<Model: LocalDatabaseModel>(
        _ values: [Model]
    ) async throws {}

    func delete<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Bool { false }

    func deleteAll<Model: LocalDatabaseModel>(
        _ type: Model.Type
    ) async throws -> Int { 0 }
}

private func requireModelAssociation<Model: LocalDatabaseModel>(
    _ model: Model.Type,
    id: Model.ID.Type,
    query: Model.Query.Type,
    adapter: Model.Persistence.Type
) {
    _ = model
    _ = id
    _ = query
    _ = adapter
}
