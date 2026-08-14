import Foundation
import Observation

@MainActor
@Observable
final class ProductDetailViewModel {
    private(set) var productID: Product.ID
    private let products: any IProductRepository
    private let cart: any ICartRepository
    private var generation: UInt64 = 0

    private(set) var state: ProductDetailState = .idle
    private(set) var model: ProductDetailModel?
    private(set) var errorMessage: String?

    init(productID: Product.ID, products: any IProductRepository, cart: any ICartRepository) {
        self.productID = productID
        self.products = products
        self.cart = cart
    }

    func load(productID: Product.ID? = nil) async {
        if let productID { self.productID = productID }
        precondition(generation < UInt64.max, "Product detail load generation exhausted")
        generation += 1
        let currentGeneration = generation
        state = .loading
        errorMessage = nil
        do {
            let product = try await products.product(id: self.productID)
            let related = try await products.related(to: product, limit: 6)
            try Task.checkCancellation()
            guard generation == currentGeneration else { return }
            model = ProductDetailModel(product: product, related: related)
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard generation == currentGeneration else { return }
            state = .failed
            errorMessage = StoreServicesText.string("Product details are unavailable.")
        }
    }

    func addToCart() async {
        guard let product = model?.product else { return }
        do {
            _ = try await cart.add(product.snapshot, quantity: 1)
            errorMessage = nil
        } catch {
            errorMessage = StoreServicesText.string("The cart could not be updated.")
        }
    }
}
