import Foundation

nonisolated
enum AppFlowHistoryAction: Equatable, Sendable {
    case preserve
    case reset
}

nonisolated
enum PendingIntentAction: Equatable, Sendable {
    case preserve
    case replay
    case discard
}

nonisolated
struct AppFlowTransition: Equatable, Sendable {
    let id: UUID
    let flow: AppFlow
    let historyAction: AppFlowHistoryAction
    let pendingIntentAction: PendingIntentAction
}
