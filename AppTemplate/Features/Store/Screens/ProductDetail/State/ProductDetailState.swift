nonisolated
enum ProductDetailState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed
}
