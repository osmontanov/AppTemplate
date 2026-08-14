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

        #expect(lifecycle.restore(from: try NavigationSnapshotCodec.encode(stored.snapshot)) == nil)
        #expect(lifecycle.hasRestored)
        #expect(lifecycle.restorationResult == .restored)
        #expect(lifecycle.router.selectedSection == .services)
        #expect(lifecycle.router.store.path == [.product(8)])
        #expect(lifecycle.router.services.path == [.appInfo])
    }

    @Test
    func queuedRootLinkAppliesAfterRestoration() throws {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())

        #expect(lifecycle.receive(try #require(URL(string: "apptemplate://services"))) == nil)
        let persisted = lifecycle.restore(from: nil)

        #expect(lifecycle.router.selectedSection == .services)
        #expect(persisted == lifecycle.snapshot)
    }

    @Test
    func invalidLinkFallsBackToMatchingTaskOneRoot() throws {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter(selectedSection: .services))
        lifecycle.router.store.push(.cart)
        lifecycle.router.services.open(.keychain)
        _ = lifecycle.restore(from: nil)

        _ = lifecycle.receive(try #require(URL(string: "apptemplate://store/not-yet-supported")))

        #expect(lifecycle.router.selectedSection == .store)
        #expect(lifecycle.router.store.path.isEmpty)
        #expect(lifecycle.router.services.path == [.keychain])
    }

    @Test
    func futureSchemaSuppressesSnapshotWrites() {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter(selectedSection: .services))
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
        let original = AppSceneNavigationLifecycle(router: AppRouter(appFlowRouter: flow))
        _ = original.restore(from: nil, applying: flow.transition)
        original.router.store.push(.cart)
        let data = try NavigationSnapshotCodec.encode(original.snapshot)
        let recreated = AppSceneNavigationLifecycle(router: AppRouter(appFlowRouter: flow))

        _ = recreated.restore(from: data, applying: flow.transition)

        #expect(recreated.router.store.path == [.cart])
        #expect(recreated.apply(flow.transition) == nil)
    }

    @Test
    func localNotificationReceiverUsesSameSceneLocalRootBridge() throws {
        let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())
        let receiver: any LocalNotificationSceneReceiving = lifecycle
        receiver.receiveLocalNotificationURL(try #require(URL(string: "apptemplate://services")))

        _ = lifecycle.restore(from: nil)

        #expect(lifecycle.router.selectedSection == .services)
    }

    private func makeRouter(selectedSection: AppSection = .store) -> AppRouter {
        AppRouter(appFlowRouter: AppFlowRouter(flow: .main), selectedSection: selectedSection)
    }
}
