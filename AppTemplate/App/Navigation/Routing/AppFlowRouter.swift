import Foundation
import Observation

@MainActor
@Observable
final class AppFlowRouter: IAppFlowRouter {
    private(set) var transition: AppFlowTransition

    var flow: AppFlow {
        transition.flow
    }

    private var stableSessionState: StableSessionState = .idle
    private var lastObservedSessionPhase: SessionPhase?

    init(flow: AppFlow = .launching) {
        transition = AppFlowTransition(
            id: UUID(),
            flow: flow,
            historyAction: .preserve,
            pendingIntentAction: .preserve
        )
    }

    func setFlow(_ flow: AppFlow) {
        transition(
            to: flow,
            historyAction: .reset,
            pendingIntentAction: flow == .main ? .replay : .discard
        )
    }

    func synchronizeSession(_ phase: SessionPhase) {
        guard phase != lastObservedSessionPhase else {
            return
        }
        lastObservedSessionPhase = phase

        switch phase {
        case .idle:
            stableSessionState = .idle
            transition(
                to: .launching,
                historyAction: .preserve,
                pendingIntentAction: .preserve
            )
        case .loading:
            transition(
                to: .launching,
                historyAction: .preserve,
                pendingIntentAction: .preserve
            )
        case .unauthenticated:
            let historyAction: AppFlowHistoryAction
            let pendingIntentAction: PendingIntentAction
            switch stableSessionState {
            case .authenticated:
                historyAction = .reset
                pendingIntentAction = .discard
            case .idle:
                historyAction = .reset
                pendingIntentAction = .preserve
            case .unauthenticated:
                historyAction = .preserve
                pendingIntentAction = .preserve
            }
            stableSessionState = .unauthenticated
            transition(
                to: .authentication,
                historyAction: historyAction,
                pendingIntentAction: pendingIntentAction
            )
        case let .authenticated(session):
            let historyAction: AppFlowHistoryAction = switch stableSessionState {
            case .unauthenticated:
                .reset
            case .authenticated, .idle:
                .preserve
            }
            stableSessionState = .authenticated(session)
            transition(
                to: .main,
                historyAction: historyAction,
                pendingIntentAction: .replay
            )
        }
    }

    private func transition(
        to flow: AppFlow,
        historyAction: AppFlowHistoryAction,
        pendingIntentAction: PendingIntentAction
    ) {
        transition = AppFlowTransition(
            id: UUID(),
            flow: flow,
            historyAction: historyAction,
            pendingIntentAction: pendingIntentAction
        )
    }

    private enum StableSessionState: Equatable {
        case idle
        case unauthenticated
        case authenticated(UserSession)
    }
}
