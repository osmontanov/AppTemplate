import Observation

@MainActor
@Observable
final class AppFlowCoordinator: IAppFlowCoordinator {
    let appFlowRouter: AppFlowRouter
    private let store: AppStateStore
    private let legacyAuthentication: LegacyAuthenticationState

    init(
        store: AppStateStore,
        appFlowRouter: AppFlowRouter,
        legacyAuthentication: LegacyAuthenticationState
    ) {
        self.store = store
        self.appFlowRouter = appFlowRouter
        self.legacyAuthentication = legacyAuthentication
    }

    @discardableResult
    func completeOnboarding() -> AppFlowActionResult {
        var state = store.state
        state.hasCompletedOnboarding = true
        return synchronize(with: state)
    }

    @discardableResult
    func restartOnboarding() -> AppFlowActionResult {
        var state = store.state
        state.hasCompletedOnboarding = false
        return synchronize(with: state)
    }

    @discardableResult
    func signIn() -> AppFlowActionResult {
        let didChangeAuthentication = !legacyAuthentication.isAuthenticated
        legacyAuthentication.signIn()
        return transitionForCurrentPolicy(
            didChangeState: didChangeAuthentication
        )
    }

    @discardableResult
    func signOut() -> AppFlowActionResult {
        let didChangeAuthentication = legacyAuthentication.isAuthenticated
        legacyAuthentication.signOut()
        return transitionForCurrentPolicy(
            didChangeState: didChangeAuthentication,
            nonMainPendingIntentAction: .discard,
            forceTransitionWhenStateChanges: true
        )
    }

    @discardableResult
    func setMaintenanceEnabled(_ isEnabled: Bool) -> AppFlowActionResult {
        var state = store.state
        state.isMaintenanceEnabled = isEnabled
        return synchronize(with: state)
    }

    private func synchronize(
        with state: AppState,
        nonMainPendingIntentAction: PendingIntentAction = .preserve,
        forceTransitionWhenStateChanges: Bool = false
    ) -> AppFlowActionResult {
        let didChangeState: Bool
        switch store.setState(state) {
        case .unchanged:
            didChangeState = false
        case .persisted:
            didChangeState = true
        case let .rejected(failure):
            return .rejected(failure)
        }

        return transitionForCurrentPolicy(
            didChangeState: didChangeState,
            nonMainPendingIntentAction: nonMainPendingIntentAction,
            forceTransitionWhenStateChanges: forceTransitionWhenStateChanges
        )
    }

    private func transitionForCurrentPolicy(
        didChangeState: Bool,
        nonMainPendingIntentAction: PendingIntentAction = .preserve,
        forceTransitionWhenStateChanges: Bool = false
    ) -> AppFlowActionResult {
        let targetFlow = AppFlowPolicy.resolve(
            store.state,
            legacyAuthentication: legacyAuthentication
        )
        let mustForceTransition =
            forceTransitionWhenStateChanges && didChangeState
        let didTransition = appFlowRouter.flow != targetFlow
            || mustForceTransition

        guard didTransition else {
            if didChangeState {
                return .applied(flow: targetFlow, didTransition: false)
            }
            return .unchanged
        }

        appFlowRouter.transitionForPolicy(
            to: targetFlow,
            pendingIntentAction: targetFlow == .main
                ? .replay
                : nonMainPendingIntentAction
        )
        return .applied(flow: targetFlow, didTransition: true)
    }
}
