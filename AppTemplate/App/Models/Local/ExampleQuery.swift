nonisolated
struct ExampleQuery: Equatable, Sendable {
    let searchText: String?
    let afterID: String?
    let limit: Int

    init(
        searchText: String? = nil,
        afterID: String? = nil,
        limit: Int = 50
    ) {
        self.searchText = searchText
        self.afterID = afterID
        self.limit = limit
    }
}
