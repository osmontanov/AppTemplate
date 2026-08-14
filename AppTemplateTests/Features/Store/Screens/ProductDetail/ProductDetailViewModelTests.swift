import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct ProductDetailViewModelTests {
    @Test
    func loadPublishesProductAndDeterministicRelatedProducts() async {
        let repository = ControlledProductRepository(products: [.fixture(id: 3), .fixture(id: 1), .fixture(id: 2)])
        let cart = CartRepositorySpy()
        let viewModel = ProductDetailViewModel(productID: 2, products: repository, cart: cart)

        await viewModel.load()

        #expect(viewModel.model?.product.id == 2)
        #expect(viewModel.model?.related.map(\.id) == [1, 3])
    }

    @Test
    func addingLoadedProductUsesItsExactSnapshot() async throws {
        let product = Product.fixture(id: 9, title: "Nine", price: 4)
        let repository = ControlledProductRepository(products: [product])
        let cart = CartRepositorySpy(aggregate: .fixture(products: []))
        let viewModel = ProductDetailViewModel(productID: 9, products: repository, cart: cart)
        await viewModel.load()

        await viewModel.addToCart()

        #expect(try await cart.cart().lines == [CartLine(product: product.snapshot, quantity: 1)])
    }

    @Test
    func newerProductIDWinsWhenOlderRequestReturnsLast() async {
        let repository = DeferredDetailProductRepository()
        let viewModel = ProductDetailViewModel(
            productID: 1,
            products: repository,
            cart: CartRepositorySpy()
        )
        let first = Task { await viewModel.load() }
        await repository.waitForRequestCount(1)
        let second = Task { await viewModel.load(productID: 2) }
        await repository.waitForRequestCount(2)

        await repository.resume(productID: 2)
        await second.value
        await repository.resume(productID: 1)
        await first.value

        #expect(viewModel.model?.product.id == 2)
    }
}

private actor DeferredDetailProductRepository: IProductRepository {
    private var continuations: [Int: CheckedContinuation<Product, Never>] = [:]
    private var requestCountWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func categories() async throws -> [ProductCategory] { [] }
    func page(_ query: ProductQuery) async throws -> ProductPage {
        ProductPage(products: [], total: 0, skip: query.skip, limit: query.limit)
    }
    func product(id: Product.ID) async throws -> Product {
        await withCheckedContinuation { continuation in
            continuations[id] = continuation
            resumeWaiters()
        }
    }
    func related(to product: Product, limit: Int) async throws -> [Product] { [] }

    func waitForRequestCount(_ count: Int) async {
        guard continuations.count < count else { return }
        await withCheckedContinuation { requestCountWaiters.append((count, $0)) }
    }

    func resume(productID: Int) {
        continuations.removeValue(forKey: productID)?.resume(returning: .fixture(id: productID))
    }

    private func resumeWaiters() {
        let ready = requestCountWaiters.filter { $0.0 <= continuations.count }
        requestCountWaiters.removeAll { $0.0 <= continuations.count }
        ready.forEach { $0.1.resume() }
    }
}
