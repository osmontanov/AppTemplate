import Foundation
import SwiftData
@testable import AppTemplate

nonisolated
struct TestLocalRecordID: Hashable, Sendable {
    let rawValue: Int
}

nonisolated
struct TestLocalQuery: Equatable, Sendable {
    let minimumScore: Int?
    let limit: Int

    init(minimumScore: Int? = nil, limit: Int = 10) {
        self.minimumScore = minimumScore
        self.limit = limit
    }
}

nonisolated
struct TestLocalRecord: Identifiable, Equatable, Sendable,
    LocalDatabaseModel
{
    typealias Query = TestLocalQuery
    typealias Persistence = TestLocalRecordAdapter

    let id: TestLocalRecordID
    let score: Int
    let title: String
}

@Model
nonisolated final class StoredTestLocalRecord {
    @Attribute(.unique) var businessID: Int
    var score: Int
    var title: String

    init(businessID: Int, score: Int, title: String) {
        self.businessID = businessID
        self.score = score
        self.title = title
    }
}

nonisolated
enum GenericLocalDatabaseFixtureError: Error, Sendable {
    case storageNotImplemented
}

nonisolated
enum TestLocalRecordAdapter: LocalEntityAdapter {
    typealias Value = TestLocalRecord
    typealias Entity = StoredTestLocalRecord
    typealias Query = TestLocalQuery

    static let diagnosticName = "StoredTestLocalRecord"
    private static let queryLimitRange = 1...200

    static func validate(id: TestLocalRecordID) throws {}

    static func validate(value: TestLocalRecord) throws {}

    static func validate(query: TestLocalQuery) throws {
        guard queryLimitRange.contains(query.limit) else {
            throw LocalDatabaseValidationError.invalidLimit(
                actual: query.limit,
                allowed: queryLimitRange
            )
        }
    }

    static func fetch(
        id: TestLocalRecordID,
        in context: ModelContext
    ) throws -> StoredTestLocalRecord? {
        throw GenericLocalDatabaseFixtureError.storageNotImplemented
    }

    static func fetchExisting(
        ids: [TestLocalRecordID],
        in context: ModelContext
    ) throws -> [StoredTestLocalRecord] {
        throw GenericLocalDatabaseFixtureError.storageNotImplemented
    }

    static func fetch(
        matching query: TestLocalQuery,
        in context: ModelContext,
        progress: (_ examinedCount: Int) throws -> Void
    ) throws -> [StoredTestLocalRecord] {
        throw GenericLocalDatabaseFixtureError.storageNotImplemented
    }

    static func attemptedRecordCount(for query: TestLocalQuery) -> Int {
        query.limit
    }

    static func id(
        of entity: StoredTestLocalRecord
    ) -> TestLocalRecordID {
        TestLocalRecordID(rawValue: entity.businessID)
    }

    static func value(
        from entity: StoredTestLocalRecord
    ) -> TestLocalRecord {
        TestLocalRecord(
            id: TestLocalRecordID(rawValue: entity.businessID),
            score: entity.score,
            title: entity.title
        )
    }

    static func makeEntity(
        from value: TestLocalRecord
    ) -> StoredTestLocalRecord {
        StoredTestLocalRecord(
            businessID: value.id.rawValue,
            score: value.score,
            title: value.title
        )
    }

    static func update(
        _ entity: StoredTestLocalRecord,
        from value: TestLocalRecord
    ) -> Bool {
        guard entity.score != value.score
            || entity.title != value.title
        else { return false }
        entity.score = value.score
        entity.title = value.title
        return true
    }
}

nonisolated
func makeGenericTestRegistry() -> LocalDatabaseModelRegistry {
    LocalDatabaseModelRegistry(adapters: [
        ExampleRecordAdapter.self,
        TestLocalRecordAdapter.self
    ])
}

nonisolated
func makeGenericInMemoryLocalDatabaseContainer() throws -> ModelContainer {
    let schema = Schema([
        LocalDatabaseSchemaV1.StoredExampleRecord.self,
        StoredTestLocalRecord.self
    ])
    let configuration = ModelConfiguration(
        "GenericLocalDatabaseTests",
        schema: schema,
        isStoredInMemoryOnly: true,
        allowsSave: true,
        groupContainer: .none,
        cloudKitDatabase: .none
    )
    return try ModelContainer(
        for: schema,
        configurations: [configuration]
    )
}

nonisolated
func makeGenericTestConfiguration() -> LocalDatabaseStoreConfiguration {
    LocalDatabaseStoreConfiguration(
        containerFactory: {
            try makeGenericInMemoryLocalDatabaseContainer()
        },
        modelRegistry: makeGenericTestRegistry()
    )
}
