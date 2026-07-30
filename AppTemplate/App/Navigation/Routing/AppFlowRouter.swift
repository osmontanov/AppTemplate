import Foundation
import Observation

@MainActor
@Observable
final class AppFlowRouter: IAppFlowRouter {
    private(set) var transition: AppFlowTransition

    var flow: AppFlow {
        transition.flow
    }

    init(flow: AppFlow = .authentication) {
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
}
