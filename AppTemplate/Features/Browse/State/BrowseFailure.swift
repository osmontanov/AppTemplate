nonisolated
enum BrowseFailure: Equatable, Sendable {
    case load

    var message: String {
        "Browse content could not be loaded."
    }
}
