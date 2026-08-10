nonisolated
enum LocalDatabaseStoreCheckpoint: Equatable, Sendable {
    case read(LocalDatabaseReadOperation)
    case readProgress(LocalDatabaseReadOperation)
    case writePreparation(LocalDatabaseWriteOperation)
    case beforeSave(LocalDatabaseWriteOperation)
}

nonisolated
struct LocalDatabaseStoreHooks: Sendable {
    let checkpoint:
        @Sendable (LocalDatabaseStoreCheckpoint) throws -> Void
    let didSave:
        @Sendable (LocalDatabaseWriteOperation) -> Void
    let didRollback:
        @Sendable (LocalDatabaseWriteOperation) -> Void

    static let production = LocalDatabaseStoreHooks(
        checkpoint: { _ in },
        didSave: { _ in },
        didRollback: { _ in }
    )
}
