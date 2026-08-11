nonisolated
enum LocalDatabaseValidationError: Error, Equatable, Sendable {
    case emptyID
    case invalidLimit(actual: Int, allowed: ClosedRange<Int>)
    case batchTooLarge(actual: Int, maximum: Int)
    case duplicateID
    case unregisteredModel
}

nonisolated
enum LocalDatabaseReadOperation: Equatable, Sendable {
    case fetchOne
    case fetchMany
}

nonisolated
enum LocalDatabaseWriteOperation: Equatable, Sendable {
    case upsertOne
    case upsertBatch
    case deleteOne
    case deleteAll
}

nonisolated
enum LocalDatabaseError: Error {
    case validation(
        model: String,
        reason: LocalDatabaseValidationError
    )
    case initialization(underlying: any Error)
    case read(
        model: String,
        operation: LocalDatabaseReadOperation,
        underlying: any Error
    )
    case write(
        model: String,
        operation: LocalDatabaseWriteOperation,
        underlying: any Error
    )
}
