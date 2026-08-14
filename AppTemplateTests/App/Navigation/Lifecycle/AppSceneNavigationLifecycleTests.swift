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

        #expect(lifecycle.presentation().storePath == [.product(9)])
        #expect(!lifecycle.presentation().hasDeferredLink)
        #expect(persisted == lifecycle.snapshot)
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
    func localNotificationReceiverUsesSameTypedSceneBridge() throws {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())
        let receiver: any LocalNotificationSceneReceiving = lifecycle
        receiver.receiveLocalNotificationURL(
            try #require(URL(string: "apptemplate://store/product/12"))
        )

        _ = lifecycle.restore(from: nil)

        #expect(lifecycle.presentation().selectedSection == .store)
        #expect(lifecycle.presentation().storePath == [.product(12)])
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
