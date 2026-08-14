import Observation

@MainActor
@Observable
final class AppFlowCoordinator: IAppFlowCoordinator {
    let appFlowRouter: AppFlowRouter
    private let store: AppStateStore
    private var isLocalSessionBootstrapResolved: Bool

    init(
        store: AppStateStore,
        appFlowRouter: AppFlowRouter,
        isLocalSessionBootstrapResolved: Bool
    ) {
        self.store = store
        self.appFlowRouter = appFlowRouter
        self.isLocalSessionBootstrapResolved = isLocalSessionBootstrapResolved
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

    func setLocalSessionBootstrapResolved(_ isResolved: Bool) {
        guard isLocalSessionBootstrapResolved != isResolved else { return }
        isLocalSessionBootstrapResolved = isResolved
        _ = transitionForCurrentPolicy(didChangeState: true)
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
            isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
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
