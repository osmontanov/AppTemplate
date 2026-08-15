import Foundation
import Observation

@MainActor
@Observable
final class CatalogViewModel {
    static let pageSizeChoices = [10, 20, 30, 50]

    private let products: any IProductRepository
    private let preferences: any IStorePreferencesRepository
    private let clock: AppClock
    private var generation: UInt64 = 0
    private var hasLoadedCategories = false
    private var hasLoadedInitialPage = false
    private var initialLoadTask: Task<Bool, Never>?
    private var initialLoadToken: UInt64 = 0

    private(set) var state: CatalogState = .idle
    private(set) var model: CatalogModel = .empty
    private(set) var errorMessage: String?
    var searchText = ""
    var selectedCategory = ""

    var isSortingEnabled: Bool { model.mode == .all }
    var canLoadMore: Bool { model.products.count < model.total && state != .loading }
    var isInitialLoadComplete: Bool { hasLoadedInitialPage }

    init(
        products: any IProductRepository,
        preferences: any IStorePreferencesRepository,
        clock: AppClock
    ) {
        self.products = products
        self.preferences = preferences
        self.clock = clock
    }

    @discardableResult
    func loadInitial() async -> Bool {
        if hasLoadedInitialPage { return true }
        let task: Task<Bool, Never>
        let token: UInt64
        let joinedExistingTask: Bool
        if let initialLoadTask {
            task = initialLoadTask
            token = initialLoadToken
            joinedExistingTask = true
        } else {
            precondition(initialLoadToken < UInt64.max, "Catalog initial-load token exhausted")
            initialLoadToken += 1
            token = initialLoadToken
            joinedExistingTask = false
            task = Task { @MainActor [weak self] in
                guard let self else { return false }
                return await self.performInitialLoad()
            }
            initialLoadTask = task
        }
        let completed = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            if !joinedExistingTask {
                task.cancel()
            }
        }
        if initialLoadToken == token {
            initialLoadTask = nil
            hasLoadedInitialPage = completed
        }
        if completed { return true }
        guard joinedExistingTask, task.isCancelled, !Task.isCancelled else {
            return false
        }
        return await loadInitial()
    }

    private func performInitialLoad() async -> Bool {
        model.preferences = await preferences.current()
        if !hasLoadedCategories {
            do {
                model.categories = try await products.categories()
                hasLoadedCategories = true
            } catch {
                if Self.isCancellation(error) { return false }
                errorMessage = StoreServicesText.string("Categories are unavailable.")
            }
        }
        guard await reload(mode: .all) else {
            guard !Task.isCancelled, isLoaded(currentQueryMode()) else { return false }
            return true
        }
        await reconcileCurrentQuery()
        return true
    }

    private func reconcileCurrentQuery() async {
        while !Task.isCancelled {
            let requestedMode = currentQueryMode()
            switch requestedMode {
            case .all:
                guard !isLoaded(.all) else { return }
                await reload(mode: .all)
            case let .category(slug):
                await selectCategory(slug)
            case let .search(text):
                await search(text)
            }
            guard currentQueryMode() != requestedMode else { return }
        }
    }

    private func currentQueryMode() -> ProductQueryMode {
        let category = selectedCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !category.isEmpty { return .category(category) }
        let search = Self.capped(searchText).trimmingCharacters(in: .whitespacesAndNewlines)
        return search.isEmpty ? .all : .search(search)
    }

    func search(_ text: String) async {
        let capped = Self.capped(text).trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedMode: ProductQueryMode = capped.isEmpty ? .all : .search(capped)
        guard !isLoaded(requestedMode) else { return }
        do {
            try await clock.sleep(.milliseconds(300))
            try Task.checkCancellation()
        } catch {
            return
        }
        guard !isLoaded(requestedMode) else { return }
        await reload(mode: requestedMode)
    }

    func selectCategory(_ slug: String?) async {
        let value = slug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let requestedMode: ProductQueryMode = value.isEmpty ? .all : .category(value)
        guard !isLoaded(requestedMode) else { return }
        await reload(mode: requestedMode)
    }

    func loadNextPage() async {
        guard canLoadMore else { return }
        await load(mode: model.mode, skip: model.products.count, appending: true)
    }

    func observePreferences() async {
        let updates = await preferences.updates()
        for await update in updates {
            guard !Task.isCancelled else { return }
            guard update != model.preferences else { continue }
            model.preferences = update
            await reload(mode: model.mode)
        }
    }

    func setLayout(_ layout: StoreCatalogLayout) async {
        do { try await preferences.setLayout(layout) }
        catch { errorMessage = StoreServicesText.string("Preferences could not be saved.") }
    }

    func setSort(_ sort: StoreCatalogSort) async {
        guard isSortingEnabled else { return }
        do { try await preferences.setSort(sort) }
        catch { errorMessage = StoreServicesText.string("Preferences could not be saved.") }
    }

    func setPageSize(_ size: Int) async {
        guard Self.pageSizeChoices.contains(size) else { return }
        do { try await preferences.setPreferredRemotePageSize(size) }
        catch { errorMessage = StoreServicesText.string("Preferences could not be saved.") }
    }

    @discardableResult
    private func reload(mode: ProductQueryMode) async -> Bool {
        await load(mode: mode, skip: 0, appending: false)
    }

    @discardableResult
    private func load(mode: ProductQueryMode, skip: Int, appending: Bool) async -> Bool {
        precondition(generation < UInt64.max, "Catalog load generation exhausted")
        generation += 1
        let currentGeneration = generation
        state = .loading
        errorMessage = nil
        let query = ProductQuery(
            mode: mode,
            sort: mode == .all ? model.preferences.sort.productSort : nil,
            limit: model.preferences.preferredRemotePageSize,
            skip: skip
        )
        do {
            let page = try await products.page(query)
            try Task.checkCancellation()
            guard generation == currentGeneration else { return false }
            let source = appending ? model.products + page.products : page.products
            var ids: Set<Int> = []
            model.products = source.filter { ids.insert($0.id).inserted }
            model.mode = mode
            model.total = page.total
            state = .loaded
            return true
        } catch {
            guard generation == currentGeneration else { return false }
            if Self.isCancellation(error) {
                state = model.products.isEmpty ? .idle : .loaded
                return false
            }
            state = .failed
            errorMessage = StoreServicesText.string("Products are unavailable.")
            return false
        }
    }

    private nonisolated static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? RemoteServiceError) == .cancelled
    }

    private nonisolated static func capped(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.prefix(100)))
    }

    private func isLoaded(_ mode: ProductQueryMode) -> Bool {
        state == .loaded && model.mode == mode
    }
}
