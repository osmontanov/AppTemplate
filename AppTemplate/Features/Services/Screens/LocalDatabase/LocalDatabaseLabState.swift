nonisolated
struct LocalDatabaseLabState: Equatable, Sendable {
    var records: [ExampleRecord]
    var nextCursor: String?
    var hasMore: Bool
    var isLoading: Bool
    var searchText: String
    var pageSize: Int

    init(
        records: [ExampleRecord] = [],
        nextCursor: String? = nil,
        hasMore: Bool = false,
        isLoading: Bool = false,
        searchText: String = "",
        pageSize: Int = 20
    ) {
        self.records = records
        self.nextCursor = nextCursor
        self.hasMore = hasMore
        self.isLoading = isLoading
        self.searchText = searchText
        self.pageSize = pageSize
    }
}

nonisolated
enum LocalDatabaseLabRetryOperation: Equatable, Sendable {
    case fetch(String)
    case page(search: String?, afterID: String?, pageSize: Int)
    case create(ExampleRecord)
    case update(ExampleRecord)
    case upsert(ExampleRecord)
    case upsertBatch([ExampleRecord])
    case delete(String)
    case deleteAll
    case reset
}
