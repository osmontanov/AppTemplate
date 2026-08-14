import SwiftUI

struct StoreFlowView: View {
    @Bindable var router: StoreRouter
    let dependencies: StoreDependencies
    let uiSupport: StoreUISupport
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        AdaptiveFlowNavigationContainer(
            path: $router.path,
            layout: AdaptiveFlowLayoutPolicy.resolve(
                horizontalSizeClass: horizontalSizeClass,
                isMacOS: isMacOS
            )
        ) {
            CatalogView(
                router: router,
                products: dependencies.products,
                preferences: dependencies.preferences,
                images: uiSupport.images,
                clock: uiSupport.clock
            )
            .toolbar {
                ToolbarItem {
                    Menu("More", systemImage: "ellipsis.circle") {
                        Button("Profile") { router.push(.profile) }
                        Button("Cart") { router.push(.cart) }
                        Button("Favorites") { router.push(.favorites) }
                    }
                }
            }
        } placeholder: {
            ContentUnavailableView("Select a Store destination", systemImage: "storefront")
        } destination: { route in
            destination(route)
        }
    }

    @ViewBuilder
    private func destination(_ route: StoreRoute) -> some View {
        switch route {
        case let .product(id):
            ProductDetailView(
                productID: id,
                router: router,
                products: dependencies.products,
                cart: dependencies.cart,
                images: uiSupport.images
            )
        case let .reviews(id):
            ReviewsView(productID: id, products: dependencies.products)
        case .favorites:
            ContentUnavailableView(
                "Favorites require sign in",
                systemImage: "heart"
            )
            .navigationTitle("Favorites")
        case .cart:
            CartView(repository: dependencies.cart)
        case .profile:
            ProfileView(
                appInfo: dependencies.appInfo,
                preferences: dependencies.preferences
            )
        }
    }

    private var isMacOS: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}
