import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct CatalogViewModelTests {
    @Test
    func initialLoadUsesPreferencesAndDeduplicatesPageIDs() async {
        let repository = ControlledProductRepository(pages: [
            ProductPage(products: [.fixture(id: 2), .fixture(id: 1), .fixture(id: 2)], total: 3, skip: 0, limit: 20)
        ])
        let preferences = ControlledStorePreferencesRepository(StorePreferences(layout: .list, sort: .priceAscending, preferredRemotePageSize: 20))
        let viewModel = CatalogViewModel(products: repository, preferences: preferences, clock: .immediate)

        await viewModel.loadInitial()

        #expect(viewModel.model.products.map(\.id) == [2, 1])
        #expect(viewModel.model.preferences.layout == .list)
        #expect(await repository.recordedQueries() == [ProductQuery(mode: .all, sort: .priceAscending, limit: 20, skip: 0)])
    }

    @Test
    func catalogReappearanceDoesNotRepeatTheInitialOrBlankSearchPage() async {
        let repository = ControlledProductRepository(pages: [
            ProductPage(products: [.fixture(id: 1)], total: 1, skip: 0, limit: 20)
        ])
        let preferences = ControlledStorePreferencesRepository()
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: preferences,
            clock: .immediate
        )

        await viewModel.loadInitial()
        await viewModel.loadInitial()
        await viewModel.search("")

        #expect(await repository.recordedQueries() == [
            ProductQuery(mode: .all, sort: nil, limit: 20, skip: 0)
        ])
    }

    @Test
    func concurrentRehostedInitialLoadAwaitsTheSingleInFlightPage() async {
        let repository = DeferredPageRepository()
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: ControlledStorePreferencesRepository(),
            clock: .immediate
        )
        let first = Task { await viewModel.loadInitial() }
        await repository.waitForRequestCount(1)
        let rehosted = Task { await viewModel.loadInitial() }
        await Task.yield()

        await repository.resume(index: 0, productID: 1)

        #expect(await first.value)
        #expect(await rehosted.value)
        #expect(await repository.recordedQueries().count == 1)
    }

    @Test
    func mappedCancellationStopsInitialLoadBeforeThePageRequest() async {
        let repository = CancelledCategoriesProductRepository()
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: ControlledStorePreferencesRepository(),
            clock: .immediate
        )

        let completed = await viewModel.loadInitial()

        #expect(!completed)
        #expect(await repository.recordedQueries().isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func cancellingInitialLoadOwnerCancelsSharedWorkAndAllowsRetry() async {
        let repository = CancellableInitialLoadProductRepository()
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: ControlledStorePreferencesRepository(),
            clock: .immediate
        )
        let owner = Task { await viewModel.loadInitial() }
        await repository.waitForFirstCategoriesRequest()

        owner.cancel()
        try? await Task.sleep(for: .milliseconds(50))
        let cancellationCount = await repository.categoryCancellationCount
        if cancellationCount == 0 {
            await repository.finishFirstCategoriesRequest()
        }

        let ownerCompleted = await owner.value
        #expect(!ownerCompleted)
        #expect(cancellationCount == 1)
        #expect(await viewModel.loadInitial())
        #expect(await repository.categoryRequestCount == 2)
        #expect(await repository.recordedQueries().count == 1)
    }

    @Test
    func rehostedInitialLoadRetriesAfterTheOriginalOwnerIsCancelled() async {
        let repository = CancellableInitialLoadProductRepository()
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: ControlledStorePreferencesRepository(),
            clock: .immediate
        )
        let originalOwner = Task { await viewModel.loadInitial() }
        await repository.waitForFirstCategoriesRequest()
        let rehostedOwner = Task { await viewModel.loadInitial() }
        await Task.yield()

        originalOwner.cancel()

        let originalCompleted = await originalOwner.value
        #expect(!originalCompleted)
        #expect(await rehostedOwner.value)
        #expect(await repository.categoryRequestCount == 2)
        #expect(await repository.recordedQueries().count == 1)
    }

    @Test
    func cancellingARehostedJoinerDoesNotCancelTheActiveInitialLoadOwner() async {
        let repository = CancellableInitialLoadProductRepository()
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: ControlledStorePreferencesRepository(),
            clock: .immediate
        )
        let owner = Task { await viewModel.loadInitial() }
        await repository.waitForFirstCategoriesRequest()
        let rehostedJoiner = Task { await viewModel.loadInitial() }
        await Task.yield()

        rehostedJoiner.cancel()
        try? await Task.sleep(for: .milliseconds(50))
        let cancellationCount = await repository.categoryCancellationCount
        if cancellationCount == 0 {
            await repository.succeedFirstCategoriesRequest()
        }

        _ = await rehostedJoiner.value
        #expect(await owner.value)
        #expect(cancellationCount == 0)
        #expect(await repository.categoryRequestCount == 1)
        #expect(await repository.recordedQueries().count == 1)
    }

    @Test
    func sceneOwnedQueryControlsSurviveCatalogViewRehosting() async {
        let repository = ControlledProductRepository(pages: [
            ProductPage(products: [.fixture(id: 1)], total: 1, skip: 0, limit: 20),
            ProductPage(products: [.fixture(id: 2)], total: 1, skip: 0, limit: 20)
        ])
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: ControlledStorePreferencesRepository(),
            clock: .immediate
        )

        viewModel.searchText = "phone"
        await viewModel.search(viewModel.searchText)
        #expect(viewModel.searchText == "phone")
        #expect(viewModel.model.mode == .search("phone"))

        viewModel.searchText = ""
        viewModel.selectedCategory = "smartphones"
        await viewModel.selectCategory(viewModel.selectedCategory)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedCategory == "smartphones")
        #expect(viewModel.model.mode == .category("smartphones"))
    }

    @Test
    func rehostingAPersistedSearchDoesNotRepeatItsLoadedQuery() async {
        let repository = ControlledProductRepository(pages: [
            ProductPage(products: [.fixture(id: 1)], total: 1, skip: 0, limit: 20),
            ProductPage(products: [.fixture(id: 2)], total: 1, skip: 0, limit: 20),
            ProductPage(products: [.fixture(id: 3)], total: 1, skip: 0, limit: 20)
        ])
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: ControlledStorePreferencesRepository(),
            clock: .immediate
        )

        await viewModel.loadInitial()
        viewModel.searchText = "phone"
        await viewModel.search(viewModel.searchText)

        #expect(await viewModel.loadInitial())
        await viewModel.search(viewModel.searchText)

        #expect(await repository.recordedQueries() == [
            ProductQuery(mode: .all, sort: nil, limit: 20, skip: 0),
            ProductQuery(mode: .search("phone"), sort: nil, limit: 20, skip: 0)
        ])
    }

    @Test
    func searchEnteredDuringInitialLoadRunsExactlyOnceAfterInitialReadiness() async {
        let repository = DeferredPageRepository()
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: ControlledStorePreferencesRepository(),
            clock: .immediate
        )
        let initialLoad = Task { await viewModel.loadInitial() }
        await repository.waitForRequestCount(1)

        viewModel.searchText = "phone"
        await repository.resume(index: 0, productID: 1)
        for _ in 0..<1_000 {
            if await repository.recordedQueries().count == 2 { break }
            await Task.yield()
        }
        let queries = await repository.recordedQueries()
        guard queries.count == 2 else {
            Issue.record("Expected the in-flight initial load to reconcile the entered search after becoming ready")
            #expect(await initialLoad.value)
            return
        }

        await repository.resume(index: 1, productID: 2)

        #expect(await initialLoad.value)
        #expect(await repository.recordedQueries() == [
            ProductQuery(mode: .all, sort: nil, limit: 20, skip: 0),
            ProductQuery(mode: .search("phone"), sort: nil, limit: 20, skip: 0)
        ])
        await viewModel.search(viewModel.searchText)
        #expect(await repository.recordedQueries().count == 2)
    }

    @Test
    func newerSearchEnteredDuringInitialReconciliationEventuallyWins() async {
        let repository = DeferredPageRepository()
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: ControlledStorePreferencesRepository(),
            clock: .immediate
        )
        let initialLoad = Task { await viewModel.loadInitial() }
        await repository.waitForRequestCount(1)

        viewModel.searchText = "old"
        await repository.resume(index: 0, productID: 1)
        await repository.waitForRequestCount(2)
        viewModel.searchText = "new"
        await repository.resume(index: 1, productID: 2)
        for _ in 0..<1_000 {
            if await repository.recordedQueries().count == 3 { break }
            await Task.yield()
        }
        let queries = await repository.recordedQueries()
        guard queries.count == 3 else {
            Issue.record("Expected initial reconciliation to follow the latest visible search")
            #expect(await initialLoad.value)
            return
        }

        await repository.resume(index: 2, productID: 3)

        #expect(await initialLoad.value)
        #expect(viewModel.model.mode == .search("new"))
        #expect(viewModel.model.products.map(\.id) == [3])
        #expect(await repository.recordedQueries().map(\.mode) == [
            .all,
            .search("old"),
            .search("new")
        ])
    }

    @Test
    func clearingSearchDuringInitialReconciliationRestoresTheLatestAllMode() async {
        let repository = DeferredPageRepository()
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: ControlledStorePreferencesRepository(),
            clock: .immediate
        )
        let initialLoad = Task { await viewModel.loadInitial() }
        await repository.waitForRequestCount(1)

        viewModel.searchText = "old"
        await repository.resume(index: 0, productID: 1)
        await repository.waitForRequestCount(2)
        viewModel.searchText = ""
        await repository.resume(index: 1, productID: 2)
        for _ in 0..<1_000 {
            if await repository.recordedQueries().count == 3 { break }
            await Task.yield()
        }
        let queries = await repository.recordedQueries()
        guard queries.count == 3 else {
            Issue.record("Expected clearing the visible search to reconcile back to all products")
            #expect(await initialLoad.value)
            return
        }

        await repository.resume(index: 2, productID: 3)

        #expect(await initialLoad.value)
        #expect(viewModel.model.mode == .all)
        #expect(viewModel.model.products.map(\.id) == [3])
        #expect(await repository.recordedQueries().map(\.mode) == [
            .all,
            .search("old"),
            .all
        ])
    }

    @Test
    func concurrentCategorySelectionCannotLeaveInitialReadinessPermanentlyFalse() async {
        let repository = DeferredPageRepository()
        let viewModel = CatalogViewModel(
            products: repository,
            preferences: ControlledStorePreferencesRepository(),
            clock: .immediate
        )
        let initialLoad = Task { await viewModel.loadInitial() }
        await repository.waitForRequestCount(1)

        viewModel.selectedCategory = "smartphones"
        let categoryLoad = Task { await viewModel.selectCategory(viewModel.selectedCategory) }
        await repository.waitForRequestCount(2)
        await repository.resume(index: 1, productID: 2)
        await categoryLoad.value
        await repository.resume(index: 0, productID: 1)

        #expect(await initialLoad.value)
        #expect(viewModel.isInitialLoadComplete)
        #expect(viewModel.model.mode == .category("smartphones"))
        #expect(viewModel.model.products.map(\.id) == [2])

        viewModel.searchText = "phone"
        let search = Task { await viewModel.search(viewModel.searchText) }
        await repository.waitForRequestCount(3)
        await repository.resume(index: 2, productID: 3)
        await search.value

        #expect(viewModel.model.mode == .search("phone"))
        #expect(viewModel.model.products.map(\.id) == [3])
    }

    @Test
    func searchCapsAtOneHundredUnicodeScalarsAndDisablesSorting() async {
        let repository = ControlledProductRepository(pages: [ProductPage(products: [], total: 0, skip: 0, limit: 20)])
        let preferences = ControlledStorePreferencesRepository(StorePreferences(layout: .grid, sort: .titleDescending, preferredRemotePageSize: 20))
        let viewModel = CatalogViewModel(products: repository, preferences: preferences, clock: .immediate)

        await viewModel.search(String(repeating: "😀", count: 120))

        let query = await repository.recordedQueries().first
        guard case let .search(text) = query?.mode else {
            Issue.record("Expected search mode")
            return
        }
        #expect(text.unicodeScalars.count == 100)
        #expect(query?.sort == nil)
        #expect(!viewModel.isSortingEnabled)
    }

    @Test
    func categoryAndSearchResetPagingWhileNextPageUsesLoadedCount() async {
        let repository = ControlledProductRepository(pages: [
            ProductPage(products: [.fixture(id: 1), .fixture(id: 2)], total: 5, skip: 0, limit: 10),
            ProductPage(products: [.fixture(id: 2), .fixture(id: 3)], total: 5, skip: 2, limit: 10),
            ProductPage(products: [.fixture(id: 4)], total: 1, skip: 0, limit: 10)
        ])
        let preferences = ControlledStorePreferencesRepository(StorePreferences(layout: .grid, sort: .featured, preferredRemotePageSize: 10))
        let viewModel = CatalogViewModel(products: repository, preferences: preferences, clock: .immediate)

        await viewModel.loadInitial()
        await viewModel.loadNextPage()
        await viewModel.selectCategory("phones")

        #expect(viewModel.model.products.map(\.id) == [4])
        #expect(await repository.recordedQueries().map(\.skip) == [0, 2, 0])
        #expect(await repository.recordedQueries().last?.sort == nil)
    }

    @Test
    func cancelledDebouncePublishesNoErrorAndMakesNoRequest() async {
        let repository = ControlledProductRepository()
        let preferences = ControlledStorePreferencesRepository()
        let viewModel = CatalogViewModel(products: repository, preferences: preferences, clock: .suspending)
        let task = Task { await viewModel.search("cancel me") }
        await Task.yield()

        task.cancel()
        await task.value

        #expect(await repository.recordedQueries().isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func searchRequestsExactlyThreeHundredMillisecondsOfDebounce() async {
        let repository = ControlledProductRepository(pages: [
            ProductPage(products: [], total: 0, skip: 0, limit: 20)
        ])
        let preferences = ControlledStorePreferencesRepository()
        let recorder = SleepDurationRecorder()
        let clock = AppClock(
            now: Date.init,
            monotonicNow: { ContinuousClock().now },
            sleep: { duration in
                await recorder.record(duration)
                try Task.checkCancellation()
            }
        )
        let viewModel = CatalogViewModel(products: repository, preferences: preferences, clock: clock)

        await viewModel.search("phone")

        #expect(await recorder.values == [.milliseconds(300)])
    }

    @Test
    func newerSearchWinsWhenOlderInitialPageReturnsLast() async {
        let repository = DeferredPageRepository()
        let preferences = ControlledStorePreferencesRepository()
        let viewModel = CatalogViewModel(products: repository, preferences: preferences, clock: .immediate)
        let initial = Task { await viewModel.loadInitial() }
        await repository.waitForRequestCount(1)
        let search = Task { await viewModel.search("new") }
        await repository.waitForRequestCount(2)

        await repository.resume(index: 1, productID: 2)
        await search.value
        await repository.resume(index: 0, productID: 1)
        _ = await initial.value

        #expect(viewModel.model.products.map(\.id) == [2])
    }
}

private extension AppClock {
    static let immediate = AppClock(now: Date.init, monotonicNow: { ContinuousClock().now }, sleep: { _ in try Task.checkCancellation() })
    static let suspending = AppClock(now: Date.init, monotonicNow: { ContinuousClock().now }, sleep: { _ in try await Task.sleep(for: .seconds(30)) })
}

private actor SleepDurationRecorder {
    private(set) var values: [Duration] = []
    func record(_ duration: Duration) { values.append(duration) }
}

private actor CancelledCategoriesProductRepository: IProductRepository {
    private var queries: [ProductQuery] = []

    func categories() async throws -> [ProductCategory] {
        throw RemoteServiceError.cancelled
    }

    func page(_ query: ProductQuery) async throws -> ProductPage {
        queries.append(query)
        return ProductPage(products: [], total: 0, skip: query.skip, limit: query.limit)
    }

    func product(id: Product.ID) async throws -> Product { .fixture(id: id) }
    func related(to product: Product, limit: Int) async throws -> [Product] { [] }
    func recordedQueries() -> [ProductQuery] { queries }
}

private actor CancellableInitialLoadProductRepository: IProductRepository {
    private var firstCategoriesContinuation: CheckedContinuation<[ProductCategory], Error>?
    private var firstCategoriesWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var categoryRequestCount = 0
    private(set) var categoryCancellationCount = 0
    private var queries: [ProductQuery] = []

    func categories() async throws -> [ProductCategory] {
        categoryRequestCount += 1
        guard categoryRequestCount == 1 else { return [] }
        firstCategoriesWaiters.forEach { $0.resume() }
        firstCategoriesWaiters.removeAll()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                firstCategoriesContinuation = continuation
            }
        } onCancel: {
            Task { await self.cancelFirstCategoriesRequest() }
        }
    }

    func page(_ query: ProductQuery) async throws -> ProductPage {
        queries.append(query)
        return ProductPage(products: [.fixture(id: 1)], total: 1, skip: 0, limit: query.limit)
    }

    func product(id: Product.ID) async throws -> Product { .fixture(id: id) }
    func related(to product: Product, limit: Int) async throws -> [Product] { [] }
    func recordedQueries() -> [ProductQuery] { queries }

    func waitForFirstCategoriesRequest() async {
        guard categoryRequestCount == 0 else { return }
        await withCheckedContinuation { firstCategoriesWaiters.append($0) }
    }

    func finishFirstCategoriesRequest() {
        guard let continuation = firstCategoriesContinuation else { return }
        firstCategoriesContinuation = nil
        continuation.resume(throwing: CancellationError())
    }

    func succeedFirstCategoriesRequest() {
        guard let continuation = firstCategoriesContinuation else { return }
        firstCategoriesContinuation = nil
        continuation.resume(returning: [])
    }

    private func cancelFirstCategoriesRequest() {
        categoryCancellationCount += 1
        finishFirstCategoriesRequest()
    }
}

private actor DeferredPageRepository: IProductRepository {
    private var continuations: [CheckedContinuation<ProductPage, Never>?] = []
    private var requestCountWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var queries: [ProductQuery] = []

    func categories() async throws -> [ProductCategory] { [] }

    func page(_ query: ProductQuery) async throws -> ProductPage {
        queries.append(query)
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
            resumeWaiters()
        }
    }

    func product(id: Product.ID) async throws -> Product { .fixture(id: id) }
    func related(to product: Product, limit: Int) async throws -> [Product] { [] }
    func recordedQueries() -> [ProductQuery] { queries }

    func waitForRequestCount(_ count: Int) async {
        guard continuations.count < count else { return }
        await withCheckedContinuation { requestCountWaiters.append((count, $0)) }
    }

    func resume(index: Int, productID: Int) {
        guard continuations.indices.contains(index), let continuation = continuations[index] else { return }
        continuations[index] = nil
        continuation.resume(returning: ProductPage(
            products: [.fixture(id: productID)], total: 1, skip: 0, limit: 20
        ))
    }

    private func resumeWaiters() {
        let ready = requestCountWaiters.filter { $0.0 <= continuations.count }
        requestCountWaiters.removeAll { $0.0 <= continuations.count }
        ready.forEach { $0.1.resume() }
    }
}
