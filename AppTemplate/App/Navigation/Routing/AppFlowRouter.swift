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
            let action: AppFlowHistoryAction = switch stableSessionState {
            case .authenticated, .idle:
                .reset
            case .unauthenticated:
                .preserve
            }
            stableSessionState = .unauthenticated
            transition(
                to: .authentication,
                historyAction: action,
                pendingIntentAction: action == .reset ? .discard : .preserve
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
