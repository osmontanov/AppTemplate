import Testing
@testable import AppTemplate

@MainActor
struct AppFlowRouterTests {
    @Test
    func defaultRouterStartsInRestoring() {
        let router = AppFlowRouter()

        #expect(router.flow == .restoring)
        #expect(router.transition.historyAction == .preserve)
        #expect(router.transition.pendingIntentAction == .preserve)
    }

    @Test
    func mainFlowResetsAndReplaysPendingIntent() {
        let router = AppFlowRouter(flow: .restoring)

        router.setFlow(.main)

        #expect(router.flow == .main)
        #expect(router.transition.historyAction == .reset)
        #expect(router.transition.pendingIntentAction == .replay)
    }

    @Test(arguments: [
        AppFlow.restoring,
        AppFlow.onboarding,
        AppFlow.maintenance
    ])
    func nonMainFlowResetsAndDiscardsPendingIntent(flow: AppFlow) {
        let router = AppFlowRouter(flow: .main)

        router.setFlow(flow)

        #expect(router.flow == flow)
        #expect(router.transition.historyAction == .reset)
        #expect(router.transition.pendingIntentAction == .discard)
    }

    @Test
    func repeatedExplicitFlowProducesNewResetTransition() {
        let router = AppFlowRouter(flow: .restoring)
        let firstID = router.transition.id

        router.setFlow(.restoring)

        #expect(router.flow == .restoring)
        #expect(router.transition.id != firstID)
        #expect(router.transition.historyAction == .reset)
        #expect(router.transition.pendingIntentAction == .discard)
    }

    @Test(arguments: [
        PendingIntentAction.preserve,
        .replay,
        .discard
    ])
    func policyTransitionPreservesHistoryWithTheRequestedPendingAction(
        action: PendingIntentAction
    ) {
        let router = AppFlowRouter(flow: .onboarding)
        let previousID = router.transition.id

        router.transitionForPolicy(
            to: .restoring,
            pendingIntentAction: action
        )

        #expect(router.flow == .restoring)
        #expect(router.transition.id != previousID)
        #expect(router.transition.historyAction == .preserve)
        #expect(router.transition.pendingIntentAction == action)
    }
}
