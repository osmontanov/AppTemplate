import Foundation
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
enum LocalDatabaseSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            StoredExampleRecord.self,
            StoredFavoriteProductSnapshot.self,
            StoredCartAggregate.self
        ]
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

    @Model
    final class StoredFavoriteProductSnapshot {
        @Attribute(.unique) var canonicalID: String
        var userID: Int
        var productID: Int
        var snapshotData: Data

        init(
            canonicalID: String,
            userID: Int,
            productID: Int,
            snapshotData: Data
        ) {
            self.canonicalID = canonicalID
            self.userID = userID
            self.productID = productID
            self.snapshotData = snapshotData
        }
    }

    @Model
    final class StoredCartAggregate {
        @Attribute(.unique) var id: String
        var revision: Int64
        var linesData: Data

        init(id: String, revision: Int64, linesData: Data) {
            self.id = id
            self.revision = revision
            self.linesData = linesData
        }
    }
}

nonisolated
enum LocalDatabaseMigrationPlan: SchemaMigrationPlan {
    static let migrateV1ToV2 = MigrationStage.lightweight(
        fromVersion: LocalDatabaseSchemaV1.self,
        toVersion: LocalDatabaseSchemaV2.self
    )

    static var schemas: [any VersionedSchema.Type] {
        [LocalDatabaseSchemaV1.self, LocalDatabaseSchemaV2.self]
    }

    static var stages: [MigrationStage] { [migrateV1ToV2] }
}
