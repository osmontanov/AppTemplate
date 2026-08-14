import Observation

@MainActor
@Observable
final class CartViewModel {
    private let repository: any ICartRepository
    private(set) var cart: CartAggregate?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var canCheckout: Bool { cart?.lines.isEmpty == false && !isLoading }

    init(repository: any ICartRepository) { self.repository = repository }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            cart = try await repository.cart()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "The cart is unavailable."
        }
    }

    func setQuantity(productID: Int, quantity: Int) async {
        do {
            cart = try await repository.setQuantity(productID: productID, quantity: quantity)
            errorMessage = nil
        } catch { errorMessage = "The cart could not be updated." }
    }

    func remove(productID: Int) async {
        do {
            cart = try await repository.remove(productID: productID)
            errorMessage = nil
        } catch { errorMessage = "The cart could not be updated." }
    }

    func handleRevisionConflict() async {
        await load()
        errorMessage = "Your cart changed. Review it before trying checkout again."
    }
}
