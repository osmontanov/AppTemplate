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
