import Foundation
@testable import AppTemplate

actor ControlledProductRepository: IProductRepository {
    private var pages: [ProductPage]
    private var productsByID: [Int: Product]
    private(set) var queries: [ProductQuery] = []
    private(set) var requestedProductIDs: [Int] = []

    init(
        pages: [ProductPage] = [],
        products: [Product] = []
    ) {
        self.pages = pages
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
    }

    func categories() async throws -> [ProductCategory] {
        [ProductCategory(slug: "phones", name: "Phones")]
    }

    func page(_ query: ProductQuery) async throws -> ProductPage {
        queries.append(query)
        guard !pages.isEmpty else {
            return ProductPage(products: [], total: 0, skip: query.skip, limit: query.limit)
        }
        return pages.removeFirst()
    }

    func product(id: Product.ID) async throws -> Product {
        requestedProductIDs.append(id)
        guard let product = productsByID[id] else { throw ProductRepositoryError.invalidData }
        return product
    }

    func related(to product: Product, limit: Int) async throws -> [Product] {
        Array(productsByID.values.filter { $0.id != product.id }.sorted { $0.id < $1.id }.prefix(limit))
    }

    func recordedQueries() -> [ProductQuery] { queries }
}

actor ControlledStorePreferencesRepository: IStorePreferencesRepository {
    private var value: StorePreferences
    private var continuation: AsyncStream<StorePreferences>.Continuation?

    init(_ value: StorePreferences = .defaults) { self.value = value }

    func current() async -> StorePreferences { value }

    func updates() async -> AsyncStream<StorePreferences> {
        let pair = AsyncStream.makeStream(of: StorePreferences.self)
        continuation = pair.continuation
        pair.continuation.yield(value)
        return pair.stream
    }

    func setLayout(_ layout: StoreCatalogLayout) async throws {
        value = StorePreferences(layout: layout, sort: value.sort, preferredRemotePageSize: value.preferredRemotePageSize)
        continuation?.yield(value)
    }

    func setSort(_ sort: StoreCatalogSort) async throws {
        value = StorePreferences(layout: value.layout, sort: sort, preferredRemotePageSize: value.preferredRemotePageSize)
        continuation?.yield(value)
    }

    func setPreferredRemotePageSize(_ size: Int) async throws {
        value = StorePreferences(layout: value.layout, sort: value.sort, preferredRemotePageSize: size)
        continuation?.yield(value)
    }
}

actor CartRepositorySpy: ICartRepository {
    var aggregate: CartAggregate
    var checkoutError: CartRepositoryError?
    private(set) var expectedRevisions: [Int64] = []

    init(
        aggregate: CartAggregate = .fixture(),
        checkoutError: CartRepositoryError? = nil
    ) {
        self.aggregate = aggregate
        self.checkoutError = checkoutError
    }

    func cart() async throws -> CartAggregate { aggregate }

    func add(_ product: ProductSnapshot, quantity: Int) async throws -> CartAggregate {
        aggregate.lines.append(CartLine(product: product, quantity: quantity))
        return aggregate
    }

    func setQuantity(productID: Int, quantity: Int) async throws -> CartAggregate {
        if let index = aggregate.lines.firstIndex(where: { $0.product.id == productID }) {
            aggregate.lines[index].quantity = quantity
        }
        return aggregate
    }

    func remove(productID: Int) async throws -> CartAggregate {
        aggregate.lines.removeAll { $0.product.id == productID }
        return aggregate
    }

    func checkout(expectedRevision: Int64) async throws {
        expectedRevisions.append(expectedRevision)
        if let checkoutError { throw checkoutError }
    }

    func revisions() -> [Int64] { expectedRevisions }
}
