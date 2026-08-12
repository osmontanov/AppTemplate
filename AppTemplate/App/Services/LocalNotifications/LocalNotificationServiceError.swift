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
    case unknownCategory
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
enum LocalNotificationServiceError: Error, Hashable, Sendable {
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

nonisolated extension LocalNotificationServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidIdentifier: "Local notification identifier is invalid."
        case .invalidAuthorizationOptions: "Local notification authorization options are invalid."
        case .invalidContent: "Local notification content is invalid."
        case .invalidTrigger: "Local notification trigger is invalid."
        case .invalidCategory: "Local notification category is invalid."
        case .invalidMetadata: "Local notification metadata is invalid."
        case .invalidDeepLink: "Local notification deep link is invalid."
        case .invalidAttachment: "Local notification attachment is invalid."
        case .unsupportedEnvelopeVersion: "Local notification envelope version is unsupported."
        case .system: "Local notification system operation failed."
        }
    }
}

nonisolated extension LocalNotificationServiceError: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, identifierKind, contentFailure, triggerFailure, categoryFailure
        case attachmentID, attachmentFailure, version, operation, domain, code
    }
    private enum Kind: String, Codable {
        case invalidIdentifier, invalidAuthorizationOptions, invalidContent
        case invalidTrigger, invalidCategory, invalidMetadata, invalidDeepLink
        case invalidAttachment, unsupportedEnvelopeVersion, system
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .invalidIdentifier:
            self = .invalidIdentifier(try container.decode(LocalNotificationIdentifierKind.self, forKey: .identifierKind))
        case .invalidAuthorizationOptions: self = .invalidAuthorizationOptions
        case .invalidContent:
            self = .invalidContent(try container.decode(LocalNotificationContentFailure.self, forKey: .contentFailure))
        case .invalidTrigger:
            self = .invalidTrigger(try container.decode(LocalNotificationTriggerFailure.self, forKey: .triggerFailure))
        case .invalidCategory:
            self = .invalidCategory(try container.decode(LocalNotificationCategoryFailure.self, forKey: .categoryFailure))
        case .invalidMetadata: self = .invalidMetadata
        case .invalidDeepLink: self = .invalidDeepLink
        case .invalidAttachment:
            self = .invalidAttachment(
                try container.decode(LocalNotificationAttachmentID.self, forKey: .attachmentID),
                try container.decode(LocalNotificationAttachmentFailure.self, forKey: .attachmentFailure)
            )
        case .unsupportedEnvelopeVersion:
            self = .unsupportedEnvelopeVersion(try container.decode(Int.self, forKey: .version))
        case .system:
            self = .system(
                operation: try container.decode(LocalNotificationSystemOperation.self, forKey: .operation),
                domain: try container.decode(String.self, forKey: .domain),
                code: try container.decode(Int.self, forKey: .code)
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .invalidIdentifier(kind):
            try container.encode(Kind.invalidIdentifier, forKey: .kind)
            try container.encode(kind, forKey: .identifierKind)
        case .invalidAuthorizationOptions: try container.encode(Kind.invalidAuthorizationOptions, forKey: .kind)
        case let .invalidContent(failure):
            try container.encode(Kind.invalidContent, forKey: .kind); try container.encode(failure, forKey: .contentFailure)
        case let .invalidTrigger(failure):
            try container.encode(Kind.invalidTrigger, forKey: .kind); try container.encode(failure, forKey: .triggerFailure)
        case let .invalidCategory(failure):
            try container.encode(Kind.invalidCategory, forKey: .kind); try container.encode(failure, forKey: .categoryFailure)
        case .invalidMetadata: try container.encode(Kind.invalidMetadata, forKey: .kind)
        case .invalidDeepLink: try container.encode(Kind.invalidDeepLink, forKey: .kind)
        case let .invalidAttachment(id, failure):
            try container.encode(Kind.invalidAttachment, forKey: .kind); try container.encode(id, forKey: .attachmentID); try container.encode(failure, forKey: .attachmentFailure)
        case let .unsupportedEnvelopeVersion(version):
            try container.encode(Kind.unsupportedEnvelopeVersion, forKey: .kind); try container.encode(version, forKey: .version)
        case let .system(operation, domain, code):
            try container.encode(Kind.system, forKey: .kind); try container.encode(operation, forKey: .operation); try container.encode(domain, forKey: .domain); try container.encode(code, forKey: .code)
        }
    }
}
