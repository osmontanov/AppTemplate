import Testing
@testable import AppTemplate

@MainActor
struct AppFlowRouterTests {
    @Test
    func defaultRouterStartsInAuthentication() {
        let router = AppFlowRouter()

        #expect(router.flow == .authentication)
        #expect(router.transition.historyAction == .preserve)
        #expect(router.transition.pendingIntentAction == .preserve)
    }

    @Test
    func mainFlowResetsAndReplaysPendingIntent() {
        let router = AppFlowRouter(flow: .authentication)

        router.setFlow(.main)

        #expect(router.flow == .main)
        #expect(router.transition.historyAction == .reset)
        #expect(router.transition.pendingIntentAction == .replay)
    }

    @Test(arguments: [
        AppFlow.authentication,
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
        let router = AppFlowRouter(flow: .authentication)
        let firstID = router.transition.id

        router.setFlow(.authentication)

        #expect(router.flow == .authentication)
        #expect(router.transition.id != firstID)
        #expect(router.transition.historyAction == .reset)
        #expect(router.transition.pendingIntentAction == .discard)
    }

    @Test(arguments: [
        PendingIntentAction.preserve,
        .replay,
        .discard
    ])
    func policyTransitionResetsWithTheRequestedPendingAction(
        action: PendingIntentAction
    ) {
        let router = AppFlowRouter(flow: .onboarding)
        let previousID = router.transition.id

        router.transitionForPolicy(
            to: .authentication,
            pendingIntentAction: action
        )

        #expect(router.flow == .authentication)
        #expect(router.transition.id != previousID)
        #expect(router.transition.historyAction == .reset)
        #expect(router.transition.pendingIntentAction == action)
    }
}
