import SwiftUI

struct StoreFlowView: View {
    @Bindable var router: StoreRouter
    let dependencies: StoreDependencies
    let uiSupport: StoreUISupport
    @Environment(ProtectedStoreActionExecutor.self) private var protectedActions
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var searchRequestID = 0

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
                clock: uiSupport.clock,
                searchRequestID: searchRequestID
            )
            .toolbar { storeToolbar }
        } placeholder: {
            ContentUnavailableView(StoreServicesText.resource("Select a Store destination"), systemImage: "storefront")
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
            ContentUnavailableView(StoreServicesText.resource("Filters"), systemImage: "line.3.horizontal.decrease")
        case .checkout:
            ContentUnavailableView(StoreServicesText.resource("Checkout"), systemImage: "cart")
        case let .reminder(productID):
            ProductReminderPresentationView(
                productID: productID,
                products: dependencies.products,
                reminders: dependencies.reminders,
                clock: uiSupport.clock
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
                    Button(StoreServicesText.resource("Favorite"), systemImage: "heart") {
                        Task {
                            await protectedActions.activateHeart(
                                productID: id,
                                session: dependencies.session.presentation.state
                            )
                            AccessibilityNotification.Announcement(
                                protectedActions.error == nil
                                    ? StoreServicesText.string("Favorite status updated")
                                    : StoreServicesText.string("Favorite could not be updated")
                            ).post()
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier(AppAccessibilityIdentifier.action(.favorite))
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
                ContentUnavailableView(StoreServicesText.resource("Favorites require sign in"), systemImage: "heart")
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

    @ToolbarContentBuilder
    private var storeToolbar: some ToolbarContent {
        ToolbarItemGroup {
            ForEach(
                Array(StoreToolbarPolicy.actions(horizontalSizeClass: horizontalSizeClass).enumerated()),
                id: \.offset
            ) { _, action in
                storeToolbarAction(action)
            }
        }
    }

    @ViewBuilder
    private func storeToolbarAction(_ action: StoreToolbarAction) -> some View {
        switch action {
        case .search:
            Button(StoreServicesText.resource("Search"), systemImage: "magnifyingglass") {
                searchRequestID &+= 1
            }
            .accessibilityIdentifier("action.store.search")
        case .filter:
            Button(StoreServicesText.resource("Filters"), systemImage: "line.3.horizontal.decrease") {
                router.presentation = .filters
            }
            .accessibilityIdentifier("action.store.filter")
        case .cart:
            Button(StoreServicesText.resource("Cart"), systemImage: "cart") { router.push(.cart) }
                .accessibilityIdentifier("action.store.cart")
        case .favorites:
            Button(StoreServicesText.resource("Favorites"), systemImage: "heart") {
                requestProtected(.openFavorites)
            }
            .accessibilityIdentifier("action.store.favorites")
        case .profile:
            Button(StoreServicesText.resource("Profile"), systemImage: "person.crop.circle") {
                router.push(.profile)
            }
            .accessibilityIdentifier("action.store.profile")
        case .more:
            Menu(StoreServicesText.resource("More"), systemImage: "ellipsis.circle") {
                Button(StoreServicesText.resource("Favorites"), systemImage: "heart") {
                    requestProtected(.openFavorites)
                }
                Button(StoreServicesText.resource("Profile"), systemImage: "person.crop.circle") {
                    router.push(.profile)
                }
            }
            .accessibilityIdentifier("action.store.more")
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

private struct ProductReminderPresentationView: View {
    let productID: Product.ID
    let products: any IProductRepository
    let reminders: any IProductReminderRepository
    let clock: AppClock
    @State private var product: Product?
    @State private var failed = false

    var body: some View {
        Group {
            if let product {
                ProductReminderView(
                    product: product,
                    reminders: reminders,
                    clock: clock
                )
            } else if failed {
                ContentUnavailableView(
                    StoreServicesText.resource("Product unavailable"),
                    systemImage: "exclamationmark.triangle"
                )
            } else {
                ProgressView(StoreServicesText.resource("Loading reminder"))
            }
        }
        .task(id: productID) {
            do {
                let resolved = try await products.product(id: productID)
                try Task.checkCancellation()
                product = resolved
                failed = false
            } catch is CancellationError {
                return
            } catch {
                product = nil
                failed = true
            }
        }
    }
}
