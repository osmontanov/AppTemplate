nonisolated
enum CheckoutStep: Equatable, Sendable {
    case delivery
    case review
    case success
}

nonisolated
enum CheckoutState: Equatable, Sendable {
    case editing(step: CheckoutStep, model: CheckoutModel)
    case submitting(CheckoutModel)
    case failed(CheckoutModel)
    case success
}
