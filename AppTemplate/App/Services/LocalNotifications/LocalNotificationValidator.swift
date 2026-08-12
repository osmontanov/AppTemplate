import Foundation
import CoreGraphics

nonisolated
enum LocalNotificationValidator {
    static func validate(authorization options: LocalNotificationAuthorizationOptions) throws {
        guard !options.isEmpty, options.subtracting(.allowed).isEmpty else {
            throw LocalNotificationServiceError.invalidAuthorizationOptions
        }
    }

    static func validate(foregroundPresentation options: LocalNotificationForegroundPresentation) throws {
        guard options.subtracting(.allowed).isEmpty else {
            throw LocalNotificationServiceError.invalidContent(.invalidForegroundPresentation)
        }
    }

    static func validate(request: LocalNotificationRequest) throws {
        try validate(content: request.content)
        try validate(trigger: request.trigger)
    }

    static func validate(content: LocalNotificationContent) throws {
        for value in [content.title, content.subtitle, content.body] where value.contains("\u{0000}") {
            _ = value
            throw LocalNotificationServiceError.invalidContent(.containsNUL)
        }
        guard content.badge.map({ $0 >= 0 }) ?? true else {
            throw LocalNotificationServiceError.invalidContent(.invalidBadge)
        }
        if let summaryArgument = content.summaryArgument {
            guard hasNonWhitespace(summaryArgument), !containsASCIIControl(summaryArgument) else {
                throw LocalNotificationServiceError.invalidContent(.invalidSummaryArgument)
            }
            guard let summaryArgumentCount = content.summaryArgumentCount, summaryArgumentCount > 0 else {
                throw LocalNotificationServiceError.invalidContent(.invalidSummaryArgumentCount)
            }
        } else if content.summaryArgumentCount != nil {
            throw LocalNotificationServiceError.invalidContent(.invalidSummaryArgumentCount)
        }
        guard content.relevanceScore.map(\.isFinite) ?? true,
              content.relevanceScore.map({ (0...1).contains($0) }) ?? true else {
            throw LocalNotificationServiceError.invalidContent(.invalidRelevanceScore)
        }
        try validate(identifierLike: content.threadIdentifier, failure: .invalidThreadIdentifier)
        try validate(identifierLike: content.targetContentIdentifier, failure: .invalidTargetContentIdentifier)
        if case let .named(resourceName) = content.sound {
            guard !resourceName.isEmpty,
                  !resourceName.contains("/"),
                  !resourceName.contains("\\"),
                  !containsASCIIControl(resourceName) else {
                throw LocalNotificationServiceError.invalidContent(.invalidSoundName)
            }
        }
        try validate(foregroundPresentation: content.foregroundPresentation)
        try validate(metadata: .object(content.metadata))
        var attachmentIDs = Set<LocalNotificationAttachmentID>()
        for attachment in content.attachments {
            guard attachmentIDs.insert(attachment.id).inserted else {
                throw LocalNotificationServiceError.invalidAttachment(attachment.id, .invalidOptions)
            }
            try validate(attachment: attachment)
        }
        let hasText = [content.title, content.subtitle, content.body].contains(where: hasNonWhitespace)
        let observable = hasText || content.badge != nil || content.sound != .none || !content.attachments.isEmpty
        guard observable else {
            throw LocalNotificationServiceError.invalidContent(.notObservable)
        }
    }

    static func validate(trigger: LocalNotificationTrigger) throws {
        try validate(
            trigger: trigger,
            calendar: deterministicCalendar,
            referenceDate: deterministicReferenceDate
        )
    }

    static func validate(
        trigger: LocalNotificationTrigger,
        calendar: Calendar,
        referenceDate: Date
    ) throws {
        switch trigger {
        case .immediate:
            return
        case let .timeInterval(seconds, repeats):
            guard seconds.isFinite, repeats ? seconds >= 60 : seconds > 0 else {
                throw LocalNotificationServiceError.invalidTrigger(.invalidTimeInterval)
            }
        case let .calendar(components, _):
            try validate(calendar: components, fallbackCalendar: calendar, referenceDate: referenceDate)
        }
    }

    static func validate(attachment: LocalNotificationAttachment) throws {
        let options = attachment.options
        if let typeHint = options.typeHint,
           typeHint.isEmpty || containsASCIIControl(typeHint) {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .invalidOptions)
        }
        if let rectangle = options.thumbnailClippingRect {
            let values = [rectangle.origin.x, rectangle.origin.y, rectangle.size.width, rectangle.size.height]
            guard values.allSatisfy(\.isFinite),
                  rectangle.origin.x >= 0,
                  rectangle.origin.y >= 0,
                  rectangle.size.width > 0,
                  rectangle.size.height > 0,
                  rectangle.maxX <= 1,
                  rectangle.maxY <= 1 else {
                throw LocalNotificationServiceError.invalidAttachment(attachment.id, .invalidOptions)
            }
        }
        if let thumbnailTime = options.thumbnailTime,
           !thumbnailTime.isFinite || thumbnailTime < 0 {
            throw LocalNotificationServiceError.invalidAttachment(attachment.id, .invalidOptions)
        }
    }

    static func validate(metadata: LocalNotificationMetadataValue) throws {
        switch metadata {
        case .string, .integer, .boolean, .null:
            return
        case let .double(value):
            guard value.isFinite else { throw LocalNotificationServiceError.invalidMetadata }
        case let .array(values):
            for value in values { try validate(metadata: value) }
        case let .object(values):
            for (key, value) in values {
                guard hasNonWhitespace(key), !containsASCIIControl(key) else {
                    throw LocalNotificationServiceError.invalidMetadata
                }
                try validate(metadata: value)
            }
        }
    }

    static func validate(category: LocalNotificationCategory) throws {
        guard category.actions.count <= 10 else {
            throw LocalNotificationServiceError.invalidCategory(.tooManyActions)
        }
        for text in [category.hiddenPreviewsBodyPlaceholder, category.categorySummaryFormat] {
            if let text, (!hasNonWhitespace(text) || text.contains("\u{0000}")) {
                throw LocalNotificationServiceError.invalidCategory(
                    text == category.hiddenPreviewsBodyPlaceholder ? .invalidHiddenPreviewsBodyPlaceholder : .invalidCategorySummaryFormat
                )
            }
        }
        var actionIDs = Set<LocalNotificationActionID>()
        for action in category.actions {
            guard actionIDs.insert(action.id).inserted else {
                throw LocalNotificationServiceError.invalidCategory(.duplicateActionID)
            }
            switch action {
            case let .button(button):
                try validate(actionTitle: button.title, options: button.options)
            case let .textInput(textInput):
                try validate(actionTitle: textInput.title, options: textInput.options)
                guard !textInput.textInputButtonTitle.isEmpty,
                      !textInput.textInputButtonTitle.contains("\u{0000}") else {
                    throw LocalNotificationServiceError.invalidCategory(.invalidTextInputButtonTitle)
                }
            }
        }
    }

    static func validate(categories: [LocalNotificationCategory]) throws {
        var categoryIDs = Set<LocalNotificationCategoryID>()
        for category in categories {
            guard categoryIDs.insert(category.id).inserted else {
                throw LocalNotificationServiceError.invalidCategory(.duplicateCategoryID)
            }
            try validate(category: category)
        }
    }

    private static func validate(
        calendar components: DateComponents,
        fallbackCalendar: Calendar,
        referenceDate: Date
    ) throws {
        guard components.nanosecond == nil, components.isLeapMonth == nil else {
            throw LocalNotificationServiceError.invalidTrigger(.unsupportedCalendarComponent)
        }
        let supported = components.era != nil || components.year != nil || components.month != nil ||
            components.day != nil || components.hour != nil || components.minute != nil ||
            components.second != nil || components.weekday != nil || components.weekdayOrdinal != nil ||
            components.weekOfMonth != nil || components.weekOfYear != nil ||
            components.yearForWeekOfYear != nil || components.quarter != nil
        guard supported else {
            throw LocalNotificationServiceError.invalidTrigger(.missingCalendarComponent)
        }
        let calendar = components.calendar ?? fallbackCalendar
        guard calendar.nextDate(after: referenceDate, matching: components, matchingPolicy: .strict) != nil else {
            throw LocalNotificationServiceError.invalidTrigger(.noNextTriggerDate)
        }
    }

    private static let deterministicReferenceDate = Date(timeIntervalSince1970: 1_700_000_000)
    private static let deterministicCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static func validate(identifierLike value: String?, failure: LocalNotificationContentFailure) throws {
        guard let value else { return }
        guard (1...256).contains(value.utf8.count), hasNonWhitespace(value), !containsASCIIControl(value) else {
            throw LocalNotificationServiceError.invalidContent(failure)
        }
    }

    private static func validate(actionTitle: String, options: LocalNotificationActionOptions) throws {
        guard !actionTitle.isEmpty, !actionTitle.contains("\u{0000}") else {
            throw LocalNotificationServiceError.invalidCategory(.invalidActionTitle)
        }
        guard options.subtracting(.allowed).isEmpty else {
            throw LocalNotificationServiceError.invalidCategory(.invalidActionOptions)
        }
    }

    private static func hasNonWhitespace(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func containsASCIIControl(_ value: String) -> Bool {
        LocalNotificationIdentifierValidator.containsASCIIControl(value)
    }
}
