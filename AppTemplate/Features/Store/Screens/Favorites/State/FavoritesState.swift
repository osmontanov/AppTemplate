nonisolated
enum FavoritesState: Equatable, Sendable {
    case idle
    case loading
    case loaded(FavoritesModel)
    case empty
    case failed
}

nonisolated
enum FavoritesError: Equatable, Sendable {
    case readFailed
    case writeFailed
}
