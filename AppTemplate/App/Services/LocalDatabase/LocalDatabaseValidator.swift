nonisolated
enum LocalDatabaseValidator {
    static let queryLimitRange = 1...200
    static let maximumBatchSize = 500

    static func validate(id: String) throws {
        guard id.contains(where: { !$0.isWhitespace }) else {
            throw LocalDatabaseValidationError.emptyID
        }
    }

    static func validate(record: ExampleRecord) throws {
        try validate(id: record.id)
    }

    static func validate(query: ExampleQuery) throws {
        guard queryLimitRange.contains(query.limit) else {
            throw LocalDatabaseValidationError.invalidLimit(
                actual: query.limit,
                allowed: queryLimitRange
            )
        }
    }

    static func validate(records: [ExampleRecord]) throws {
        guard records.count <= maximumBatchSize else {
            throw LocalDatabaseValidationError.batchTooLarge(
                actual: records.count,
                maximum: maximumBatchSize
            )
        }

        var identities = Set<String>()
        for record in records {
            try validate(record: record)
            guard identities.insert(record.id).inserted else {
                throw LocalDatabaseValidationError.duplicateID
            }
        }
    }
}
