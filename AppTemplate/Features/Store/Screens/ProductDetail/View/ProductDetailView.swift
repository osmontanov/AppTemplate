import SwiftUI

struct ProductDetailView: View {
    @Bindable var router: StoreRouter
    let productID: Product.ID
    let images: ImageService
    @State private var viewModel: ProductDetailViewModel
    @Environment(\.locale) private var locale
    @AccessibilityFocusState private var resultIsFocused: Bool

    init(
        productID: Product.ID,
        router: StoreRouter,
        products: any IProductRepository,
        cart: any ICartRepository,
        images: ImageService
    ) {
        self.productID = productID
        self.router = router
        self.images = images
        _viewModel = State(initialValue: ProductDetailViewModel(
            productID: productID, products: products, cart: cart
        ))
    }

    var body: some View {
        Group {
            if let model = viewModel.model {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let url = model.product.thumbnailURL {
                            RemoteImage(url: url, images: images)
                                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 320)
                        }
                        Text(verbatim: model.product.title).font(.largeTitle.bold())
                        Text(verbatim: AppFormatting.priceUSD(model.product.price, locale: locale))
                            .font(.title2)
                        Text(verbatim: model.product.description)
                        ViewThatFits(in: .horizontal) {
                            HStack { actions(product: model.product) }
                            VStack { actions(product: model.product) }
                        }
                        if viewModel.cartUpdateSucceeded == true {
                            Label(AppText.resource("Added to cart"), systemImage: "checkmark.circle.fill")
                                .accessibilityLabel(AppText.resource("Added to cart"))
                                .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualSuccess))
                        } else if viewModel.cartUpdateSucceeded == false {
                            Label(AppText.resource("The cart could not be updated."), systemImage: "exclamationmark.triangle.fill")
                                .accessibilityLabel(AppText.resource("The cart could not be updated."))
                                .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
                        }
                        if !model.related.isEmpty {
                            Text(AppText.resource("Related products")).font(.headline)
                            ForEach(model.related) { product in
                                Button(product.title) { router.push(.product(product.id)) }
                            }
                        }
                    }
                    .padding()
                }
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.actualFailure))
                    .accessibilityFocused($resultIsFocused)
            } else {
                ProgressView(AppText.resource("Loading product"))
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
            }
        }
        .navigationTitle(AppText.resource("Product"))
        .task(id: productID) {
            await viewModel.load(productID: productID)
            resultIsFocused = viewModel.model == nil
            AccessibilityNotification.Announcement(
                viewModel.model == nil
                    ? AppText.string("Product is unavailable")
                    : AppText.string("Product loaded")
            ).post()
        }
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.productDetail))
    }

    @ViewBuilder
    private func actions(product: Product) -> some View {
        Button(AppText.resource("Add to cart")) {
            Task {
                await viewModel.addToCart()
                AccessibilityNotification.Announcement(
                    viewModel.cartUpdateSucceeded == true
                        ? AppText.string("Added to cart")
                        : AppText.string("The cart could not be updated.")
                ).post()
            }
        }
            .buttonStyle(.borderedProminent)
            .disabled(product.stock == 0)
            .frame(minHeight: 44)
            .accessibilityIdentifier("action.store.add-to-cart")
        Button(AppText.resource("Reviews")) { router.push(.reviews(product.id)) }
            .frame(minHeight: 44)
            .accessibilityIdentifier("action.store.reviews")
        Button(AppText.resource("Remind me"), systemImage: "bell") {
            router.presentation = .reminder(product.id)
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("action.store.reminder")
    }
}
