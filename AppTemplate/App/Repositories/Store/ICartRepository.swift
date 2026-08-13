nonisolated protocol ICartRepository: Sendable {
    func cart() async throws -> CartAggregate
    func add(_ product: ProductSnapshot, quantity: Int) async throws -> CartAggregate
    func setQuantity(productID: Int, quantity: Int) async throws -> CartAggregate
    func remove(productID: Int) async throws -> CartAggregate
    func checkout(expectedRevision: Int64) async throws
}
