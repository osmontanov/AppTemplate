import Foundation
import SwiftData

nonisolated
extension ExampleRecord: LocalDatabaseModel {
    typealias Query = ExampleQuery
    typealias Persistence = ExampleRecordAdapter
}

nonisolated
enum ExampleRecordAdapter: LocalEntityAdapter {
    typealias Value = ExampleRecord
    typealias Entity = LocalDatabaseSchemaV2.StoredExampleRecord
    typealias Query = ExampleQuery

    static let diagnosticName = "StoredExampleRecord"
    private static let queryLimitRange = 1...200
    // The cursor predicate `$0.id > afterID` compares raw unicode scalars in
    // the store; the sort order must match it or keyset pagination skips and
    // repeats records.
    private static let cursorOrder = SortDescriptor(
        \LocalDatabaseSchemaV2.StoredExampleRecord.id,
        comparator: .lexical
    )

    static func validate(id: String) throws {
        guard id.contains(where: { !$0.isWhitespace }) else {
            throw LocalDatabaseValidationError.emptyID
        }
    }

    static func validate(value: ExampleRecord) throws {
        try validate(id: value.id)
    }

    static func validate(query: ExampleQuery) throws {
        guard queryLimitRange.contains(query.limit) else {
            throw LocalDatabaseValidationError.invalidLimit(
                actual: query.limit,
                allowed: queryLimitRange
            )
        }
    }

    static func fetch(
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
        return try context.fetch(descriptor)
    }

    static func fetch(
        matching query: ExampleQuery,
        in context: ModelContext,
        progress: (_ examinedCount: Int) throws -> Void
    ) throws -> [Entity] {
        var descriptor: FetchDescriptor<
            LocalDatabaseSchemaV2.StoredExampleRecord
        >
        if let afterID = query.afterID {
            descriptor = FetchDescriptor<
                LocalDatabaseSchemaV2.StoredExampleRecord
            >(
                predicate: #Predicate { $0.id > afterID },
                sortBy: [cursorOrder]
            )
        } else {
            descriptor = FetchDescriptor<
                LocalDatabaseSchemaV2.StoredExampleRecord
            >(
                sortBy: [cursorOrder]
            )
        }
        guard let normalizedSearch = normalizedSearch(query.searchText) else {
            descriptor.fetchLimit = query.limit
            return try context.fetch(descriptor)
        }

        descriptor.includePendingChanges = false
        let entities = try context.fetch(descriptor, batchSize: 128)
        var matches: [Entity] = []
        var examinedCount = 0

        for entity in entities {
            examinedCount += 1
            let normalizedPayload = entity.payload.folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive,
                    .widthInsensitive
                ],
                locale: nil
            )
            if normalizedPayload.contains(normalizedSearch) {
                matches.append(entity)
            }
            if examinedCount.isMultiple(of: 128) {
                try progress(examinedCount)
            }
            if matches.count == query.limit {
                return matches
            }
        }

        return matches
    }

    static func attemptedRecordCount(for query: ExampleQuery) -> Int {
        query.limit
    }

    static func id(of entity: Entity) -> String { entity.id }

    static func value(from entity: Entity) -> ExampleRecord {
        ExampleRecord(id: entity.id, payload: entity.payload)
    }

    static func makeEntity(from value: ExampleRecord) -> Entity {
        Entity(id: value.id, payload: value.payload)
    }

    static func update(
        _ entity: Entity,
        from value: ExampleRecord
    ) -> Bool {
        guard entity.payload != value.payload else { return false }
        entity.payload = value.payload
        return true
    }

    private static func normalizedSearch(
        _ searchText: String?
    ) -> String? {
        guard let searchText else { return nil }
        let trimmed = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return nil }
        return trimmed.folding(
            options: [
                .caseInsensitive,
                .diacriticInsensitive,
                .widthInsensitive
            ],
            locale: nil
        )
    }
}
