import SwiftUI

struct StoreFlowView: View {
    @Bindable var router: StoreRouter
    let dependencies: StoreDependencies
    let uiSupport: StoreUISupport
    @Environment(ProtectedStoreActionExecutor.self) private var protectedActions
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
                        Button("Favorites") { requestProtected(.openFavorites) }
                    }
                }
            }
        } placeholder: {
            ContentUnavailableView("Select a Store destination", systemImage: "storefront")
        } destination: { route in
            destination(route)
        }
        .sheet(item: $router.presentation) { presentation in
            presentedContent(presentation)
        }
    }

    @ViewBuilder
    private func presentedContent(_ presentation: StorePresentation) -> some View {
        switch presentation {
        case .authentication:
            AuthenticationFlowView(dependencies: AuthenticationDependencies(
                session: dependencies.session,
                cancellation: router
            ))
        case .filters:
            ContentUnavailableView("Filters", systemImage: "line.3.horizontal.decrease")
        case .checkout:
            ContentUnavailableView("Checkout", systemImage: "cart")
        case let .reminder(productID):
            ContentUnavailableView(
                "Reminder for product \(productID)",
                systemImage: "bell"
            )
        case let .sessionRecovery(reason):
            SessionRecoveryView(
                reason: reason,
                session: dependencies.session,
                onResolved: {
                    if case .sessionRecovery = router.presentation {
                        router.presentation = nil
                    }
                }
            )
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
            .toolbar {
                ToolbarItem {
                    Button("Favorite", systemImage: "heart") {
                        Task {
                            await protectedActions.activateHeart(
                                productID: id,
                                session: dependencies.session.presentation.state
                            )
                        }
                    }
                    .accessibilityIdentifier("action.store.favorite")
                }
            }
        case let .reviews(id):
            ReviewsView(productID: id, products: dependencies.products)
        case .favorites:
            if case let .authenticated(profile, _) = dependencies.session.presentation.state {
                FavoritesView(
                    router: router,
                    repository: dependencies.favorites,
                    userID: profile.id
                )
            } else {
                ContentUnavailableView("Favorites require sign in", systemImage: "heart")
            }
        case .cart:
            CartView(repository: dependencies.cart)
        case .profile:
            ProfileView(
                router: router,
                session: dependencies.session,
                appInfo: dependencies.appInfo,
                preferences: dependencies.preferences
            )
        }
    }

    private func requestProtected(_ action: ProtectedStoreAction) {
        let state = dependencies.session.presentation.state
        switch router.requestProtected(action, session: state) {
        case let .execute(action):
            guard case let .authenticated(profile, _) = state else { return }
            Task {
                await protectedActions.execute(
                    action,
                    expectedUserID: profile.id
                )
            }
        case .presentAuthentication:
            break
        case let .blocked(reason):
            router.presentation = .sessionRecovery(reason)
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
