import SwiftUI

struct CartView: View {
    let repository: any ICartRepository
    @State private var viewModel: CartViewModel
    @State private var checkoutCart: CartAggregate?

    init(repository: any ICartRepository) {
        self.repository = repository
        _viewModel = State(initialValue: CartViewModel(repository: repository))
    }

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(verbatim: error).foregroundStyle(.red)
            }
            if let cart = viewModel.cart {
                ForEach(cart.lines, id: \.product.id) { line in
                    VStack(alignment: .leading) {
                        Text(verbatim: line.product.title).font(.headline)
                        Stepper(
                            "Quantity: \(line.quantity)",
                            value: Binding(
                                get: { line.quantity },
                                set: { quantity in
                                    Task { await viewModel.setQuantity(productID: line.product.id, quantity: quantity) }
                                }
                            ),
                            in: 1...99
                        )
                        Button("Remove", role: .destructive) {
                            Task { await viewModel.remove(productID: line.product.id) }
                        }
                    }
                }
                if cart.lines.isEmpty {
                    ContentUnavailableView("Your cart is empty", systemImage: "cart")
                }
            } else if viewModel.isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Cart")
        .safeAreaInset(edge: .bottom) {
            Button("Demo checkout") {
                checkoutCart = viewModel.cart
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canCheckout)
            .padding()
        }
        .task { await viewModel.load() }
        .sheet(item: $checkoutCart) { cart in
            CheckoutFlowView(
                cart: cart,
                repository: repository,
                onDone: {
                    checkoutCart = nil
                    Task { await viewModel.load() }
                },
                onRevisionConflict: {
                    checkoutCart = nil
                    Task { await viewModel.handleRevisionConflict() }
                }
            )
        }
        .accessibilityIdentifier("screen.store.cart")
    }
}
