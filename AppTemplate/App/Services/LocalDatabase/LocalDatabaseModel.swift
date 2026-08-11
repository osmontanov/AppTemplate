nonisolated
protocol LocalDatabaseModel: Identifiable, Sendable
where ID: Hashable & Sendable {
    associatedtype Query: Sendable
    associatedtype Persistence: LocalEntityAdapter
    where Persistence.Value == Self,
          Persistence.Query == Query
}
