import Testing
@testable import AppTemplate

@MainActor
struct CartViewModelTests {
    @Test
    func emptyCartDisablesCheckout() async {
        let repository = CartRepositorySpy(aggregate: .fixture(products: []))
        let viewModel = CartViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.cart?.lines.isEmpty == true)
        #expect(!viewModel.canCheckout)
    }

    @Test
    func quantityAndRemovalPublishRepositoryAggregate() async {
        let repository = CartRepositorySpy(aggregate: .fixture(products: [.fixture(id: 1)]))
        let viewModel = CartViewModel(repository: repository)
        await viewModel.load()

        await viewModel.setQuantity(productID: 1, quantity: 3)
        #expect(viewModel.cart?.lines.first?.quantity == 3)
        await viewModel.remove(productID: 1)
        #expect(viewModel.cart?.lines.isEmpty == true)
    }
}
