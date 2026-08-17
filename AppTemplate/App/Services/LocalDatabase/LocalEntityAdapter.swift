import SwiftData

nonisolated
enum LocalDatabasePersistenceInvariantError:
    Error,
    Equatable,
    Sendable
{
    case duplicatePersistedID
}

nonisolated
protocol LocalEntityAdapter: SendableMetatype
where Value.Persistence == Self, Value.Query == Query {
    associatedtype Value: LocalDatabaseModel
    associatedtype Entity: PersistentModel
    associatedtype Query: Sendable

    static var diagnosticName: String { get }
    static var adapterIdentifier: ObjectIdentifier { get }
    static var valueIdentifier: ObjectIdentifier { get }
    static var entityIdentifier: ObjectIdentifier { get }

    static func validate(id: Value.ID) throws
    static func validate(value: Value) throws
    static func validate(query: Query) throws
    static func fetch(
        id: Value.ID,
        in context: ModelContext
    ) throws -> Entity?
    static func fetchEntityForRemoval(
        id: Value.ID,
        in context: ModelContext
    ) throws -> Entity?
    static func fetchExisting(
        ids: [Value.ID],
        in context: ModelContext
    ) throws -> [Entity]
    static func fetch(
        matching query: Query,
        in context: ModelContext,
        progress: (_ examinedCount: Int) throws -> Void
    ) throws -> [Entity]
    static func attemptedRecordCount(for query: Query) -> Int
    static func id(of entity: Entity) -> Value.ID
    static func value(from entity: Entity) -> Value
    static func makeEntity(from value: Value) -> Entity
    static func update(_ entity: Entity, from value: Value) -> Bool
}

nonisolated
extension LocalEntityAdapter {
    static func fetchEntityForRemoval(
        id: Value.ID,
        in context: ModelContext
    ) throws -> Entity? {
        try fetch(id: id, in: context)
    }

    static var adapterIdentifier: ObjectIdentifier {
        ObjectIdentifier(Self.self)
    }

    static var valueIdentifier: ObjectIdentifier {
        ObjectIdentifier(Value.self)
    }

    static var entityIdentifier: ObjectIdentifier {
        ObjectIdentifier(Entity.self)
    }

    static func uniqueEntity(
        from entities: [Entity]
    ) throws -> Entity? {
        guard entities.count <= 1 else {
            throw LocalDatabasePersistenceInvariantError
                .duplicatePersistedID
        }
        return entities.first
    }

    static func entitiesByID(
        _ entities: [Entity]
    ) throws -> [Value.ID: Entity] {
        var result: [Value.ID: Entity] = [:]
        for entity in entities {
            let businessID = id(of: entity)
            guard result.updateValue(entity, forKey: businessID) == nil else {
                throw LocalDatabasePersistenceInvariantError
                    .duplicatePersistedID
            }
        }
        return result
    }
}
