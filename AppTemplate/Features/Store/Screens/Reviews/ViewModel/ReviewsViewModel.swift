import Foundation
import Observation

@MainActor
@Observable
final class ReviewsViewModel {
    let productID: Product.ID
    private let products: any IProductRepository
    private(set) var product: Product?
    private(set) var errorMessage: String?

    init(productID: Product.ID, products: any IProductRepository) {
        self.productID = productID
        self.products = products
    }

    func load() async {
        do {
            product = try await products.product(id: productID)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = AppText.string("Reviews are unavailable.")
        }
    }
}
