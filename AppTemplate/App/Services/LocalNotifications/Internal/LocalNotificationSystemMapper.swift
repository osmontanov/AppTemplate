import CoreGraphics
import Foundation
import UserNotifications

nonisolated
enum LocalNotificationSystemMapperError: Error, Hashable, Sendable {
    case unsupportedTrigger
    case attachmentRejected(String)
    case noNextTriggerDate
}

nonisolated
enum LocalNotificationSystemMapper {
    typealias NotificationAttachmentFactory = (
        LocalNotificationSystemAttachment
    ) throws -> UNNotificationAttachment

    static let envelopeKey = "AppTemplate.LocalNotification.envelope"

    static func authorizationOptions(
        _ options: LocalNotificationAuthorizationOptions
    ) -> UNAuthorizationOptions {
        var result: UNAuthorizationOptions = []
        if options.contains(.alert) { result.insert(.alert) }
        if options.contains(.sound) { result.insert(.sound) }
        if options.contains(.badge) { result.insert(.badge) }
        if options.contains(.provisional) { result.insert(.provisional) }
        return result
    }

    static func authorizationStatus(
        _ status: UNAuthorizationStatus?
    ) -> LocalNotificationAuthorizationStatus {
        guard let status else { return .notSupported }
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
#if os(iOS)
        case .ephemeral: return .ephemeral
#endif
        @unknown default: return .unknown
        }
    }

    static func settingState(
        _ setting: UNNotificationSetting
    ) -> LocalNotificationSettingState {
        switch setting {
        case .notSupported: .notSupported
        case .disabled: .disabled
        case .enabled: .enabled
        @unknown default: .unknown
        }
    }

    static func alertStyle(_ style: UNAlertStyle?) -> LocalNotificationAlertStyle {
        guard let style else { return .notSupported }
        switch style {
        case .none: return .none
        case .banner: return .banner
        case .alert: return .alert
        @unknown default: return .unknown
        }
    }

    static func previewSetting(
        _ setting: UNShowPreviewsSetting?
    ) -> LocalNotificationPreviewSetting {
        guard let setting else { return .notSupported }
        switch setting {
        case .always: return .always
        case .whenAuthenticated: return .whenAuthenticated
        case .never: return .never
        @unknown default: return .unknown
        }
    }

    static func settings(_ settings: UNNotificationSettings) -> LocalNotificationSettings {
        LocalNotificationSettings(
            authorizationStatus: authorizationStatus(settings.authorizationStatus),
            alertSetting: settingState(settings.alertSetting),
            soundSetting: settingState(settings.soundSetting),
            badgeSetting: settingState(settings.badgeSetting),
            notificationCenterSetting: settingState(settings.notificationCenterSetting),
            lockScreenSetting: settingState(settings.lockScreenSetting),
            alertStyle: alertStyle(settings.alertStyle),
            previewSetting: previewSetting(settings.showPreviewsSetting)
        )
    }

    static func presentationOptions(
        _ options: LocalNotificationForegroundPresentation
    ) -> UNNotificationPresentationOptions {
        var result: UNNotificationPresentationOptions = []
        if options.contains(.banner) { result.insert(.banner) }
        if options.contains(.list) { result.insert(.list) }
        if options.contains(.sound) { result.insert(.sound) }
        if options.contains(.badge) { result.insert(.badge) }
        return result
    }

    static func interruptionLevel(
        _ level: LocalNotificationInterruptionLevel
    ) -> UNNotificationInterruptionLevel {
        switch level {
        case .passive: .passive
        case .active: .active
        }
    }

    static func notificationContent(
        _ content: LocalNotificationSystemContent,
        attachmentFactory: NotificationAttachmentFactory = notificationAttachment
    ) throws -> UNMutableNotificationContent {
        let mapped = UNMutableNotificationContent()
        mapped.title = content.title
        mapped.subtitle = content.subtitle
        mapped.body = content.body
        mapped.badge = content.badge.map(NSNumber.init(value:))
        mapped.sound = notificationSound(content.sound)
        mapped.categoryIdentifier = content.categoryIdentifier ?? ""
        mapped.threadIdentifier = content.threadIdentifier ?? ""
        mapped.targetContentIdentifier = content.targetContentIdentifier
        setSummaryFields(content, on: mapped)
        if let relevanceScore = content.relevanceScore {
            mapped.relevanceScore = relevanceScore
        }
        mapped.interruptionLevel = interruptionLevel(content.interruptionLevel)
        var mappedAttachments: [UNNotificationAttachment] = []
        mappedAttachments.reserveCapacity(content.attachments.count)
        for attachment in content.attachments {
            do {
                mappedAttachments.append(try attachmentFactory(attachment))
            } catch {
                throw LocalNotificationSystemMapperError.attachmentRejected(
                    attachment.identifier
                )
            }
        }
        mapped.attachments = mappedAttachments
        if let envelopeData = content.envelopeData {
            mapped.userInfo = [envelopeKey: envelopeData]
        }
        return mapped
    }

    static func notificationAttachment(
        _ attachment: LocalNotificationSystemAttachment
    ) throws -> UNNotificationAttachment {
        try UNNotificationAttachment(
            identifier: attachment.identifier,
            url: attachment.fileURL,
            options: notificationAttachmentOptions(attachment)
        )
    }

    static func notificationAttachmentOptions(
        _ attachment: LocalNotificationSystemAttachment
    ) -> [AnyHashable: Any] {
        var options: [AnyHashable: Any] = [:]
        if let typeHint = attachment.options.typeHint ?? attachment.typeIdentifier {
            options[UNNotificationAttachmentOptionsTypeHintKey] = typeHint
        }
        if attachment.options.hidesThumbnail {
            options[UNNotificationAttachmentOptionsThumbnailHiddenKey] = true
        }
        if let clippingRect = attachment.options.thumbnailClippingRect {
            options[UNNotificationAttachmentOptionsThumbnailClippingRectKey] =
                CGRectCreateDictionaryRepresentation(clippingRect)
        }
        if let thumbnailTime = attachment.options.thumbnailTime {
            options[UNNotificationAttachmentOptionsThumbnailTimeKey] = thumbnailTime
        }
        return options
    }

    static func systemAttachment(
        _ attachment: UNNotificationAttachment
    ) -> LocalNotificationSystemAttachment {
        LocalNotificationSystemAttachment(
            identifier: attachment.identifier,
            fileURL: attachment.url,
            typeIdentifier: attachment.type
        )
    }

    static func notificationTrigger(
        _ trigger: LocalNotificationSystemTrigger
    ) throws -> UNNotificationTrigger? {
        switch trigger {
        case .immediate:
            return nil
        case let .timeInterval(seconds, repeats):
            return UNTimeIntervalNotificationTrigger(
                timeInterval: seconds,
                repeats: repeats
            )
        case let .calendar(components, repeats):
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: repeats
            )
            guard trigger.nextTriggerDate() != nil else {
                throw LocalNotificationSystemMapperError.noNextTriggerDate
            }
            return trigger
        case .unknown:
            throw LocalNotificationSystemMapperError.unsupportedTrigger
        }
    }

    static func systemTrigger(
        _ trigger: UNNotificationTrigger?
    ) -> LocalNotificationSystemTrigger {
        guard let trigger else { return .immediate }
        if let interval = trigger as? UNTimeIntervalNotificationTrigger {
            return .timeInterval(seconds: interval.timeInterval, repeats: interval.repeats)
        }
        if let calendar = trigger as? UNCalendarNotificationTrigger {
            return .calendar(calendar.dateComponents, repeats: calendar.repeats)
        }
        return .unknown
    }

    static func notificationRequest(
        _ request: LocalNotificationSystemRequest,
        attachmentFactory: NotificationAttachmentFactory = notificationAttachment
    ) throws -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: request.identifier,
            content: try notificationContent(
                request.content,
                attachmentFactory: attachmentFactory
            ),
            trigger: try notificationTrigger(request.trigger)
        )
    }

    static func systemRequest(
        _ request: UNNotificationRequest
    ) -> LocalNotificationSystemRequest {
        LocalNotificationSystemRequest(
            identifier: request.identifier,
            content: systemContent(request.content),
            trigger: systemTrigger(request.trigger),
            nextTriggerDate: nextTriggerDate(request.trigger)
        )
    }

    static func systemDelivered(_ notification: UNNotification) -> LocalNotificationSystemDelivered {
        LocalNotificationSystemDelivered(
            request: systemRequest(notification.request),
            deliveredAt: notification.date
        )
    }

    static func notificationCategory(
        _ category: LocalNotificationSystemCategory
    ) -> UNNotificationCategory {
        let actions = category.actions.map(notificationAction)
        let options = categoryOptions(category)
#if os(iOS)
        return UNNotificationCategory(
            identifier: category.identifier,
            actions: actions,
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: category.hiddenPreviewsBodyPlaceholder,
            categorySummaryFormat: category.categorySummaryFormat,
            options: options
        )
#else
        return UNNotificationCategory(
            identifier: category.identifier,
            actions: actions,
            intentIdentifiers: [],
            options: options
        )
#endif
    }

    static func systemCategory(_ category: UNNotificationCategory) -> LocalNotificationSystemCategory {
#if os(iOS)
        let hiddenPreviewsBodyPlaceholder: String? = category.hiddenPreviewsBodyPlaceholder
        let categorySummaryFormat: String? = category.categorySummaryFormat
#else
        let hiddenPreviewsBodyPlaceholder: String? = nil
        let categorySummaryFormat: String? = nil
#endif
        return LocalNotificationSystemCategory(
            identifier: category.identifier,
            actions: category.actions.compactMap(systemAction),
            hiddenPreviewsBodyPlaceholder: hiddenPreviewsBodyPlaceholder,
            categorySummaryFormat: categorySummaryFormat,
            hiddenPreviewsShowTitle: category.options.contains(.hiddenPreviewsShowTitle),
            hiddenPreviewsShowSubtitle: category.options.contains(.hiddenPreviewsShowSubtitle),
            reportsDismissal: category.options.contains(.customDismissAction)
        )
    }

    private static func notificationSound(
        _ sound: LocalNotificationSystemSound
    ) -> UNNotificationSound? {
        switch sound {
        case .none: nil
        case .default: .default
        case let .named(resourceName):
            UNNotificationSound(named: .init(rawValue: resourceName))
        }
    }

    private static func systemContent(
        _ content: UNNotificationContent
    ) -> LocalNotificationSystemContent {
        let summary = summaryFields(from: content)
        return LocalNotificationSystemContent(
            title: content.title,
            subtitle: content.subtitle,
            body: content.body,
            badge: content.badge?.intValue,
            sound: content.sound == nil ? .none : .default,
            categoryIdentifier: nilIfEmpty(content.categoryIdentifier),
            threadIdentifier: nilIfEmpty(content.threadIdentifier),
            targetContentIdentifier: content.targetContentIdentifier,
            summaryArgument: nilIfEmpty(summary.argument),
            summaryArgumentCount: summary.argument.isEmpty ? nil : summary.count,
            relevanceScore: content.relevanceScore,
            interruptionLevel: content.interruptionLevel == .passive ? .passive : .active,
            attachments: content.attachments.map(systemAttachment),
            envelopeData: content.userInfo[envelopeKey] as? Data
        )
    }

    private static func notificationAction(
        _ action: LocalNotificationSystemAction
    ) -> UNNotificationAction {
        switch action {
        case let .button(button):
            UNNotificationAction(
                identifier: button.identifier,
                title: button.title,
                options: notificationActionOptions(button.options)
            )
        case let .textInput(text):
            UNTextInputNotificationAction(
                identifier: text.identifier,
                title: text.title,
                options: notificationActionOptions(text.options),
                textInputButtonTitle: text.textInputButtonTitle,
                textInputPlaceholder: text.textInputPlaceholder ?? ""
            )
        }
    }

    private static func systemAction(
        _ action: UNNotificationAction
    ) -> LocalNotificationSystemAction? {
        let options = systemActionOptions(action.options)
        if let text = action as? UNTextInputNotificationAction {
            return .textInput(.init(
                identifier: text.identifier,
                title: text.title,
                options: options,
                textInputButtonTitle: text.textInputButtonTitle,
                textInputPlaceholder: nilIfEmpty(text.textInputPlaceholder)
            ))
        }
        return .button(.init(
            identifier: action.identifier,
            title: action.title,
            options: options
        ))
    }

    private static func notificationActionOptions(
        _ options: LocalNotificationActionOptions
    ) -> UNNotificationActionOptions {
        var result: UNNotificationActionOptions = []
        if options.contains(.foreground) { result.insert(.foreground) }
        if options.contains(.destructive) { result.insert(.destructive) }
        if options.contains(.authenticationRequired) { result.insert(.authenticationRequired) }
        return result
    }

    private static func systemActionOptions(
        _ options: UNNotificationActionOptions
    ) -> LocalNotificationActionOptions {
        var result: LocalNotificationActionOptions = []
        if options.contains(.foreground) { result.insert(.foreground) }
        if options.contains(.destructive) { result.insert(.destructive) }
        if options.contains(.authenticationRequired) { result.insert(.authenticationRequired) }
        return result
    }

    private static func categoryOptions(
        _ category: LocalNotificationSystemCategory
    ) -> UNNotificationCategoryOptions {
        var result: UNNotificationCategoryOptions = []
        if category.hiddenPreviewsShowTitle { result.insert(.hiddenPreviewsShowTitle) }
        if category.hiddenPreviewsShowSubtitle { result.insert(.hiddenPreviewsShowSubtitle) }
        if category.reportsDismissal { result.insert(.customDismissAction) }
        return result
    }

    private static func nilIfEmpty(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }

    private static func nextTriggerDate(_ trigger: UNNotificationTrigger?) -> Date? {
        switch trigger {
        case let interval as UNTimeIntervalNotificationTrigger:
            interval.nextTriggerDate()
        case let calendar as UNCalendarNotificationTrigger:
            calendar.nextTriggerDate()
        default:
            nil
        }
    }

    private static func setSummaryFields(
        _ content: LocalNotificationSystemContent,
        on mapped: UNMutableNotificationContent
    ) {
#if os(iOS)
        // These Objective-C properties remain available but Swift marks them deprecated
        // because modern iOS ignores their presentation effect. Preserve the system DTO.
        mapped.setValue(content.summaryArgument ?? "", forKey: "summaryArgument")
        if let count = content.summaryArgumentCount {
            mapped.setValue(NSNumber(value: count), forKey: "summaryArgumentCount")
        }
#else
        mapped.summaryArgument = content.summaryArgument ?? ""
        if let count = content.summaryArgumentCount {
            mapped.summaryArgumentCount = count
        }
#endif
    }

    private static func summaryFields(
        from content: UNNotificationContent
    ) -> (argument: String, count: Int) {
#if os(iOS)
        let argument = content.value(forKey: "summaryArgument") as? String ?? ""
        let count = (content.value(forKey: "summaryArgumentCount") as? NSNumber)?.intValue ?? 1
        return (argument, count)
#else
        return (content.summaryArgument, content.summaryArgumentCount)
#endif
    }
}
