nonisolated
enum ProductReminderViewError: Equatable, Sendable {
    case invalid(ProductReminderField)
    case authorizationDenied
    case schedule
}

nonisolated
enum ProductReminderState: Equatable, Sendable {
    case editing(model: ProductReminderModel, status: ProductReminderStatus)
    case scheduling(ProductReminderModel)
    case scheduled(ProductReminderScheduleResult)
    case failed(model: ProductReminderModel, error: ProductReminderViewError)
}
