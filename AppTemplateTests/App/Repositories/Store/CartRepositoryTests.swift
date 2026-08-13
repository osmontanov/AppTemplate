import Foundation
import Testing
@testable import AppTemplate

struct CartRepositoryTests {
    @Test
    func missingCartStartsAtRevisionZeroAndNoOpsDoNotPersist() async throws {
        let database = RecordingCartDatabase()
        let repository = CartRepository(database: database)

        #expect(try await repository.cart() == CartAggregate(id: "Store.Cart", revision: 0, lines: []))
        #expect(try await repository.setQuantity(productID: 1, quantity: 2).revision == 0)
        #expect(try await repository.remove(productID: 1).revision == 0)
        #expect(await database.upsertCount == 0)
    }

    @Test
    func cartReadSortsPersistedLinesWithoutWriting() async throws {
        let database = RecordingCartDatabase()
        await database.seed(
            CartAggregate(
                id: "Store.Cart",
                revision: 4,
                lines: [
                    CartLine(product: cartProduct(9), quantity: 1),
                    CartLine(product: cartProduct(2), quantity: 1)
                ]
            )
        )
        let repository = CartRepository(database: database)

        #expect(try await repository.cart().lines.map(\.product.id) == [2, 9])
        #expect(await database.upsertCount == 0)
    }

    @Test
    func addSetAndRemoveSortLinesAndIncrementOncePerMutation() async throws {
        let database = makeCartDatabase()
        let repository = CartRepository(database: database)

        let first = try await repository.add(cartProduct(9), quantity: 1)
        let second = try await repository.add(cartProduct(2), quantity: 2)
        let third = try await repository.add(cartProduct(9), quantity: 3)
        let fourth = try await repository.setQuantity(productID: 2, quantity: 7)
        let fifth = try await repository.remove(productID: 9)

        #expect(first.revision == 1)
        #expect(second.lines.map(\.product.id) == [2, 9])
        #expect(third.lines.map(\.quantity) == [2, 4])
        #expect(fourth.lines.map(\.quantity) == [7, 4])
        #expect(fifth.revision == 5)
        #expect(fifth.lines.map(\.product.id) == [2])
        #expect(try await repository.cart() == fifth)
    }

    @Test
    func concurrentAddsRemainAtomicSortedAndPersistEveryReturnedRevision() async throws {
        let database = makeCartDatabase()
        let repository = CartRepository(database: database)

        let recorder = CartAggregateRecorder()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for id in [8, 1, 5, 1, 3, 8] {
                group.addTask {
                    await recorder.record(
                        try await repository.add(cartProduct(id), quantity: 1)
                    )
                }
            }
            try await group.waitForAll()
        }
        let results = await recorder.values
        let persisted = try await repository.cart()

        #expect(Set(results.map(\.revision)) == Set((1...6).map(Int64.init)))
        #expect(persisted.revision == 6)
        #expect(persisted.lines.map(\.product.id) == [1, 3, 5, 8])
        #expect(persisted.lines.map(\.quantity) == [2, 1, 1, 2])
        #expect(results.allSatisfy { $0.lines.map(\.product.id) == $0.lines.map(\.product.id).sorted() })
    }

    @Test
    func checkoutRejectsEmptyAndStaleThenPersistsEmptyRevisionAndContinues() async throws {
        let database = makeCartDatabase()
        let repository = CartRepository(database: database)

        await #expect(throws: CartRepositoryError.emptyCart) {
            try await repository.checkout(expectedRevision: 0)
        }
        #expect(try await repository.cart().revision == 0)
        let first = try await repository.add(cartProduct(1), quantity: 1)
        let second = try await repository.add(cartProduct(2), quantity: 1)
        await #expect(throws: CartRepositoryError.revisionConflict(expected: first.revision, actual: second.revision)) {
            try await repository.checkout(expectedRevision: first.revision)
        }
        try await repository.checkout(expectedRevision: second.revision)
        #expect(try await repository.cart() == CartAggregate(id: "Store.Cart", revision: 3, lines: []))
        #expect(try await repository.add(cartProduct(4), quantity: 1).revision == 4)
    }

    @Test
    func invalidQuantityAndArithmeticOverflowNeverWrite() async throws {
        let database = RecordingCartDatabase()
        let repository = CartRepository(database: database)

        await #expect(throws: CartRepositoryError.invalidQuantity) {
            try await repository.add(cartProduct(1), quantity: 0)
        }
        await #expect(throws: CartRepositoryError.invalidQuantity) {
            try await repository.setQuantity(productID: 1, quantity: -1)
        }
        await database.seed(CartAggregate(id: "Store.Cart", revision: .max, lines: [CartLine(product: cartProduct(1), quantity: 1)]))
        await #expect(throws: CartRepositoryInternalError.arithmeticOverflow) {
            try await repository.remove(productID: 1)
        }
        #expect(await database.upsertCount == 0)
    }

    @Test
    func addValidatesTheSuppliedSnapshotEvenWhenItsProductAlreadyExists() async throws {
        let repository = CartRepository(database: makeCartDatabase())
        _ = try await repository.add(cartProduct(1), quantity: 1)
        let invalid = ProductSnapshot(
            id: 1,
            title: "Invalid",
            price: -1,
            thumbnailURL: nil
        )

        await #expect(throws: StoreModelValidationError.invalidPrice) {
            try await repository.add(invalid, quantity: 1)
        }
        #expect(try await repository.cart().lines.first?.quantity == 1)
    }

    @Test
    func secondCommandCannotReadUntilFirstPersistsAndReleasesGate() async throws {
        let database = RecordingCartDatabase(pauseFirstFetch: true)
        let repository = CartRepository(database: database)
        let first = Task { try await repository.add(cartProduct(2), quantity: 1) }
        await database.waitUntilFetchCount(1)
        let second = Task { try await repository.add(cartProduct(1), quantity: 1) }
        await repository.waitUntilQueuedCommandCountForTesting(1)

        #expect(await database.fetchCount == 1)
        await database.releaseFirstFetch()
        _ = try await first.value
        _ = try await second.value
        #expect(await database.fetchCount == 2)
        #expect(await database.upsertCount == 2)
    }

    @Test
    func databaseFailureAndCancellationReleaseGateAndPreservePersistedState() async throws {
        let database = RecordingCartDatabase()
        let repository = CartRepository(database: database)
        await database.failNextUpsert()
        await #expect(throws: CartDatabaseTestError.failed) {
            try await repository.add(cartProduct(1), quantity: 1)
        }
        #expect(try await repository.add(cartProduct(2), quantity: 1).revision == 1)

        await database.pauseNextFetch()
        let cancelled = Task { try await repository.add(cartProduct(3), quantity: 1) }
        await database.waitUntilFetchCount(3)
        cancelled.cancel()
        await database.releaseFirstFetch()
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(try await repository.add(cartProduct(4), quantity: 1).revision == 2)
    }
}

private enum CartDatabaseTestError: Error { case failed }

private actor CartAggregateRecorder {
    private(set) var values: [CartAggregate] = []
    func record(_ value: CartAggregate) { values.append(value) }
}

private func makeCartDatabase() -> any ILocalDatabaseService {
    LocalDatabaseService(configuration: .inMemory())
}

private func cartProduct(_ id: Int) -> ProductSnapshot {
    ProductSnapshot(
        id: id,
        title: "Product \(id)",
        price: 1,
        thumbnailURL: nil
    )
}

private actor RecordingCartDatabase: ILocalDatabaseService {
    private var stored: CartAggregate?
    private(set) var fetchCount = 0
    private(set) var upsertCount = 0
    private var shouldPause: Bool
    private var pauseContinuation: CheckedContinuation<Void, Never>?
    private var fetchWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var shouldFailUpsert = false

    init(pauseFirstFetch: Bool = false) { shouldPause = pauseFirstFetch }
    func seed(_ value: CartAggregate) { stored = value }
    func failNextUpsert() { shouldFailUpsert = true }
    func pauseNextFetch() { shouldPause = true }

    func waitUntilFetchCount(_ expected: Int) async {
        guard fetchCount < expected else { return }
        await withCheckedContinuation { fetchWaiters.append((expected, $0)) }
    }

    func releaseFirstFetch() {
        let continuation = pauseContinuation
        pauseContinuation = nil
        continuation?.resume()
    }

    func fetch<Model: LocalDatabaseModel>(_ type: Model.Type, id: Model.ID) async throws -> Model? {
        guard Model.self == CartAggregate.self else { return nil }
        fetchCount += 1
        let ready = fetchWaiters.filter { $0.0 <= fetchCount }
        fetchWaiters.removeAll { $0.0 <= fetchCount }
        for waiter in ready { waiter.1.resume() }
        if shouldPause {
            shouldPause = false
            await withCheckedContinuation { pauseContinuation = $0 }
            try Task.checkCancellation()
        }
        return stored as? Model
    }

    func fetch<Model: LocalDatabaseModel>(_ type: Model.Type, matching query: Model.Query) async throws -> [Model] { [] }
    func upsert<Model: LocalDatabaseModel>(_ value: Model) async throws {
        guard let value = value as? CartAggregate else { return }
        if shouldFailUpsert { shouldFailUpsert = false; throw CartDatabaseTestError.failed }
        stored = value
        upsertCount += 1
    }
    func upsert<Model: LocalDatabaseModel>(_ values: [Model]) async throws {}
    func delete<Model: LocalDatabaseModel>(_ type: Model.Type, id: Model.ID) async throws -> Bool { false }
    func deleteAll<Model: LocalDatabaseModel>(_ type: Model.Type) async throws -> Int { 0 }
}
