import Foundation
import SwiftData

nonisolated
enum CartAggregateAdapter: LocalEntityAdapter {
    typealias Value = CartAggregate
    typealias Entity = LocalDatabaseSchemaV2.StoredCartAggregate
    typealias Query = CartAggregateQuery

    static let diagnosticName = "StoredCartAggregate"
    private static let maximumLinesByteCount = 256 * 1_024

    static func validate(id: String) throws {
        guard id == CartAggregate.singletonID else {
            throw StoreModelValidationError.invalidCartIdentity
        }
    }

    static func validate(value: CartAggregate) throws {
        try value.validateStoreInvariants()
        _ = try encodeLines(value.lines)
    }

    static func validate(query: CartAggregateQuery) throws {
        _ = query
    }

    static func fetch(
        id: String,
        in context: ModelContext
    ) throws -> Entity? {
        var descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate { $0.id == id }
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
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 2
        return try uniqueEntity(from: context.fetch(descriptor))
    }

    static func fetchExisting(
        ids: [String],
        in context: ModelContext
    ) throws -> [Entity] {
        let descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let entities = try context.fetch(descriptor)
        try entities.forEach(validateStoredEntity)
        return entities
    }

    static func fetch(
        matching query: CartAggregateQuery,
        in context: ModelContext,
        progress: (_ examinedCount: Int) throws -> Void
    ) throws -> [Entity] {
        _ = query
        _ = progress
        let singletonID = CartAggregate.singletonID
        var descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate { $0.id == singletonID }
        )
        descriptor.fetchLimit = 2
        let entities = try context.fetch(descriptor)
        _ = try uniqueEntity(from: entities)
        try entities.forEach(validateStoredEntity)
        return entities
    }

    static func attemptedRecordCount(for query: CartAggregateQuery) -> Int {
        _ = query
        return 1
    }

    static func id(of entity: Entity) -> String { entity.id }

    static func value(from entity: Entity) -> CartAggregate {
        do {
            return try decodedValue(from: entity)
        } catch {
            preconditionFailure(
                "Cart entity must be validated before conversion"
            )
        }
    }

    static func makeEntity(from value: CartAggregate) -> Entity {
        Entity(
            id: value.id,
            revision: value.revision,
            linesData: prevalidatedEncoding(of: value.lines)
        )
    }

    static func update(
        _ entity: Entity,
        from value: CartAggregate
    ) -> Bool {
        let linesData = prevalidatedEncoding(of: value.lines)
        guard entity.revision != value.revision
            || entity.linesData != linesData
        else { return false }
        entity.revision = value.revision
        entity.linesData = linesData
        return true
    }

    private static func validateStoredEntity(_ entity: Entity) throws {
        _ = try decodedValue(from: entity)
    }

    private static func decodedValue(
        from entity: Entity
    ) throws -> CartAggregate {
        try validateEncodedSize(entity.linesData)
        let lines: [CartLine]
        do {
            lines = try JSONDecoder().decode(
                [CartLine].self,
                from: entity.linesData
            )
        } catch let error as StoreModelValidationError {
            throw error
        } catch {
            throw StorePersistenceValidationError.invalidEncodedData
        }
        let value = CartAggregate(
            id: entity.id,
            revision: entity.revision,
            lines: lines
        )
        try value.validateStoreInvariants()
        return value
    }

    private static func encodeLines(_ lines: [CartLine]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(lines)
        } catch {
            throw StorePersistenceValidationError.invalidEncodedData
        }
        try validateEncodedSize(data)
        return data
    }

    private static func prevalidatedEncoding(of lines: [CartLine]) -> Data {
        do {
            return try encodeLines(lines)
        } catch {
            preconditionFailure(
                "Cart value must be validated before persistence"
            )
        }
    }

    private static func validateEncodedSize(_ data: Data) throws {
        guard data.count <= maximumLinesByteCount else {
            throw StorePersistenceValidationError.encodedDataTooLarge(
                actual: data.count,
                maximum: maximumLinesByteCount
            )
        }
    }
}
