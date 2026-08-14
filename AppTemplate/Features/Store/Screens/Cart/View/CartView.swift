import SwiftUI

struct CartView: View {
    let repository: any ICartRepository
    @State private var viewModel: CartViewModel
    @State private var checkoutCart: CartAggregate?
    @AccessibilityFocusState private var resultIsFocused: Bool

    init(repository: any ICartRepository) {
        self.repository = repository
        _viewModel = State(initialValue: CartViewModel(repository: repository))
    }

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
                    .accessibilityFocused($resultIsFocused)
            }
            if let cart = viewModel.cart {
                ForEach(cart.lines, id: \.product.id) { line in
                    VStack(alignment: .leading) {
                        Text(verbatim: line.product.title).font(.headline)
                        Stepper(
                            StoreServicesText.resource("Quantity: \(line.quantity)"),
                            value: Binding(
                                get: { line.quantity },
                                set: { quantity in
                                    Task { await viewModel.setQuantity(productID: line.product.id, quantity: quantity) }
                                }
                            ),
                            in: 1...99
                        )
                        Button(StoreServicesText.resource("Remove"), role: .destructive) {
                            Task { await viewModel.remove(productID: line.product.id) }
                        }
                    }
                }
                if cart.lines.isEmpty {
                    ContentUnavailableView(StoreServicesText.resource("Your cart is empty"), systemImage: "cart")
                        .accessibilityIdentifier(AppAccessibilityIdentifier.result(.empty))
                        .accessibilityFocused($resultIsFocused)
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .accessibilityLabel(StoreServicesText.resource("Loading cart"))
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
            }
        }
        .navigationTitle(StoreServicesText.resource("Cart"))
        .safeAreaInset(edge: .bottom) {
            Button(StoreServicesText.resource("Demo checkout")) {
                checkoutCart = viewModel.cart
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canCheckout)
            .frame(minHeight: 44)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(AppAccessibilityIdentifier.action(.continueCheckout))
            .padding()
        }
        .task {
            await viewModel.load()
            resultIsFocused = viewModel.errorMessage != nil || viewModel.cart?.lines.isEmpty == true
            AccessibilityNotification.Announcement(
                viewModel.errorMessage != nil
                    ? StoreServicesText.string("Cart is unavailable")
                    : StoreServicesText.string("Cart loaded")
            ).post()
        }
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
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.cart))
    }
}
