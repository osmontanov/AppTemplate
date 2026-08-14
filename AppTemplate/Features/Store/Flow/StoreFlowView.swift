import SwiftUI

struct StoreFlowView: View {
    @Bindable var router: StoreRouter
    let session: SessionPresentation
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        AdaptiveFlowNavigationContainer(
            path: $router.path,
            layout: AdaptiveFlowLayoutPolicy.resolve(horizontalSizeClass: horizontalSizeClass, isMacOS: isMacOS)
        ) {
            List {
                Section("Store") {
                    NavigationLink("Catalog", value: StoreRoute.product(1))
                    NavigationLink("Cart", value: StoreRoute.cart)
                }
            }
            .navigationTitle("Store")
            .toolbar {
                ToolbarItem {
                    Menu("More", systemImage: "ellipsis.circle") {
                        Button("Favorites") { router.push(.favorites) }
                        Button("Profile") { router.push(.profile) }
                        Button("Cart") { router.push(.cart) }
                    }
                }
            }
        } placeholder: {
            ContentUnavailableView("Select a Store destination", systemImage: "storefront")
        } destination: { route in
            StorePlaceholderDestination(route: route)
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

private struct StorePlaceholderDestination: View {
    let route: StoreRoute

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol).navigationTitle(title)
    }

    private var title: LocalizedStringKey {
        switch route {
        case .product: "Product"
        case .reviews: "Reviews"
        case .favorites: "Favorites"
        case .cart: "Cart"
        case .profile: "Profile"
        }
    }

    private var symbol: String {
        switch route {
        case .product: "shippingbox"
        case .reviews: "star.bubble"
        case .favorites: "heart"
        case .cart: "cart"
        case .profile: "person.crop.circle"
        }
    }
}
