import Testing
@testable import AppTemplate

@MainActor
struct AppFlowRouterTests {
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

    @Test
    func authenticatedColdRestorePreservesHistories() {
        let router = AppFlowRouter(flow: .launching)
        let session = UserSession(id: "member", displayName: "Member")

        router.synchronizeSession(.loading)
        router.synchronizeSession(.authenticated(session))

        #expect(router.flow == .main)
        #expect(router.transition.historyAction == .preserve)
        #expect(router.transition.pendingIntentAction == .replay)
    }

    @Test
    func newAuthenticationResetsHistories() {
        let router = AppFlowRouter(flow: .launching)
        let session = UserSession(id: "member", displayName: "Member")

        router.synchronizeSession(.unauthenticated)
        router.synchronizeSession(.loading)
        router.synchronizeSession(.authenticated(session))

        #expect(router.flow == .main)
        #expect(router.transition.historyAction == .reset)
        #expect(router.transition.pendingIntentAction == .replay)
    }

    @Test
    func logoutDiscardsPendingNavigation() {
        let router = AppFlowRouter(flow: .launching)
        let session = UserSession(id: "member", displayName: "Member")
        router.synchronizeSession(.authenticated(session))

        router.synchronizeSession(.loading)
        router.synchronizeSession(.unauthenticated)

        #expect(router.flow == .authentication)
        #expect(router.transition.historyAction == .reset)
        #expect(router.transition.pendingIntentAction == .discard)
    }

    @Test
    func duplicateSessionReportIsIdempotent() {
        let router = AppFlowRouter(flow: .launching)
        router.synchronizeSession(.unauthenticated)
        let transition = router.transition

        router.synchronizeSession(.unauthenticated)

        #expect(router.transition == transition)
    }

    @Test
    func failedSignInPreservesAuthenticationHistory() {
        let router = AppFlowRouter(flow: .launching)
        router.synchronizeSession(.unauthenticated)
        router.synchronizeSession(.loading)

        router.synchronizeSession(.unauthenticated)

        #expect(router.flow == .authentication)
        #expect(router.transition.historyAction == .preserve)
        #expect(router.transition.pendingIntentAction == .preserve)
    }

    @Test
    func failedSignOutPreservesMainHistory() {
        let router = AppFlowRouter(flow: .launching)
        let session = UserSession(id: "member", displayName: "Member")
        router.synchronizeSession(.authenticated(session))
        router.synchronizeSession(.loading)

        router.synchronizeSession(.authenticated(session))

        #expect(router.flow == .main)
        #expect(router.transition.historyAction == .preserve)
        #expect(router.transition.pendingIntentAction == .replay)
    }
}
