import Testing
@testable import AppTemplate

@MainActor
struct AppRouterTests {
    @Test
    func typedRoutersOwnIndependentScenePaths() {
        let sharedFlow = AppFlowRouter(flow: .main)
        let first = AppRouter(appFlowRouter: sharedFlow)
        let second = AppRouter(appFlowRouter: sharedFlow)

        first.store.push(.product(1))
        first.services.open(.keychain)

        #expect(first.store.path == [.product(1)])
        #expect(first.services.path == [.keychain])
        #expect(second.store.path.isEmpty)
        #expect(second.services.path.isEmpty)
    }

    @Test
    func rootIntentsSelectAndResetOnlyTheirDestination() {
        let router = makeRouter(selectedSection: .services)
        router.store.push(.cart)
        router.services.open(.appInfo)

        #expect(router.handle(.openStoreRoot) == .applied)
        #expect(router.selectedSection == .store)
        #expect(router.store.path.isEmpty)
        #expect(router.services.path == [.appInfo])

        router.store.push(.profile)
        #expect(router.handle(.openServicesRoot) == .applied)
        #expect(router.selectedSection == .services)
        #expect(router.store.path == [.profile])
        #expect(router.services.path.isEmpty)
    }

    @Test(arguments: [
        (NavigationIntent.openProduct(12), AppSection.store, [StoreRoute.product(12)], []),
        (.openProfile, .store, [.profile], []),
        (.openService(.appState), .services, [], [ServicesRoute.appState]),
        (.openService(.localNotifications), .services, [], [.localNotifications])
    ])
    func typedIntentsSelectAndReplaceOnlyTheirDestination(
        intent: NavigationIntent,
        expectedSection: AppSection,
        expectedStorePath: [StoreRoute],
        expectedServicesPath: [ServicesRoute]
    ) {
        let router = makeRouter(selectedSection: .services)
        router.store.path = [.cart, .profile]
        router.services.path = [.keychain, .remoteAPI]

        #expect(router.handle(intent) == .applied)
        #expect(router.selectedSection == expectedSection)
        if expectedSection == .store {
            #expect(router.store.path == expectedStorePath)
            #expect(router.services.path == [.keychain, .remoteAPI])
        } else {
            #expect(router.store.path == [.cart, .profile])
            #expect(router.services.path == expectedServicesPath)
        }
    }

    @Test
    func favoritesIntentIsProtectedWhileProfileRemainsPublic() {
        let router = makeRouter(selectedSection: .services)
        router.store.path = [.product(4)]

        #expect(router.handle(.openFavorites, session: .guest) == .applied)
        #expect(router.selectedSection == .store)
        #expect(router.store.path == [.product(4)])
        #expect(router.store.pendingProtectedAction == .openFavorites)
        #expect(router.store.presentation == .authentication)

        router.store.cancelAuthentication()
        #expect(router.handle(.openProfile, session: .guest) == .applied)
        #expect(router.store.path == [.profile])
    }

    @Test
    func blockedFavoritesIntentPresentsSafeRecoveryWithoutReplacingPath() {
        let router = makeRouter()
        router.store.path = [.profile, .product(4)]

        _ = router.handle(
            .openFavorites,
            session: .unavailable(.secureStorageCleanupFailed)
        )

        #expect(router.store.path == [.profile, .product(4)])
        #expect(router.store.presentation == .sessionRecovery(.secureStorageCleanupFailed))
    }

    @Test
    func policyTransitionsPreserveHistories() {
        let flow = AppFlowRouter(flow: .main)
        let router = AppRouter(appFlowRouter: flow)
        router.store.push(.product(4))
        router.services.open(.localDatabase)

        flow.transitionForPolicy(to: .maintenance, pendingIntentAction: .preserve)
        _ = router.apply(flow.transition)

        #expect(router.store.path == [.product(4)])
        #expect(router.services.path == [.localDatabase])
    }

    @Test
    func explicitResetTransitionClearsBothTypedHistories() {
        let flow = AppFlowRouter(flow: .main)
        let router = AppRouter(appFlowRouter: flow, selectedSection: .services)
        router.store.push(.favorites)
        router.services.open(.remoteAPI)

        flow.setFlow(.restoring)
        _ = router.apply(flow.transition)

        #expect(router.selectedSection == .store)
        #expect(router.store.path.isEmpty)
        #expect(router.services.path.isEmpty)
    }

    @Test
    func storeRouterReplaceResetAndPresentationAreSceneLocal() {
        let router = StoreRouter(path: [.product(1), .reviews(1)])
        router.presentation = .filters
        router.replace(with: .cart)
        #expect(router.path == [.cart])
        #expect(router.presentation == .filters)
        router.reset()
        #expect(router.path.isEmpty)
        #expect(router.presentation == nil)
    }

    private func makeRouter(selectedSection: AppSection = .store) -> AppRouter {
        AppRouter(appFlowRouter: AppFlowRouter(flow: .main), selectedSection: selectedSection)
    }
}
