nonisolated
struct LocalDatabasePage<Value: Sendable, Cursor: Sendable>: Sendable {
    let values: [Value]
    let nextCursor: Cursor?
    let hasMore: Bool
}
