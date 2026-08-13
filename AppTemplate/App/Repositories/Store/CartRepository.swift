nonisolated enum CartRepositoryInternalError: Error, Equatable, Sendable {
    case arithmeticOverflow
}

actor CartRepository: ICartRepository {
    private let database: any ILocalDatabaseService
    private let gate = AsyncOperationGate()

    init(database: any ILocalDatabaseService) {
        self.database = database
    }

    func cart() async throws -> CartAggregate {
        try await Self.current(database: database)
    }

    func add(_ product: ProductSnapshot, quantity: Int) async throws -> CartAggregate {
        guard quantity > 0 else { throw CartRepositoryError.invalidQuantity }
        try Self.validate(product: product, quantity: quantity)
        let database = database
        return try await gate.withExclusiveAccess {
            var current = try await Self.current(database: database)
            if let index = current.lines.firstIndex(where: { $0.product.id == product.id }) {
                let total = current.lines[index].quantity.addingReportingOverflow(quantity)
                guard !total.overflow else { throw CartRepositoryInternalError.arithmeticOverflow }
                current.lines[index].quantity = total.partialValue
            } else {
                current.lines.append(CartLine(product: product, quantity: quantity))
            }
            return try await Self.persistMutation(current, database: database)
        }
    }

    func setQuantity(productID: Int, quantity: Int) async throws -> CartAggregate {
        guard quantity > 0 else { throw CartRepositoryError.invalidQuantity }
        let database = database
        return try await gate.withExclusiveAccess {
            var current = try await Self.current(database: database)
            guard let index = current.lines.firstIndex(where: { $0.product.id == productID }) else {
                return current
            }
            guard current.lines[index].quantity != quantity else { return current }
            current.lines[index].quantity = quantity
            return try await Self.persistMutation(current, database: database)
        }
    }

    func remove(productID: Int) async throws -> CartAggregate {
        let database = database
        return try await gate.withExclusiveAccess {
            var current = try await Self.current(database: database)
            guard let index = current.lines.firstIndex(where: { $0.product.id == productID }) else {
                return current
            }
            current.lines.remove(at: index)
            return try await Self.persistMutation(current, database: database)
        }
    }

    func checkout(expectedRevision: Int64) async throws {
        let database = database
        try await gate.withExclusiveAccess {
            var current = try await Self.current(database: database)
            guard current.revision == expectedRevision else {
                throw CartRepositoryError.revisionConflict(
                    expected: expectedRevision,
                    actual: current.revision
                )
            }
            guard !current.lines.isEmpty else { throw CartRepositoryError.emptyCart }
            current.lines = []
            _ = try await Self.persistMutation(current, database: database)
        }
    }

    func waitUntilQueuedCommandCountForTesting(_ expectedCount: Int) async {
        await gate.waitUntilWaiterCountForTesting(expectedCount)
    }

    private nonisolated static func current(
        database: any ILocalDatabaseService
    ) async throws -> CartAggregate {
        guard let stored = try await database.fetch(
            CartAggregate.self,
            id: CartAggregate.singletonID
        ) else {
            return CartAggregate(
                id: CartAggregate.singletonID,
                revision: 0,
                lines: []
            )
        }
        return CartAggregate(
            id: stored.id,
            revision: stored.revision,
            lines: stored.lines.sorted { $0.product.id < $1.product.id }
        )
    }

    private nonisolated static func persistMutation(
        _ current: CartAggregate,
        database: any ILocalDatabaseService
    ) async throws -> CartAggregate {
        let increment = current.revision.addingReportingOverflow(1)
        guard !increment.overflow else { throw CartRepositoryInternalError.arithmeticOverflow }
        let updated = CartAggregate(
            id: CartAggregate.singletonID,
            revision: increment.partialValue,
            lines: current.lines.sorted { $0.product.id < $1.product.id }
        )
        try await database.upsert(updated)
        return updated
    }

    private nonisolated static func validate(
        product: ProductSnapshot,
        quantity: Int
    ) throws {
        try CartAggregateAdapter.validate(
            value: CartAggregate(
                id: CartAggregate.singletonID,
                revision: 0,
                lines: [CartLine(product: product, quantity: quantity)]
            )
        )
    }
}
