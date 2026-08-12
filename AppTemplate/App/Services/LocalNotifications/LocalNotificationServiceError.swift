import Foundation

nonisolated
enum LocalNotificationContentFailure: String, Codable, CaseIterable, Hashable, Sendable {
    case notObservable
    case containsNUL
    case invalidBadge
    case invalidSummaryArgument
    case invalidSummaryArgumentCount
    case invalidRelevanceScore
    case invalidSoundName
    case invalidThreadIdentifier
    case invalidTargetContentIdentifier
    case invalidForegroundPresentation
}

nonisolated
enum LocalNotificationTriggerFailure: String, Codable, CaseIterable, Hashable, Sendable {
    case invalidTimeInterval
    case missingCalendarComponent
    case unsupportedCalendarComponent
    case noNextTriggerDate
}

nonisolated
enum LocalNotificationCategoryFailure: String, Codable, CaseIterable, Hashable, Sendable {
    case duplicateCategoryID
    case duplicateActionID
    case tooManyActions
    case invalidActionTitle
    case invalidTextInputButtonTitle
    case invalidHiddenPreviewsBodyPlaceholder
    case invalidCategorySummaryFormat
    case invalidActionOptions
}

nonisolated
enum LocalNotificationAttachmentFailure: String, Codable, CaseIterable, Hashable, Sendable {
    case notFileURL
    case missing
    case unreadable
    case notRegularFile
    case symbolicLink
    case unsupportedType
    case invalidOptions
    case stagingFailed
    case systemRejected
}

nonisolated
enum LocalNotificationSystemOperation: String, Codable, CaseIterable, Hashable, Sendable {
    case authorization
    case setCategories
    case schedule
    case setBadge
}

nonisolated
enum LocalNotificationServiceError: Error, Equatable, Sendable {
    case invalidIdentifier(LocalNotificationIdentifierKind)
    case invalidAuthorizationOptions
    case invalidContent(LocalNotificationContentFailure)
    case invalidTrigger(LocalNotificationTriggerFailure)
    case invalidCategory(LocalNotificationCategoryFailure)
    case invalidMetadata
    case invalidDeepLink
    case invalidAttachment(LocalNotificationAttachmentID, LocalNotificationAttachmentFailure)
    case unsupportedEnvelopeVersion(Int)
    case system(operation: LocalNotificationSystemOperation, domain: String, code: Int)
}
