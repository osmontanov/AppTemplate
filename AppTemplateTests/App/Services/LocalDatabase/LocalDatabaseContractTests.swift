import SwiftData
import Testing
@testable import AppTemplate

struct LocalDatabaseContractTests {
    @Test
    func queryDefaultsToUnfilteredFiftyRecordLimit() {
        let query = ExampleQuery()

        #expect(query.searchText == nil)
        #expect(query.limit == 50)
    }

    @Test
    func validatorRejectsBlankIDs() {
        for id in ["", " ", "\n\t"] {
            expectValidationError(.emptyID) {
                try LocalDatabaseValidator.validate(id: id)
            }
        }
    }

    @Test
    func validatorAcceptsExactNonblankIdentityAndEmptyPayload() throws {
        try LocalDatabaseValidator.validate(
            record: ExampleRecord(id: " local-42 ", payload: "")
        )
    }

    @Test
    func validatorEnforcesInclusiveQueryBounds() throws {
        try LocalDatabaseValidator.validate(
            query: ExampleQuery(limit: 1)
        )
        try LocalDatabaseValidator.validate(
            query: ExampleQuery(limit: 200)
        )
        expectValidationError(
            .invalidLimit(actual: 0, allowed: 1...200)
        ) {
            try LocalDatabaseValidator.validate(
                query: ExampleQuery(limit: 0)
            )
        }
        expectValidationError(
            .invalidLimit(actual: 201, allowed: 1...200)
        ) {
            try LocalDatabaseValidator.validate(
                query: ExampleQuery(limit: 201)
            )
        }
    }

    @Test
    func validatorRejectsOversizedAndDuplicateBatches() {
        let oversized = (0...500).map {
            ExampleRecord(id: "record-\($0)", payload: "value")
        }
        expectValidationError(
            .batchTooLarge(actual: 501, maximum: 500)
        ) {
            try LocalDatabaseValidator.validate(records: oversized)
        }
        expectValidationError(.duplicateID) {
            try LocalDatabaseValidator.validate(records: [
                ExampleRecord(id: "same", payload: "one"),
                ExampleRecord(id: "same", payload: "two")
            ])
        }
    }

    @Test
    func schemaStartsAtV1WithoutInventedMigrationStage() {
        #expect(
            LocalDatabaseSchemaV1.versionIdentifier
                == Schema.Version(1, 0, 0)
        )
        #expect(LocalDatabaseSchemaV1.models.count == 1)
        #expect(LocalDatabaseMigrationPlan.schemas.count == 1)
        #expect(LocalDatabaseMigrationPlan.stages.isEmpty)
    }
}

private func expectValidationError(
    _ expected: LocalDatabaseValidationError,
    operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("Expected LocalDatabaseValidationError")
    } catch let error as LocalDatabaseValidationError {
        #expect(error == expected)
    } catch {
        Issue.record("Unexpected error type: \(type(of: error))")
    }
}
