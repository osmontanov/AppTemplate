import SwiftData

nonisolated
enum LocalDatabaseSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [StoredExampleRecord.self]
    }

    @Model
    final class StoredExampleRecord {
        @Attribute(.unique) var id: String
        var payload: String

        init(id: String, payload: String) {
            self.id = id
            self.payload = payload
        }
    }
}

nonisolated
enum LocalDatabaseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LocalDatabaseSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
