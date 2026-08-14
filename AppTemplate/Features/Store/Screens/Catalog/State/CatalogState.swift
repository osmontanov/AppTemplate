nonisolated
enum CatalogState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed
}
