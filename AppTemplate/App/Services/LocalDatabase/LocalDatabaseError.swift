nonisolated
enum LocalDatabaseValidationError: Error, Equatable, Sendable {
    case emptyID
    case invalidLimit(actual: Int, allowed: ClosedRange<Int>)
    case batchTooLarge(actual: Int, maximum: Int)
    case duplicateID
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
    case validation(LocalDatabaseValidationError)
    case initialization(underlying: any Error)
    case read(
        operation: LocalDatabaseReadOperation,
        underlying: any Error
    )
    case write(
        operation: LocalDatabaseWriteOperation,
        underlying: any Error
    )
}
