import Foundation
import CoreGraphics

nonisolated
enum LocalNotificationAuthorizationStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case notSupported
    case unknown
}

nonisolated
enum LocalNotificationSettingState: String, Codable, CaseIterable, Hashable, Sendable {
    case notSupported
    case disabled
    case enabled
    case unknown
}

nonisolated
enum LocalNotificationAlertStyle: String, Codable, CaseIterable, Hashable, Sendable {
    case none
    case banner
    case alert
    case notSupported
    case unknown
}

nonisolated
enum LocalNotificationPreviewSetting: String, Codable, CaseIterable, Hashable, Sendable {
    case always
    case whenAuthenticated
    case never
    case notSupported
    case unknown
}

nonisolated
struct LocalNotificationSettings: Hashable, Codable, Sendable {
    let authorizationStatus: LocalNotificationAuthorizationStatus
    let alertSetting: LocalNotificationSettingState
    let soundSetting: LocalNotificationSettingState
    let badgeSetting: LocalNotificationSettingState
    let notificationCenterSetting: LocalNotificationSettingState
    let lockScreenSetting: LocalNotificationSettingState
    let alertStyle: LocalNotificationAlertStyle
    let previewSetting: LocalNotificationPreviewSetting

    init(
        authorizationStatus: LocalNotificationAuthorizationStatus,
        alertSetting: LocalNotificationSettingState,
        soundSetting: LocalNotificationSettingState,
        badgeSetting: LocalNotificationSettingState,
        notificationCenterSetting: LocalNotificationSettingState,
        lockScreenSetting: LocalNotificationSettingState,
        alertStyle: LocalNotificationAlertStyle,
        previewSetting: LocalNotificationPreviewSetting
    ) {
        self.authorizationStatus = authorizationStatus
        self.alertSetting = alertSetting
        self.soundSetting = soundSetting
        self.badgeSetting = badgeSetting
        self.notificationCenterSetting = notificationCenterSetting
        self.lockScreenSetting = lockScreenSetting
        self.alertStyle = alertStyle
        self.previewSetting = previewSetting
    }
}

nonisolated
struct LocalNotificationAuthorizationOptions: OptionSet, Hashable, Sendable {
    let rawValue: UInt

    static let alert = Self(rawValue: 1 << 0)
    static let sound = Self(rawValue: 1 << 1)
    static let badge = Self(rawValue: 1 << 2)
    static let provisional = Self(rawValue: 1 << 3)
    static let allowed: Self = [.alert, .sound, .badge, .provisional]

    init(rawValue: UInt) { self.rawValue = rawValue }
}

nonisolated extension LocalNotificationAuthorizationOptions: Codable {
    init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(UInt.self)
        let options = Self(rawValue: rawValue)
        guard (try? LocalNotificationValidator.validate(authorization: options)) != nil else {
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Invalid local notification authorization options")
        }
        self = options
    }

    func encode(to encoder: any Encoder) throws {
        try LocalNotificationValidator.validate(authorization: self)
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated
enum LocalNotificationSound: Hashable, Codable, Sendable {
    case none
    case `default`
    case named(resourceName: String)
}

nonisolated
enum LocalNotificationInterruptionLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case passive
    case active
}

nonisolated
struct LocalNotificationForegroundPresentation: OptionSet, Hashable, Sendable {
    let rawValue: UInt

    static let banner = Self(rawValue: 1 << 0)
    static let list = Self(rawValue: 1 << 1)
    static let sound = Self(rawValue: 1 << 2)
    static let badge = Self(rawValue: 1 << 3)
    static let allowed: Self = [.banner, .list, .sound, .badge]

    init(rawValue: UInt) { self.rawValue = rawValue }
}

nonisolated extension LocalNotificationForegroundPresentation: Codable {
    init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(UInt.self)
        let options = Self(rawValue: rawValue)
        guard (try? LocalNotificationValidator.validate(foregroundPresentation: options)) != nil else {
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Invalid local notification foreground presentation options")
        }
        self = options
    }

    func encode(to encoder: any Encoder) throws {
        try LocalNotificationValidator.validate(foregroundPresentation: self)
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated
struct LocalNotificationAttachmentOptions: Hashable, Codable, Sendable {
    let typeHint: String?
    let hidesThumbnail: Bool
    let thumbnailClippingRect: CGRect?
    let thumbnailTime: TimeInterval?

    init(
        typeHint: String? = nil,
        hidesThumbnail: Bool = false,
        thumbnailClippingRect: CGRect? = nil,
        thumbnailTime: TimeInterval? = nil
    ) {
        self.typeHint = typeHint
        self.hidesThumbnail = hidesThumbnail
        self.thumbnailClippingRect = thumbnailClippingRect
        self.thumbnailTime = thumbnailTime
    }
}

nonisolated
struct LocalNotificationAttachment: Hashable, Codable, Sendable {
    let id: LocalNotificationAttachmentID
    let fileURL: URL
    let options: LocalNotificationAttachmentOptions

    init(id: LocalNotificationAttachmentID, fileURL: URL, options: LocalNotificationAttachmentOptions = .init()) {
        self.id = id
        self.fileURL = fileURL
        self.options = options
    }
}

nonisolated
indirect enum LocalNotificationMetadataValue: Hashable, Sendable {
    case string(String)
    case integer(Int64)
    case double(Double)
    case boolean(Bool)
    case array([LocalNotificationMetadataValue])
    case object([String: LocalNotificationMetadataValue])
    case null
}

nonisolated extension LocalNotificationMetadataValue: Codable {
    private enum CodingKeys: String, CodingKey { case type, value }
    private enum Tag: String, Codable { case string, integer, double, boolean, array, object, null }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Tag.self, forKey: .type) {
        case .string: self = .string(try container.decode(String.self, forKey: .value))
        case .integer: self = .integer(try container.decode(Int64.self, forKey: .value))
        case .double:
            let value = try container.decode(Double.self, forKey: .value)
            guard value.isFinite else {
                throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Metadata double must be finite")
            }
            self = .double(value)
        case .boolean: self = .boolean(try container.decode(Bool.self, forKey: .value))
        case .array: self = .array(try container.decode([Self].self, forKey: .value))
        case .object:
            let value = try container.decode([String: Self].self, forKey: .value)
            guard (try? LocalNotificationValidator.validate(metadata: .object(value))) != nil else {
                throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Invalid metadata object")
            }
            self = .object(value)
        case .null: self = .null
        }
    }

    func encode(to encoder: any Encoder) throws {
        try LocalNotificationValidator.validate(metadata: self)
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .string(value):
            try container.encode(Tag.string, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .integer(value):
            try container.encode(Tag.integer, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .double(value):
            try container.encode(Tag.double, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .boolean(value):
            try container.encode(Tag.boolean, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .array(value):
            try container.encode(Tag.array, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .object(value):
            try container.encode(Tag.object, forKey: .type)
            try container.encode(value, forKey: .value)
        case .null:
            try container.encode(Tag.null, forKey: .type)
        }
    }
}

nonisolated
struct LocalNotificationContent: Hashable, Codable, Sendable {
    let title: String
    let subtitle: String
    let body: String
    let badge: Int?
    let sound: LocalNotificationSound
    let categoryID: LocalNotificationCategoryID?
    let threadIdentifier: String?
    let targetContentIdentifier: String?
    let summaryArgument: String?
    let summaryArgumentCount: Int?
    let relevanceScore: Double?
    let interruptionLevel: LocalNotificationInterruptionLevel
    let attachments: [LocalNotificationAttachment]
    let metadata: [String: LocalNotificationMetadataValue]
    let deepLink: URL?
    let foregroundPresentation: LocalNotificationForegroundPresentation

    init(
        title: String = "",
        subtitle: String = "",
        body: String = "",
        badge: Int? = nil,
        sound: LocalNotificationSound = .none,
        categoryID: LocalNotificationCategoryID? = nil,
        threadIdentifier: String? = nil,
        targetContentIdentifier: String? = nil,
        summaryArgument: String? = nil,
        summaryArgumentCount: Int? = nil,
        relevanceScore: Double? = nil,
        interruptionLevel: LocalNotificationInterruptionLevel = .active,
        attachments: [LocalNotificationAttachment] = [],
        metadata: [String: LocalNotificationMetadataValue] = [:],
        deepLink: URL? = nil,
        foregroundPresentation: LocalNotificationForegroundPresentation = []
    ) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.badge = badge
        self.sound = sound
        self.categoryID = categoryID
        self.threadIdentifier = threadIdentifier
        self.targetContentIdentifier = targetContentIdentifier
        self.summaryArgument = summaryArgument
        self.summaryArgumentCount = summaryArgumentCount
        self.relevanceScore = relevanceScore
        self.interruptionLevel = interruptionLevel
        self.attachments = attachments
        self.metadata = metadata
        self.deepLink = deepLink
        self.foregroundPresentation = foregroundPresentation
    }
}

nonisolated
enum LocalNotificationTrigger: Hashable, Codable, Sendable {
    case immediate
    case timeInterval(seconds: TimeInterval, repeats: Bool)
    case calendar(DateComponents, repeats: Bool)
}

nonisolated
struct LocalNotificationRequest: Hashable, Codable, Sendable {
    let id: LocalNotificationID
    let content: LocalNotificationContent
    let trigger: LocalNotificationTrigger

    init(id: LocalNotificationID, content: LocalNotificationContent, trigger: LocalNotificationTrigger) {
        self.id = id
        self.content = content
        self.trigger = trigger
    }
}

nonisolated
struct LocalNotificationActionOptions: OptionSet, Hashable, Codable, Sendable {
    let rawValue: UInt

    static let foreground = Self(rawValue: 1 << 0)
    static let destructive = Self(rawValue: 1 << 1)
    static let authenticationRequired = Self(rawValue: 1 << 2)
    static let allowed: Self = [.foreground, .destructive, .authenticationRequired]

    init(rawValue: UInt) { self.rawValue = rawValue }
}

nonisolated
struct LocalNotificationButtonAction: Hashable, Codable, Sendable {
    let id: LocalNotificationActionID
    let title: String
    let options: LocalNotificationActionOptions
    let deepLink: URL?

    init(
        id: LocalNotificationActionID,
        title: String,
        options: LocalNotificationActionOptions = [],
        deepLink: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.options = options
        self.deepLink = deepLink
    }
}

nonisolated
struct LocalNotificationTextInputAction: Hashable, Codable, Sendable {
    let id: LocalNotificationActionID
    let title: String
    let options: LocalNotificationActionOptions
    let deepLink: URL?
    let textInputButtonTitle: String
    let textInputPlaceholder: String?

    init(
        id: LocalNotificationActionID,
        title: String,
        options: LocalNotificationActionOptions = [],
        deepLink: URL? = nil,
        textInputButtonTitle: String,
        textInputPlaceholder: String? = nil
    ) {
        self.id = id
        self.title = title
        self.options = options
        self.deepLink = deepLink
        self.textInputButtonTitle = textInputButtonTitle
        self.textInputPlaceholder = textInputPlaceholder
    }
}

nonisolated
enum LocalNotificationAction: Hashable, Codable, Sendable {
    case button(LocalNotificationButtonAction)
    case textInput(LocalNotificationTextInputAction)

    var id: LocalNotificationActionID {
        switch self {
        case let .button(action): action.id
        case let .textInput(action): action.id
        }
    }
}

nonisolated
struct LocalNotificationCategory: Hashable, Codable, Sendable {
    let id: LocalNotificationCategoryID
    let actions: [LocalNotificationAction]
    let hiddenPreviewsBodyPlaceholder: String?
    let categorySummaryFormat: String?
    let hiddenPreviewsShowTitle: Bool
    let hiddenPreviewsShowSubtitle: Bool
    let reportsDismissal: Bool

    init(
        id: LocalNotificationCategoryID,
        actions: [LocalNotificationAction] = [],
        hiddenPreviewsBodyPlaceholder: String? = nil,
        categorySummaryFormat: String? = nil,
        hiddenPreviewsShowTitle: Bool = false,
        hiddenPreviewsShowSubtitle: Bool = false,
        reportsDismissal: Bool = false
    ) {
        self.id = id
        self.actions = actions
        self.hiddenPreviewsBodyPlaceholder = hiddenPreviewsBodyPlaceholder
        self.categorySummaryFormat = categorySummaryFormat
        self.hiddenPreviewsShowTitle = hiddenPreviewsShowTitle
        self.hiddenPreviewsShowSubtitle = hiddenPreviewsShowSubtitle
        self.reportsDismissal = reportsDismissal
    }
}

nonisolated
struct LocalNotificationDeepLinkPolicy: Sendable {
    let accepts: @Sendable (URL) -> Bool

    init(accepts: @escaping @Sendable (URL) -> Bool) {
        self.accepts = accepts
    }

    func isValid(_ url: URL) -> Bool { accepts(url) }
}

nonisolated
struct LocalNotificationStoredAttachment: Hashable, Codable, Sendable {
    let id: LocalNotificationAttachmentID
    let fileURL: URL
    let typeIdentifier: String

    init(id: LocalNotificationAttachmentID, fileURL: URL, typeIdentifier: String) {
        self.id = id
        self.fileURL = fileURL
        self.typeIdentifier = typeIdentifier
    }
}

nonisolated
struct LocalNotificationStoredContent: Hashable, Codable, Sendable {
    let title: String
    let subtitle: String
    let body: String
    let badge: Int?
    let sound: LocalNotificationSound
    let categoryID: LocalNotificationCategoryID?
    let threadIdentifier: String?
    let targetContentIdentifier: String?
    let summaryArgument: String?
    let summaryArgumentCount: Int?
    let relevanceScore: Double?
    let interruptionLevel: LocalNotificationInterruptionLevel
    let attachments: [LocalNotificationStoredAttachment]
    let metadata: [String: LocalNotificationMetadataValue]
    let deepLink: URL?
    let foregroundPresentation: LocalNotificationForegroundPresentation

    init(
        title: String = "",
        subtitle: String = "",
        body: String = "",
        badge: Int? = nil,
        sound: LocalNotificationSound = .none,
        categoryID: LocalNotificationCategoryID? = nil,
        threadIdentifier: String? = nil,
        targetContentIdentifier: String? = nil,
        summaryArgument: String? = nil,
        summaryArgumentCount: Int? = nil,
        relevanceScore: Double? = nil,
        interruptionLevel: LocalNotificationInterruptionLevel = .active,
        attachments: [LocalNotificationStoredAttachment] = [],
        metadata: [String: LocalNotificationMetadataValue] = [:],
        deepLink: URL? = nil,
        foregroundPresentation: LocalNotificationForegroundPresentation = []
    ) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.badge = badge
        self.sound = sound
        self.categoryID = categoryID
        self.threadIdentifier = threadIdentifier
        self.targetContentIdentifier = targetContentIdentifier
        self.summaryArgument = summaryArgument
        self.summaryArgumentCount = summaryArgumentCount
        self.relevanceScore = relevanceScore
        self.interruptionLevel = interruptionLevel
        self.attachments = attachments
        self.metadata = metadata
        self.deepLink = deepLink
        self.foregroundPresentation = foregroundPresentation
    }
}

nonisolated
struct LocalNotificationStoredRequest: Hashable, Codable, Sendable {
    let id: LocalNotificationID
    let content: LocalNotificationStoredContent
    let trigger: LocalNotificationTrigger

    init(id: LocalNotificationID, content: LocalNotificationStoredContent, trigger: LocalNotificationTrigger) {
        self.id = id
        self.content = content
        self.trigger = trigger
    }
}

nonisolated
enum LocalNotificationUnreadableReason: String, Codable, CaseIterable, Hashable, Sendable {
    case missingEnvelope
    case corruptEnvelope
    case unsupportedEnvelopeVersion
    case identifierMismatch
}

nonisolated
enum LocalNotificationSnapshotPayload: Hashable, Codable, Sendable {
    case decoded(LocalNotificationStoredRequest)
    case unreadable(LocalNotificationUnreadableReason)
}

nonisolated
struct LocalNotificationPendingSnapshot: Hashable, Codable, Sendable {
    let id: LocalNotificationID
    let payload: LocalNotificationSnapshotPayload
    let nextTriggerDate: Date?

    init(id: LocalNotificationID, payload: LocalNotificationSnapshotPayload, nextTriggerDate: Date?) {
        self.id = id
        self.payload = payload
        self.nextTriggerDate = nextTriggerDate
    }
}

nonisolated
struct LocalNotificationDeliveredSnapshot: Hashable, Codable, Sendable {
    let id: LocalNotificationID
    let payload: LocalNotificationSnapshotPayload
    let deliveredAt: Date

    init(id: LocalNotificationID, payload: LocalNotificationSnapshotPayload, deliveredAt: Date) {
        self.id = id
        self.payload = payload
        self.deliveredAt = deliveredAt
    }
}

nonisolated
struct LocalNotificationEventNotification: Hashable, Codable, Sendable {
    let id: LocalNotificationID
    let payload: LocalNotificationSnapshotPayload

    init(id: LocalNotificationID, payload: LocalNotificationSnapshotPayload) {
        self.id = id
        self.payload = payload
    }
}

nonisolated
enum LocalNotificationDiagnosticReason: String, Codable, CaseIterable, Hashable, Sendable {
    case missingEnvelope
    case corruptEnvelope
    case unsupportedEnvelopeVersion
    case identifierMismatch
    case invalidDeepLink
    case unrecognizedAction
}

nonisolated
struct LocalNotificationDiagnostic: Hashable, Codable, Sendable {
    let id: LocalNotificationID?
    let reason: LocalNotificationDiagnosticReason

    init(id: LocalNotificationID?, reason: LocalNotificationDiagnosticReason) {
        self.id = id
        self.reason = reason
    }
}

nonisolated
enum LocalNotificationEvent: Hashable, Codable, Sendable {
    case foreground(notification: LocalNotificationEventNotification, presentation: LocalNotificationForegroundPresentation)
    case opened(notification: LocalNotificationEventNotification, deepLink: URL?)
    case dismissed(notification: LocalNotificationEventNotification)
    case action(notification: LocalNotificationEventNotification, id: LocalNotificationActionID, deepLink: URL?)
    case textAction(notification: LocalNotificationEventNotification, id: LocalNotificationActionID, text: String, deepLink: URL?)
    case diagnostic(LocalNotificationDiagnostic)
}
