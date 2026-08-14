import Foundation

nonisolated
enum ProductReminderSelection: Equatable, Sendable {
    case quickTest
    case interval(seconds: TimeInterval, repeats: Bool)
    case calendar(date: Date, timeZone: TimeZone)
}

nonisolated
enum ProductReminderStatus: Equatable, Sendable {
    case notScheduled
    case scheduled(nextTriggerDate: Date?)
}

nonisolated
enum ProductReminderScheduleWarning: Equatable, Sendable {
    case textOnlyAttachmentFallback
}

nonisolated
enum ProductReminderScheduleResult: Equatable, Sendable {
    case scheduled
    case scheduledWithWarning(ProductReminderScheduleWarning)
}

nonisolated
enum ProductReminderError: Error, Equatable, Sendable {
    case authorizationDenied
    case invalidProductID
    case intervalOutOfRange
    case repeatingIntervalBelowMinimum
    case calendarNotInFuture
    case calendarBeyondOneYear
    case invalidRescheduleSource
    case categoryRegistrationFailed
}

nonisolated
protocol IProductReminderRepository: Sendable {
    func status(productID: Product.ID) async -> ProductReminderStatus
    func schedule(
        product: Product,
        selection: ProductReminderSelection
    ) async throws -> ProductReminderScheduleResult
    func remindLater(
        from source: ProductReminderRescheduleSource,
        after delay: Duration
    ) async throws
    func cancel(productID: Product.ID) async
}
