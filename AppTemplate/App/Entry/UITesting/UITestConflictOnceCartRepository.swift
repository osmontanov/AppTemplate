actor UITestConflictOnceCartRepository: ICartRepository {
    private let base: any ICartRepository
    private var shouldConflict = true

    init(base: any ICartRepository) {
        self.base = base
    }

    func cart() async throws -> CartAggregate {
        try await base.cart()
    }

    func add(_ product: ProductSnapshot, quantity: Int) async throws -> CartAggregate {
        try await base.add(product, quantity: quantity)
    }

    func setQuantity(productID: Int, quantity: Int) async throws -> CartAggregate {
        try await base.setQuantity(productID: productID, quantity: quantity)
    }

    func remove(productID: Int) async throws -> CartAggregate {
        try await base.remove(productID: productID)
    }

    func checkout(expectedRevision: Int64) async throws {
        if shouldConflict {
            shouldConflict = false
            let current = try await base.cart()
            guard let line = current.lines.first else {
                try await base.checkout(expectedRevision: expectedRevision)
                return
            }
            let increment = line.quantity.addingReportingOverflow(1)
            guard !increment.overflow else {
                throw CartRepositoryError.invalidQuantity
            }
            let updated = try await base.setQuantity(
                productID: line.product.id,
                quantity: increment.partialValue
            )
            throw CartRepositoryError.revisionConflict(
                expected: expectedRevision,
                actual: updated.revision
            )
        }
        try await base.checkout(expectedRevision: expectedRevision)
    }
}
