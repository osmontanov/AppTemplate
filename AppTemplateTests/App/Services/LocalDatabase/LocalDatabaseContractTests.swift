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
    func storeModelsFreezeTheirCompileTimePersistenceAssociations() {
        requireModelAssociation(
            FavoriteProductSnapshot.self,
            id: String.self,
            query: FavoriteProductQuery.self,
            adapter: FavoriteProductSnapshotAdapter.self
        )
        requireModelAssociation(
            CartAggregate.self,
            id: String.self,
            query: CartAggregateQuery.self,
            adapter: CartAggregateAdapter.self
        )
        requireAdapterAssociation(
            FavoriteProductSnapshotAdapter.self,
            value: FavoriteProductSnapshot.self,
            entity: LocalDatabaseSchemaV2.StoredFavoriteProductSnapshot.self,
            query: FavoriteProductQuery.self
        )
        requireAdapterAssociation(
            CartAggregateAdapter.self,
            value: CartAggregate.self,
            entity: LocalDatabaseSchemaV2.StoredCartAggregate.self,
            query: CartAggregateQuery.self
        )
    }

    @Test
    func schemaKeepsFrozenV1AndAddsOneExplicitV2MigrationStage() {
        #expect(
            LocalDatabaseSchemaV1.versionIdentifier
                == Schema.Version(1, 0, 0)
        )
        #expect(LocalDatabaseSchemaV1.models.count == 1)
        #expect(
            LocalDatabaseSchemaV2.versionIdentifier
                == Schema.Version(2, 0, 0)
        )
        #expect(LocalDatabaseSchemaV2.models.count == 3)
        let schemaIdentifiers = LocalDatabaseMigrationPlan.schemas.map {
            ObjectIdentifier($0)
        }
        #expect(schemaIdentifiers == [
            ObjectIdentifier(LocalDatabaseSchemaV1.self),
            ObjectIdentifier(LocalDatabaseSchemaV2.self)
        ])
        #expect(LocalDatabaseMigrationPlan.stages.count == 1)
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

private func requireAdapterAssociation<Adapter: LocalEntityAdapter>(
    _ adapter: Adapter.Type,
    value: Adapter.Value.Type,
    entity: Adapter.Entity.Type,
    query: Adapter.Query.Type
) {
    _ = adapter
    _ = value
    _ = entity
    _ = query
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
