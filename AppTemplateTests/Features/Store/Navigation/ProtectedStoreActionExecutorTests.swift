import Testing
@testable import AppTemplate

@MainActor
struct ProtectedStoreActionExecutorTests {
    @Test
    func pendingFavoriteFetchesProductAndEnsuresIdempotentlyForExpectedUser() async {
        let session = ExecutorSessionSpy(state: authenticatedState(userID: 7))
        let products = ExecutorProductRepository(product: .fixture(id: 3))
        let favorites = ExecutorFavoritesRepository()
        let executor = makeExecutor(products: products, favorites: favorites, session: session)

        await executor.execute(.favorite(3), expectedUserID: 7)

        #expect(await products.requestedIDs == [3])
        #expect(await favorites.containsCalls.isEmpty)
        #expect(await favorites.ensureCalls.map(\.userID) == [7])
        #expect(await favorites.ensureCalls.map(\.product.id) == [3])
        #expect(await favorites.toggleCalls == 0)
    }

    @Test
    func authenticatedHeartReadsContainsThenRemovesOrEnsures() async {
        let state = authenticatedState(userID: 4)
        let session = ExecutorSessionSpy(state: state)
        let contained = ExecutorFavoritesRepository(containsResults: [.success(true)])
        let missing = ExecutorFavoritesRepository(containsResults: [.success(false)])
        let product = Product.fixture(id: 8)

        await makeExecutor(favorites: contained, session: session).activateHeart(for: product, session: state)
        await makeExecutor(favorites: missing, session: session).activateHeart(for: product, session: state)

        #expect(await contained.containsCalls.map(\.userID) == [4])
        #expect(await contained.containsCalls.map(\.productID) == [8])
        #expect(await contained.removeCalls.map(\.userID) == [4])
        #expect(await contained.removeCalls.map(\.productID) == [8])
        #expect(await contained.ensureCalls.isEmpty)
        #expect(await missing.ensureCalls.map(\.userID) == [4])
        #expect(await missing.ensureCalls.map(\.product.id) == [8])
    }

    @Test
    func guestHeartQueuesEnsureAndUnavailableHeartPresentsExactRecovery() async {
        let router = StoreRouter()
        let session = ExecutorSessionSpy(state: .guest)
        let favorites = ExecutorFavoritesRepository()
        let executor = makeExecutor(router: router, favorites: favorites, session: session)

        await executor.activateHeart(for: .fixture(id: 6), session: .guest)
        #expect(router.pendingProtectedAction == .favorite(6))
        #expect(router.presentation == .authentication)
        #expect(await favorites.ensureCalls.isEmpty)

        let unavailable = SessionState.unavailable(.secureStorageCleanupFailed)
        session.publish(unavailable, revision: 2)
        executor.sessionDidChange(session.presentation)
        await executor.activateHeart(for: .fixture(id: 7), session: unavailable)
        #expect(router.presentation == .sessionRecovery(.secureStorageCleanupFailed))
        #expect(router.pendingProtectedAction == nil)
    }

    @Test(arguments: [
        (ExecutorFailurePoint.product, ProtectedStoreActionExecutionError.productLoadFailed),
        (.contains, .favoriteReadFailed),
        (.write, .favoriteWriteFailed)
    ])
    func mapsRepositoryFailuresWithoutFalseNavigation(
        point: ExecutorFailurePoint,
        expected: ProtectedStoreActionExecutionError
    ) async {
        let state = authenticatedState(userID: 1)
        let session = ExecutorSessionSpy(state: state)
        let products = ExecutorProductRepository(product: .fixture(id: 2), error: point == .product ? ExecutorTestError.injected : nil)
        let favorites = ExecutorFavoritesRepository(
            containsResults: point == .contains ? [.failure(ExecutorTestError.injected)] : [.success(false)],
            ensureResults: point == .write ? [.failure(ExecutorTestError.injected)] : []
        )
        let router = StoreRouter(path: [.product(2)])
        let executor = makeExecutor(router: router, products: products, favorites: favorites, session: session)

        if point == .product {
            await executor.execute(.favorite(2), expectedUserID: 1)
        } else {
            await executor.activateHeart(for: .fixture(id: 2), session: state)
        }

        #expect(executor.error == expected)
        #expect(router.path == [.product(2)])
    }

    @Test
    func sameUserAvailabilityRevisionPreservesSuspendedFavorite() async {
        let state = authenticatedState(userID: 1, availability: .validating)
        let session = ExecutorSessionSpy(state: state)
        let containsGate = ExecutorBoolGate()
        let favorites = ExecutorFavoritesRepository(containsGate: containsGate)
        let executor = makeExecutor(favorites: favorites, session: session)
        executor.sessionDidChange(session.presentation)

        let task = Task { await executor.activateHeart(for: .fixture(id: 5), session: state) }
        await containsGate.waitUntilEntered()
        session.publish(authenticatedState(userID: 1, availability: .offline(.transport)), revision: 2)
        executor.sessionDidChange(session.presentation)
        await containsGate.resolve(.success(false))
        await task.value

        #expect(await favorites.ensureCalls.map(\.userID) == [1])
        #expect(await favorites.ensureCalls.map(\.product.id) == [5])
    }

    @Test
    func sameUserAvailabilityRevisionPreservesSuspendedProductFetch() async {
        let state = authenticatedState(userID: 1, availability: .validating)
        let session = ExecutorSessionSpy(state: state)
        let productGate = ExecutorProductGate()
        let products = ExecutorProductRepository(product: .fixture(id: 5), gate: productGate)
        let favorites = ExecutorFavoritesRepository()
        let executor = makeExecutor(products: products, favorites: favorites, session: session)
        executor.sessionDidChange(session.presentation)

        let task = Task { await executor.execute(.favorite(5), expectedUserID: 1) }
        await productGate.waitUntilEntered()
        session.publish(authenticatedState(userID: 1, availability: .offline(.transport)), revision: 2)
        executor.sessionDidChange(session.presentation)
        await productGate.resolve(.fixture(id: 5))
        await task.value

        #expect(await favorites.ensureCalls.map(\.userID) == [1])
        #expect(await favorites.ensureCalls.map(\.product.id) == [5])
    }

    @Test(arguments: [
        SessionState.guest,
        .unavailable(.secureStorageReadFailed),
        authenticatedState(userID: 2)
    ])
    func identityInvalidationSuppressesSuspendedWrite(newState: SessionState) async {
        let state = authenticatedState(userID: 1)
        let session = ExecutorSessionSpy(state: state)
        let containsGate = ExecutorBoolGate()
        let favorites = ExecutorFavoritesRepository(containsGate: containsGate)
        let executor = makeExecutor(favorites: favorites, session: session)
        executor.sessionDidChange(session.presentation)

        let task = Task { await executor.activateHeart(for: .fixture(id: 5), session: state) }
        await containsGate.waitUntilEntered()
        session.publish(newState, revision: 2)
        executor.sessionDidChange(session.presentation)
        await containsGate.resolve(.success(false))
        await task.value

        #expect(await favorites.ensureCalls.isEmpty)
        #expect(executor.error == nil)
    }

    @Test
    func differentUserSuppressesSuspendedProductFetchBeforeWrite() async {
        let state = authenticatedState(userID: 1)
        let session = ExecutorSessionSpy(state: state)
        let productGate = ExecutorProductGate()
        let products = ExecutorProductRepository(product: .fixture(id: 5), gate: productGate)
        let favorites = ExecutorFavoritesRepository()
        let executor = makeExecutor(products: products, favorites: favorites, session: session)
        executor.sessionDidChange(session.presentation)

        let task = Task { await executor.execute(.favorite(5), expectedUserID: 1) }
        await productGate.waitUntilEntered()
        session.publish(authenticatedState(userID: 2), revision: 2)
        executor.sessionDidChange(session.presentation)
        await productGate.resolve(.fixture(id: 5))
        await task.value

        #expect(await favorites.ensureCalls.isEmpty)
        #expect(executor.error == nil)
    }

    @Test
    func navigationActionsRecheckExpectedUserImmediatelyBeforeEffect() async {
        let session = ExecutorSessionSpy(state: authenticatedState(userID: 1))
        let router = StoreRouter(path: [.product(3)])
        let executor = makeExecutor(router: router, session: session)

        await executor.execute(.openFavorites, expectedUserID: 2)
        await executor.execute(.openAccount, expectedUserID: 2)

        #expect(router.path == [.product(3)])
        #expect(router.profileSection == .overview)
    }

    private func makeExecutor(
        router: StoreRouter = StoreRouter(),
        products: ExecutorProductRepository = ExecutorProductRepository(product: .fixture()),
        favorites: ExecutorFavoritesRepository = ExecutorFavoritesRepository(),
        session: ExecutorSessionSpy
    ) -> ProtectedStoreActionExecutor {
        ProtectedStoreActionExecutor(router: router, products: products, favorites: favorites, session: session)
    }
}

nonisolated enum ExecutorFailurePoint: Sendable { case product, contains, write }
private enum ExecutorTestError: Error { case injected }

@MainActor
private final class ExecutorSessionSpy: ISessionActions {
    private(set) var status: SessionStatusPresentation
    var presentation: SessionPresentation { status.session }

    init(state: SessionState) {
        status = SessionStatusPresentation(session: SessionPresentation(state: state, revision: 1), expiry: nil)
    }

    func publish(_ state: SessionState, revision: UInt64) {
        status = SessionStatusPresentation(session: SessionPresentation(state: state, revision: revision), expiry: nil)
    }

    func bootstrap() async {}
    func retryBootstrap() async {}
    func login(username: String, password: String) async -> SessionLoginResult { .cancelled }
    func retryPersistence(_ token: SessionPersistenceRetryToken) async -> SessionPersistenceRetryResult { .cancelled }
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async {}
    func validateSession() async -> SessionValidationResult { .unchanged }
    func refreshSession() async -> SessionValidationResult { .unchanged }
    func signOut() async -> SessionSignOutResult { .cancelled }
}

private actor ExecutorProductRepository: IProductRepository {
    private let value: Product
    private let error: Error?
    private let gate: ExecutorProductGate?
    private(set) var requestedIDs: [Int] = []

    init(
        product: Product,
        error: Error? = nil,
        gate: ExecutorProductGate? = nil
    ) {
        value = product
        self.error = error
        self.gate = gate
    }
    func categories() async throws -> [ProductCategory] { [] }
    func page(_ query: ProductQuery) async throws -> ProductPage { ProductPage(products: [], total: 0, skip: 0, limit: 1) }
    func product(id: Product.ID) async throws -> Product {
        requestedIDs.append(id)
        if let error { throw error }
        if let gate { return await gate.wait() }
        return value
    }
    func related(to product: Product, limit: Int) async throws -> [Product] { [] }
}

private actor ExecutorProductGate {
    private var entered = false
    private var product: Product?
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var productWaiters: [CheckedContinuation<Product, Never>] = []

    func wait() async -> Product {
        entered = true
        entryWaiters.forEach { $0.resume() }
        entryWaiters.removeAll()
        if let product { return product }
        return await withCheckedContinuation { productWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func resolve(_ value: Product) {
        product = value
        productWaiters.forEach { $0.resume(returning: value) }
        productWaiters.removeAll()
    }
}

private actor ExecutorFavoritesRepository: IFavoritesRepository {
    private(set) var containsCalls: [(userID: Int, productID: Int)] = []
    private(set) var ensureCalls: [(product: ProductSnapshot, userID: Int)] = []
    private(set) var removeCalls: [(userID: Int, productID: Int)] = []
    private(set) var toggleCalls = 0
    private var containsResults: [Result<Bool, Error>]
    private var ensureResults: [Result<Bool, Error>]
    private let containsGate: ExecutorBoolGate?

    init(
        containsResults: [Result<Bool, Error>] = [],
        ensureResults: [Result<Bool, Error>] = [],
        containsGate: ExecutorBoolGate? = nil
    ) {
        self.containsResults = containsResults
        self.ensureResults = ensureResults
        self.containsGate = containsGate
    }

    func favorites(userID: Int) async throws -> [FavoriteProductSnapshot] { [] }
    func contains(userID: Int, productID: Int) async throws -> Bool {
        containsCalls.append((userID, productID))
        if let containsGate { return try await containsGate.wait().get() }
        return try (containsResults.isEmpty ? .success(false) : containsResults.removeFirst()).get()
    }
    func ensureFavorite(_ product: ProductSnapshot, userID: Int) async throws -> Bool {
        ensureCalls.append((product, userID))
        return try (ensureResults.isEmpty ? .success(true) : ensureResults.removeFirst()).get()
    }
    func removeFavorite(userID: Int, productID: Int) async throws -> Bool { removeCalls.append((userID, productID)); return true }
    func toggle(_ product: ProductSnapshot, userID: Int) async throws -> Bool { toggleCalls += 1; return true }
}

private actor ExecutorBoolGate {
    private var entered = false
    private var result: Result<Bool, Error>?
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var resultWaiters: [CheckedContinuation<Result<Bool, Error>, Never>] = []
    func wait() async -> Result<Bool, Error> {
        entered = true
        entryWaiters.forEach { $0.resume() }; entryWaiters.removeAll()
        if let result { return result }
        return await withCheckedContinuation { resultWaiters.append($0) }
    }
    func waitUntilEntered() async { if !entered { await withCheckedContinuation { entryWaiters.append($0) } } }
    func resolve(_ value: Result<Bool, Error>) { result = value; resultWaiters.forEach { $0.resume(returning: value) }; resultWaiters.removeAll() }
}

nonisolated private func authenticatedState(
    userID: Int,
    availability: SessionAvailability = .online
) -> SessionState {
    .authenticated(
        UserProfile(id: userID, username: "user\(userID)", firstName: "User", lastName: "\(userID)", imageURL: nil),
        availability: availability
    )
}
