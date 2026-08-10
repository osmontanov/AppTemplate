nonisolated
struct ExampleQuery: Equatable, Sendable {
    let searchText: String?
    let limit: Int

    init(searchText: String? = nil, limit: Int = 50) {
        self.searchText = searchText
        self.limit = limit
    }
}
