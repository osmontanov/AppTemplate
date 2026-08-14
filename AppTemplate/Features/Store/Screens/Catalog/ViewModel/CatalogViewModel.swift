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

    private(set) var state: CatalogState = .idle
    private(set) var model: CatalogModel = .empty
    private(set) var errorMessage: String?

    var isSortingEnabled: Bool { model.mode == .all }
    var canLoadMore: Bool { model.products.count < model.total && state != .loading }

    init(
        products: any IProductRepository,
        preferences: any IStorePreferencesRepository,
        clock: AppClock
    ) {
        self.products = products
        self.preferences = preferences
        self.clock = clock
    }

    func loadInitial() async {
        model.preferences = await preferences.current()
        if !hasLoadedCategories {
            do {
                model.categories = try await products.categories()
                hasLoadedCategories = true
            } catch is CancellationError {
                return
            } catch {
                errorMessage = StoreServicesText.string("Categories are unavailable.")
            }
        }
        await reload(mode: .all)
    }

    func search(_ text: String) async {
        do {
            try await clock.sleep(.milliseconds(300))
            try Task.checkCancellation()
        } catch {
            return
        }
        let capped = Self.capped(text).trimmingCharacters(in: .whitespacesAndNewlines)
        await reload(mode: capped.isEmpty ? .all : .search(capped))
    }

    func selectCategory(_ slug: String?) async {
        let value = slug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        await reload(mode: value.isEmpty ? .all : .category(value))
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

    private func reload(mode: ProductQueryMode) async {
        await load(mode: mode, skip: 0, appending: false)
    }

    private func load(mode: ProductQueryMode, skip: Int, appending: Bool) async {
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
            guard generation == currentGeneration else { return }
            let source = appending ? model.products + page.products : page.products
            var ids: Set<Int> = []
            model.products = source.filter { ids.insert($0.id).inserted }
            model.mode = mode
            model.total = page.total
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard generation == currentGeneration else { return }
            state = .failed
            errorMessage = StoreServicesText.string("Products are unavailable.")
        }
    }

    private nonisolated static func capped(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.prefix(100)))
    }
}
