import Observation

@MainActor
@Observable
final class AppFlowCoordinator: IAppFlowCoordinator {
    let appFlowRouter: AppFlowRouter
    private let store: AppStateStore

    init(
        store: AppStateStore,
        appFlowRouter: AppFlowRouter
    ) {
        self.store = store
        self.appFlowRouter = appFlowRouter
    }

    func setFlow(_ flow: AppFlow) {
        appFlowRouter.setFlow(flow)
    }

    func completeOnboarding() {
        var state = store.state
        state.hasCompletedOnboarding = true
        synchronize(with: state)
    }

    func restartOnboarding() {
        var state = store.state
        state.hasCompletedOnboarding = false
        synchronize(with: state)
    }

    func signIn() {
        var state = store.state
        state.isAuthenticated = true
        synchronize(with: state)
    }

    func signOut() {
        var state = store.state
        state.isAuthenticated = false
        synchronize(
            with: state,
            nonMainPendingIntentAction: .discard,
            forceTransitionWhenStateChanges: true
        )
    }

    func setMaintenanceEnabled(_ isEnabled: Bool) {
        var state = store.state
        state.isMaintenanceEnabled = isEnabled
        synchronize(with: state)
    }

    private func synchronize(
        with state: AppState,
        nonMainPendingIntentAction: PendingIntentAction = .preserve,
        forceTransitionWhenStateChanges: Bool = false
    ) {
        let didChangeState = store.setState(state) == .persisted
        let targetFlow = AppFlowPolicy.resolve(store.state)
        let mustForceTransition =
            forceTransitionWhenStateChanges && didChangeState

        guard appFlowRouter.flow != targetFlow || mustForceTransition else {
            return
        }

        appFlowRouter.transitionForPolicy(
            to: targetFlow,
            pendingIntentAction: targetFlow == .main
                ? .replay
                : nonMainPendingIntentAction
        )
    }
}
