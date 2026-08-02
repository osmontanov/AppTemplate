nonisolated
enum AppFlowActionResult: Equatable, Sendable {
    case unchanged
    case applied(flow: AppFlow, didTransition: Bool)
    case rejected(AppStatePersistenceFailure)
}
