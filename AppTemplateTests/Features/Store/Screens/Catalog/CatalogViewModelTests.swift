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
        await initial.value

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

private actor DeferredPageRepository: IProductRepository {
    private var continuations: [CheckedContinuation<ProductPage, Never>?] = []
    private var requestCountWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func categories() async throws -> [ProductCategory] { [] }

    func page(_ query: ProductQuery) async throws -> ProductPage {
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
            resumeWaiters()
        }
    }

    func product(id: Product.ID) async throws -> Product { .fixture(id: id) }
    func related(to product: Product, limit: Int) async throws -> [Product] { [] }

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
