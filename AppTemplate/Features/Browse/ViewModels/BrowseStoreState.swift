nonisolated enum BrowseFailure: Equatable, Sendable {
    case load

    var message: String {
        "Browse content could not be loaded."
    }
}

nonisolated enum BrowseListState: Equatable, Sendable {
    case idle
    case loading
    case content([BrowseItem])
    case failed(BrowseFailure)
}

nonisolated enum BrowseDetailState: Equatable, Sendable {
    case idle
    case loading
    case content(BrowseItem)
    case notFound
    case failed(BrowseFailure)
}
