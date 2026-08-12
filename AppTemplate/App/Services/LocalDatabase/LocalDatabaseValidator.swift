nonisolated
enum LocalDatabaseValidator {
    static let maximumBatchSize = 500

    static func validate<Model: LocalDatabaseModel>(
        values: [Model]
    ) throws {
        guard values.count <= maximumBatchSize else {
            throw LocalDatabaseValidationError.batchTooLarge(
                actual: values.count,
                maximum: maximumBatchSize
            )
        }

        var identities = Set<Model.ID>()
        for value in values {
            try Model.Persistence.validate(value: value)
            guard identities.insert(value.id).inserted else {
                throw LocalDatabaseValidationError.duplicateID
            }
        }
    }
}
