import SwiftUI

struct ProductDetailView: View {
    @Bindable var router: StoreRouter
    let productID: Product.ID
    let images: any IImageLoader
    @State private var viewModel: ProductDetailViewModel
    @Environment(\.locale) private var locale
    @AccessibilityFocusState private var resultIsFocused: Bool

    init(
        productID: Product.ID,
        router: StoreRouter,
        products: any IProductRepository,
        cart: any ICartRepository,
        images: any IImageLoader
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
                            RemoteProductImage(url: url, imageLoader: images)
                                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 320)
                        }
                        Text(verbatim: model.product.title).font(.largeTitle.bold())
                        Text(verbatim: StoreFormatting.priceUSD(model.product.price, locale: locale))
                            .font(.title2)
                        Text(verbatim: model.product.description)
                        ViewThatFits(in: .horizontal) {
                            HStack { actions(product: model.product) }
                            VStack { actions(product: model.product) }
                        }
                        if !model.related.isEmpty {
                            Text(StoreServicesText.resource("Related products")).font(.headline)
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
                ProgressView(StoreServicesText.resource("Loading product"))
                    .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
            }
        }
        .navigationTitle(StoreServicesText.resource("Product"))
        .task(id: productID) {
            await viewModel.load(productID: productID)
            resultIsFocused = viewModel.model == nil
            AccessibilityNotification.Announcement(
                viewModel.model == nil
                    ? StoreServicesText.string("Product is unavailable")
                    : StoreServicesText.string("Product loaded")
            ).post()
        }
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.productDetail))
    }

    @ViewBuilder
    private func actions(product: Product) -> some View {
        Button(StoreServicesText.resource("Add to cart")) { Task { await viewModel.addToCart() } }
            .buttonStyle(.borderedProminent)
            .disabled(product.stock == 0)
            .frame(minHeight: 44)
        Button(StoreServicesText.resource("Reviews")) { router.push(.reviews(product.id)) }
            .frame(minHeight: 44)
        Button(StoreServicesText.resource("Remind me"), systemImage: "bell") {
            router.presentation = .reminder(product.id)
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier(AppAccessibilityIdentifier.action(.scheduleReminder))
    }
}
