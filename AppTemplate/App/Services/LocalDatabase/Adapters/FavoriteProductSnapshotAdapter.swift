import Foundation
import SwiftData

nonisolated
enum StorePersistenceValidationError: Error, Equatable, Sendable {
    case encodedDataTooLarge(actual: Int, maximum: Int)
    case invalidEncodedData
    case storedIdentityMismatch
}

nonisolated
enum FavoriteProductSnapshotAdapter: LocalEntityAdapter {
    typealias Value = FavoriteProductSnapshot
    typealias Entity = LocalDatabaseSchemaV2.StoredFavoriteProductSnapshot
    typealias Query = FavoriteProductQuery

    static let diagnosticName = "StoredFavoriteProductSnapshot"
    private static let maximumSnapshotByteCount = 64 * 1_024

    static func validate(id: String) throws {
        guard isCanonicalID(id) else {
            throw StoreModelValidationError.invalidFavoriteIdentity
        }
    }

    static func validate(value: FavoriteProductSnapshot) throws {
        try value.validateStoreInvariants()
        _ = try encodeSnapshot(value.product)
    }

    static func validate(query: FavoriteProductQuery) throws {
        guard query.userID > 0 else {
            throw StoreModelValidationError.invalidUserID
        }
    }

    static func fetch(
        id: String,
        in context: ModelContext
    ) throws -> Entity? {
        var descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate { $0.canonicalID == id }
        )
        descriptor.fetchLimit = 2
        let entity = try uniqueEntity(from: context.fetch(descriptor))
        try entity.map(validateStoredEntity)
        return entity
    }

    // Removal must stay possible for records whose payload no longer decodes,
    // so this lookup deliberately skips stored-entity validation.
    static func fetchEntityForRemoval(
        id: String,
        in context: ModelContext
    ) throws -> Entity? {
        var descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate { $0.canonicalID == id }
        )
        descriptor.fetchLimit = 2
        return try uniqueEntity(from: context.fetch(descriptor))
    }

    static func fetchExisting(
        ids: [String],
        in context: ModelContext
    ) throws -> [Entity] {
        let descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate { ids.contains($0.canonicalID) }
        )
        let entities = try context.fetch(descriptor)
        try entities.forEach(validateStoredEntity)
        return entities
    }

    static func fetch(
        matching query: FavoriteProductQuery,
        in context: ModelContext,
        progress: (_ examinedCount: Int) throws -> Void
    ) throws -> [Entity] {
        let userID = query.userID
        let descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate { $0.userID == userID },
            sortBy: [SortDescriptor(\Entity.productID)]
        )
        let entities = try context.fetch(descriptor)
        var examinedCount = 0
        for entity in entities {
            examinedCount += 1
            try validateStoredEntity(entity)
            if examinedCount.isMultiple(of: 128) {
                try progress(examinedCount)
            }
        }
        return entities
    }

    static func attemptedRecordCount(
        for query: FavoriteProductQuery
    ) -> Int {
        _ = query
        return 500
    }

    static func id(of entity: Entity) -> String {
        entity.canonicalID
    }

    static func value(from entity: Entity) -> FavoriteProductSnapshot {
        do {
            return try decodedValue(from: entity)
        } catch {
            preconditionFailure(
                "Favorite entity must be validated before conversion"
            )
        }
    }

    static func makeEntity(
        from value: FavoriteProductSnapshot
    ) -> Entity {
        Entity(
            canonicalID: value.canonicalID,
            userID: value.userID,
            productID: value.product.id,
            snapshotData: prevalidatedEncoding(of: value.product)
        )
    }

    static func update(
        _ entity: Entity,
        from value: FavoriteProductSnapshot
    ) -> Bool {
        let snapshotData = prevalidatedEncoding(of: value.product)
        guard entity.userID != value.userID
            || entity.productID != value.product.id
            || entity.snapshotData != snapshotData
        else { return false }
        entity.userID = value.userID
        entity.productID = value.product.id
        entity.snapshotData = snapshotData
        return true
    }

    private static func validateStoredEntity(_ entity: Entity) throws {
        _ = try decodedValue(from: entity)
    }

    private static func decodedValue(
        from entity: Entity
    ) throws -> FavoriteProductSnapshot {
        try validateEncodedSize(
            entity.snapshotData,
            maximum: maximumSnapshotByteCount
        )
        let product: ProductSnapshot
        do {
            product = try JSONDecoder().decode(
                ProductSnapshot.self,
                from: entity.snapshotData
            )
        } catch let error as StoreModelValidationError {
            throw error
        } catch {
            throw StorePersistenceValidationError.invalidEncodedData
        }
        guard entity.productID == product.id else {
            throw StorePersistenceValidationError.storedIdentityMismatch
        }
        let value = FavoriteProductSnapshot(
            canonicalID: entity.canonicalID,
            userID: entity.userID,
            product: product
        )
        do {
            try value.validateStoreInvariants()
        } catch {
            throw StorePersistenceValidationError.storedIdentityMismatch
        }
        return value
    }

    private static func encodeSnapshot(
        _ snapshot: ProductSnapshot
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(snapshot)
        } catch {
            throw StorePersistenceValidationError.invalidEncodedData
        }
        try validateEncodedSize(
            data,
            maximum: maximumSnapshotByteCount
        )
        return data
    }

    private static func prevalidatedEncoding(
        of snapshot: ProductSnapshot
    ) -> Data {
        do {
            return try encodeSnapshot(snapshot)
        } catch {
            preconditionFailure(
                "Favorite value must be validated before persistence"
            )
        }
    }

    private static func validateEncodedSize(
        _ data: Data,
        maximum: Int
    ) throws {
        guard data.count <= maximum else {
            throw StorePersistenceValidationError.encodedDataTooLarge(
                actual: data.count,
                maximum: maximum
            )
        }
    }

    private static func isCanonicalID(_ id: String) -> Bool {
        let components = id.split(separator: "|", omittingEmptySubsequences: false)
        guard components.count == 2,
              components[0].hasPrefix("user:"),
              components[1].hasPrefix("product:"),
              let userID = Int(components[0].dropFirst("user:".count)),
              let productID = Int(components[1].dropFirst("product:".count)),
              userID > 0,
              productID > 0
        else { return false }
        return id == FavoriteProductSnapshot.canonicalID(
            userID: userID,
            productID: productID
        )
    }
}
