import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AppSceneNavigationLifecycleTests {
    @Test
    func restoreAppliesTypedStateBeforeCurrentTransition() throws {
        let stored = makeRouter(selectedSection: .services)
        stored.store.push(.product(8))
        stored.services.open(.appInfo)
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())

        #expect(
            lifecycle.restore(
                from: try NavigationSnapshotCodec.encode(stored.snapshot)
            ) == nil
        )
        #expect(lifecycle.hasRestored)
        #expect(lifecycle.restorationResult == .restored)
        #expect(lifecycle.presentation().selectedSection == .services)
        #expect(lifecycle.presentation().storePath == [.product(8)])
        #expect(lifecycle.presentation().servicesPath == [.appInfo])
    }

    @Test
    func newestValidLinkAloneAppliesAfterRestoration() throws {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())

        #expect(
            lifecycle.receive(
                try #require(URL(string: "apptemplate://store/product/7"))
            ) == nil
        )
        #expect(
            lifecycle.receive(
                try #require(URL(string: "apptemplate://store/product/9"))
            ) == nil
        )
        #expect(lifecycle.presentation().hasDeferredLink)

        let persisted = lifecycle.restore(from: nil)

        #expect(lifecycle.presentation().storePath.isEmpty)
        #expect(lifecycle.presentation().hasDeferredLink)
        #expect(persisted == nil)

        #expect(lifecycle.reconcile(.init(state: .guest, revision: 1)) == nil)
        #expect(lifecycle.presentation().storePath == [.product(9)])
        #expect(!lifecycle.presentation().hasDeferredLink)
    }

    @Test
    func protectedFavoritesLinkQueuesAfterGuestReadinessWithoutPersistingRoute() throws {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())
        _ = lifecycle.receive(try #require(URL(string: "apptemplate://store/favorites")))
        _ = lifecycle.restore(from: nil)

        _ = lifecycle.reconcile(.init(state: .guest, revision: 1))

        #expect(lifecycle.presentation().storePath.isEmpty)
        #expect(lifecycle.presentation().hasPendingProtectedAction)
        #expect(lifecycle.router.store.presentation == .authentication)
        #expect(lifecycle.snapshot.storePath.isEmpty)
    }

    @Test
    func publicProfileLinkAppliesForGuest() throws {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())
        _ = lifecycle.receive(try #require(URL(string: "apptemplate://store/profile")))
        _ = lifecycle.restore(from: nil)

        _ = lifecycle.reconcile(.init(state: .guest, revision: 1))

        #expect(lifecycle.presentation().storePath == [.profile])
        #expect(!lifecycle.presentation().hasPendingProtectedAction)
    }

    @Test
    func invalidLinkHasZeroRouteOrDeferredMutation() throws {
        let lifecycle = AppSceneNavigationLifecycle(
            router: makeRouter(selectedSection: .services)
        )
        _ = lifecycle.restore(from: nil)
        lifecycle.router.store.push(.cart)
        lifecycle.router.services.open(.keychain)
        let snapshotBefore = lifecycle.snapshot

        #expect(
            lifecycle.receive(
                try #require(URL(string: "apptemplate://legacy/private"))
            ) == nil
        )

        #expect(lifecycle.snapshot == snapshotBefore)
        #expect(!lifecycle.presentation().hasDeferredLink)
        #expect(
            lifecycle.presentation().deepLinkFailure
                == DeepLinkFailurePresentation(reason: .unsupportedHost)
        )
    }

    @Test
    func invalidLinkDoesNotEraseLatestValidDeferredIntent() throws {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())
        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://store/product/7"))
        )
        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://legacy/private"))
        )

        #expect(lifecycle.presentation().hasDeferredLink)
        #expect(
            lifecycle.presentation().deepLinkFailure
                == DeepLinkFailurePresentation(reason: .unsupportedHost)
        )

        _ = lifecycle.restore(from: nil)
        #expect(lifecycle.presentation().storePath.isEmpty)
        #expect(lifecycle.presentation().hasDeferredLink)
        _ = lifecycle.reconcile(.init(state: .guest, revision: 1))
        #expect(lifecycle.presentation().storePath == [.product(7)])
    }

    @Test
    func immediateNewLinkSupersedesAnOlderDeferredLink() throws {
        let flow = AppFlowRouter(flow: .restoring)
        let lifecycle = AppSceneNavigationLifecycle(
            router: AppRouter(appFlowRouter: flow)
        )
        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://store/product/7"))
        )
        _ = lifecycle.restore(from: nil)
        #expect(lifecycle.presentation().hasDeferredLink)

        _ = lifecycle.reconcile(.init(state: .guest, revision: 1))

        flow.transitionForPolicy(to: .main, pendingIntentAction: .replay)
        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://store/product/9"))
        )
        #expect(lifecycle.presentation().storePath == [.product(9)])
        #expect(!lifecycle.presentation().hasDeferredLink)

        _ = lifecycle.apply(flow.transition)
        #expect(lifecycle.presentation().storePath == [.product(9)])
    }

    @Test
    func validLinkDefersOutsideMainThenReplaysOnMainTransition() throws {
        let flow = AppFlowRouter(flow: .maintenance)
        let lifecycle = AppSceneNavigationLifecycle(
            router: AppRouter(appFlowRouter: flow)
        )
        _ = lifecycle.restore(from: nil)
        _ = lifecycle.reconcile(.init(state: .guest, revision: 1))

        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://services/remote-api"))
        )
        #expect(lifecycle.presentation().hasDeferredLink)
        #expect(lifecycle.presentation().servicesPath.isEmpty)

        flow.transitionForPolicy(to: .main, pendingIntentAction: .replay)
        #expect(lifecycle.apply(flow.transition) == .applied)
        #expect(lifecycle.presentation().selectedSection == .services)
        #expect(lifecycle.presentation().servicesPath == [.remoteAPI])
        #expect(!lifecycle.presentation().hasDeferredLink)
    }

    @Test
    func validLinkClearsStaleFailureWhetherDeferredOrImmediate() throws {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())
        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://legacy/private"))
        )
        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://store/profile"))
        )
        #expect(lifecycle.presentation().deepLinkFailure == nil)

        _ = lifecycle.restore(from: nil)
        _ = lifecycle.reconcile(.init(state: .guest, revision: 1))
        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://services/app-info"))
        )
        #expect(lifecycle.presentation().deepLinkFailure == nil)
        #expect(lifecycle.presentation().servicesPath == [.appInfo])
    }

    @Test
    func futureSchemaSuppressesSnapshotWrites() {
        let lifecycle = AppSceneNavigationLifecycle(
            router: makeRouter(selectedSection: .services)
        )
        let future = Data(#"{"schemaVersion":99,"future":"keep"}"#.utf8)

        #expect(lifecycle.restore(from: future) == nil)
        #expect(lifecycle.restorationResult == .preservedFutureSchema(99))
        #expect(lifecycle.snapshotForPersistence == nil)
    }

    @Test
    func policyTransitionPreservesTypedHistories() {
        let flow = AppFlowRouter(flow: .main)
        let router = AppRouter(appFlowRouter: flow)
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        _ = lifecycle.restore(from: nil)
        _ = lifecycle.reconcile(.init(state: .guest, revision: 1))
        router.store.push(.profile)
        router.services.open(.localNotifications)

        flow.transitionForPolicy(to: .maintenance, pendingIntentAction: .preserve)
        _ = lifecycle.apply(flow.transition)

        #expect(router.store.path == [.profile])
        #expect(router.services.path == [.localNotifications])
    }

    @Test
    func persistedTransitionCheckpointPreventsDuplicateReset() throws {
        let flow = AppFlowRouter(flow: .main)
        flow.setFlow(.restoring)
        let original = AppSceneNavigationLifecycle(
            router: AppRouter(appFlowRouter: flow)
        )
        _ = original.restore(from: nil, applying: flow.transition)
        _ = original.reconcile(.init(state: .guest, revision: 1))
        original.router.store.push(.cart)
        let data = try NavigationSnapshotCodec.encode(original.snapshot)
        let recreated = AppSceneNavigationLifecycle(
            router: AppRouter(appFlowRouter: flow)
        )

        _ = recreated.restore(from: data, applying: flow.transition)

        #expect(recreated.router.store.path == [.cart])
        #expect(recreated.apply(flow.transition) == nil)
        #expect(recreated.presentation().checkpoint == flow.transition.id)
    }

    @Test
    func lifecycleOwnsTypedSceneNavigationWithoutNotificationConformance() {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())
        _ = lifecycle.restore(from: nil)
        _ = lifecycle.reconcile(.init(state: .guest, revision: 1))
        lifecycle.handleSampleIntent(.openProduct(12))

        #expect(lifecycle.presentation().selectedSection == .store)
        #expect(lifecycle.presentation().storePath == [.product(12)])
    }

    @Test
    func restoringSessionDoesNotMakeSceneReadyOrReplayDeferredLink() throws {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())
        _ = lifecycle.receive(
            try #require(URL(string: "apptemplate://store/product/9"))
        )

        _ = lifecycle.restore(from: nil)
        #expect(
            lifecycle.reconcile(.init(state: .restoring, revision: 1)) == nil
        )

        #expect(!lifecycle.isNavigationReady)
        #expect(lifecycle.presentation().hasDeferredLink)
        #expect(lifecycle.presentation().storePath.isEmpty)
        #expect(lifecycle.router.store.lastAppliedSessionRevision == 1)

        #expect(lifecycle.reconcile(.init(state: .guest, revision: 1)) == nil)
        #expect(!lifecycle.isNavigationReady)
        #expect(lifecycle.presentation().hasDeferredLink)

        #expect(lifecycle.reconcile(.init(state: .guest, revision: 2)) == nil)
        #expect(lifecycle.isNavigationReady)
        #expect(!lifecycle.presentation().hasDeferredLink)
        #expect(lifecycle.presentation().storePath == [.product(9)])
    }

    @Test
    func sceneResetDiscardsProtectedPresentationAndFutureResume() {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())
        let sibling = AppSceneNavigationLifecycle(router: makeRouter())
        _ = lifecycle.restore(from: nil)
        _ = sibling.restore(from: nil)
        _ = lifecycle.reconcile(.init(state: .guest, revision: 1))
        _ = sibling.reconcile(authenticated(userID: 2, revision: 5))
        _ = lifecycle.router.store.requestProtected(.favorite(7), session: .guest)
        lifecycle.router.store.cacheAccountPresentation(account(userID: 1))
        lifecycle.router.services.open(.appInfo)
        sibling.router.store.path = [.profile, .favorites, .product(8)]
        _ = sibling.router.store.requestProtected(.openFavorites, session: .guest)
        sibling.router.store.presentation = .reminder(8)
        _ = sibling.router.store.selectProfileSection(
            .account,
            session: authenticated(userID: 2, revision: 5).state
        )
        sibling.router.store.cacheAccountPresentation(account(userID: 2))

        lifecycle.resetNavigationInCurrentScene()

        #expect(lifecycle.presentation().storePath.isEmpty)
        #expect(lifecycle.presentation().servicesPath.isEmpty)
        #expect(lifecycle.router.store.presentation == nil)
        #expect(lifecycle.router.store.pendingProtectedAction == nil)
        #expect(lifecycle.router.store.profileSection == .overview)
        #expect(lifecycle.router.store.cachedAccountPresentation == nil)
        #expect(
            lifecycle.reconcile(authenticated(userID: 1, revision: 2)) == nil
        )
        #expect(sibling.router.store.path == [.profile, .favorites, .product(8)])
        #expect(sibling.router.store.presentation == .reminder(8))
        #expect(sibling.router.store.pendingProtectedAction == .openFavorites)
        #expect(sibling.router.store.profileSection == .account)
        #expect(sibling.router.store.cachedAccountPresentation?.userID == 2)
        #expect(sibling.router.store.lastAppliedSessionRevision == 5)
        #expect(sibling.reconcile(authenticated(userID: 2, revision: 6)) == nil)
        #expect(sibling.router.store.path == [.profile, .favorites, .product(8)])
        #expect(sibling.router.store.pendingProtectedAction == .openFavorites)
    }

    @Test
    func twoScenesReconcileAndConsumeIndependently() {
        let first = AppSceneNavigationLifecycle(router: makeRouter())
        let second = AppSceneNavigationLifecycle(router: makeRouter())
        _ = first.restore(from: nil)
        _ = second.restore(from: nil)
        let guest = SessionPresentation(state: .guest, revision: 1)
        _ = first.reconcile(guest)
        _ = second.reconcile(guest)
        _ = first.router.store.requestProtected(.favorite(7), session: .guest)
        _ = second.router.store.requestProtected(.openFavorites, session: .guest)
        second.router.store.path = [.profile, .product(8)]
        second.router.store.cacheAccountPresentation(account(userID: 2))
        let authenticated = authenticated(userID: 1, revision: 2)

        #expect(first.reconcile(authenticated) == .favorite(7))
        #expect(second.reconcile(authenticated) == .openFavorites)
        #expect(first.router.store.pendingProtectedAction == nil)
        #expect(second.router.store.pendingProtectedAction == nil)
        #expect(second.router.store.path == [.profile, .product(8)])
        #expect(second.router.store.cachedAccountPresentation?.userID == 2)
        #expect(first.router.store.lastAppliedSessionRevision == 2)
        #expect(second.router.store.lastAppliedSessionRevision == 2)
    }

    @Test
    func pruningOneScenePreservesPublicRoutesAndSiblingState() {
        let first = AppSceneNavigationLifecycle(router: makeRouter())
        let second = AppSceneNavigationLifecycle(router: makeRouter())
        _ = first.restore(from: nil)
        _ = second.restore(from: nil)
        let authenticated = authenticated(userID: 1, revision: 1)
        _ = first.reconcile(authenticated)
        _ = second.reconcile(authenticated)
        first.router.store.path = [.profile, .favorites, .product(7), .cart]
        first.router.services.path = [.keychain]
        second.router.store.path = [.favorites, .product(8)]
        second.router.store.presentation = .checkout
        second.router.store.cacheAccountPresentation(account(userID: 1))

        _ = first.reconcile(.init(state: .guest, revision: 2))

        #expect(first.router.store.path == [.profile, .product(7), .cart])
        #expect(first.router.services.path == [.keychain])
        #expect(second.router.store.path == [.favorites, .product(8)])
        #expect(second.router.store.presentation == .checkout)
        #expect(second.router.store.cachedAccountPresentation?.userID == 1)
        #expect(second.router.store.lastAppliedSessionRevision == 1)
    }

    private func authenticated(
        userID: Int,
        revision: UInt64
    ) -> SessionPresentation {
        SessionPresentation(
            state: .authenticated(
                UserProfile(
                    id: userID,
                    username: "user\(userID)",
                    firstName: "User",
                    lastName: "\(userID)",
                    imageURL: nil
                ),
                availability: .online
            ),
            revision: revision
        )
    }

    private func account(userID: Int) -> ProfileAccountPresentation {
        ProfileAccountPresentation(
            userID: userID,
            displayName: "User \(userID)",
            availability: .online
        )
    }

    private func makeRouter(
        selectedSection: AppSection = .store
    ) -> AppRouter {
        AppRouter(
            appFlowRouter: AppFlowRouter(flow: .main),
            selectedSection: selectedSection
        )
    }
}
