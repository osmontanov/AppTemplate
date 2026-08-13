nonisolated enum CartRepositoryError: Error, Equatable, Sendable {
    case invalidQuantity
    case emptyCart
    case revisionConflict(expected: Int64, actual: Int64)
}
