import SwiftData
import Testing
@testable import AppTemplate

struct ExampleRecordAdapterTests {
    @Test(arguments: ["", " ", "\n\t"])
    func rejectsBlankExampleIDs(id: String) {
        expectExampleValidation(.emptyID) {
            try ExampleRecordAdapter.validate(id: id)
        }
    }

    @Test
    func acceptsExactNonblankIdentityAndEmptyPayload() throws {
        let value = ExampleRecord(id: " local-42 ", payload: "")

        try ExampleRecordAdapter.validate(value: value)

        #expect(value.id == " local-42 ")
        #expect(value.payload.isEmpty)
    }

    @Test(arguments: [1, 200])
    func enforcesInclusiveExampleQueryLimits(limit: Int) throws {
        try ExampleRecordAdapter.validate(
            query: ExampleQuery(limit: limit)
        )
    }

    @Test(arguments: [0, 201])
    func rejectsOutOfRangeExampleQueryLimits(limit: Int) {
        expectExampleValidation(
            .invalidLimit(actual: limit, allowed: 1...200)
        ) {
            try ExampleRecordAdapter.validate(
                query: ExampleQuery(limit: limit)
            )
        }
    }

    @Test
    func attemptedExampleQueryCountUsesValidatedLimit() {
        #expect(
            ExampleRecordAdapter.attemptedRecordCount(
                for: ExampleQuery(limit: 37)
            ) == 37
        )
    }

    @Test
    func sharedBatchValidationRejectsFiveHundredOneValues() {
        let values = (0...500).map {
            ExampleRecord(id: "record-\($0)", payload: "value")
        }

        expectExampleValidation(
            .batchTooLarge(actual: 501, maximum: 500)
        ) {
            try LocalDatabaseValidator.validate(values: values)
        }
    }

    @Test
    func sharedBatchValidationRejectsExactDuplicateIDs() {
        expectExampleValidation(.duplicateID) {
            try LocalDatabaseValidator.validate(values: [
                ExampleRecord(id: "same", payload: "one"),
                ExampleRecord(id: "same", payload: "two")
            ])
        }
    }

    @Test
    func caseDistinctExampleIDsRemainDistinct() throws {
        try LocalDatabaseValidator.validate(values: [
            ExampleRecord(id: "same", payload: "one"),
            ExampleRecord(id: "SAME", payload: "two")
        ])
    }

    @Test
    func duplicatePersistedIDsThrowInsteadOfTrapping() {
        let first = LocalDatabaseSchemaV1.StoredExampleRecord(
            id: "same",
            payload: "one"
        )
        let second = LocalDatabaseSchemaV1.StoredExampleRecord(
            id: "same",
            payload: "two"
        )

        #expect(throws: LocalDatabasePersistenceInvariantError.self) {
            _ = try ExampleRecordAdapter.entitiesByID([first, second])
        }
    }
}

private func expectExampleValidation(
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
