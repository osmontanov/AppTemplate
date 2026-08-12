import CoreGraphics
import Foundation

nonisolated
enum LocalNotificationSystemSound: Hashable, Sendable {
    case none
    case `default`
    case named(resourceName: String)
}

nonisolated
struct LocalNotificationSystemAttachmentOptions: Hashable, Sendable {
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
struct LocalNotificationSystemAttachment: Hashable, Sendable {
    let identifier: String
    let fileURL: URL
    let typeIdentifier: String?
    let options: LocalNotificationSystemAttachmentOptions

    init(
        identifier: String,
        fileURL: URL,
        typeIdentifier: String? = nil,
        options: LocalNotificationSystemAttachmentOptions = .init()
    ) {
        self.identifier = identifier
        self.fileURL = fileURL
        self.typeIdentifier = typeIdentifier
        self.options = options
    }
}

nonisolated
struct LocalNotificationSystemContent: Hashable, Sendable {
    let title: String
    let subtitle: String
    let body: String
    let badge: Int?
    let sound: LocalNotificationSystemSound
    let categoryIdentifier: String?
    let threadIdentifier: String?
    let targetContentIdentifier: String?
    let summaryArgument: String?
    let summaryArgumentCount: Int?
    let relevanceScore: Double?
    let interruptionLevel: LocalNotificationInterruptionLevel
    let attachments: [LocalNotificationSystemAttachment]
    let envelopeData: Data?

    init(
        title: String,
        subtitle: String,
        body: String,
        badge: Int?,
        sound: LocalNotificationSystemSound,
        categoryIdentifier: String?,
        threadIdentifier: String?,
        targetContentIdentifier: String?,
        summaryArgument: String?,
        summaryArgumentCount: Int?,
        relevanceScore: Double?,
        interruptionLevel: LocalNotificationInterruptionLevel,
        attachments: [LocalNotificationSystemAttachment],
        envelopeData: Data?
    ) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.badge = badge
        self.sound = sound
        self.categoryIdentifier = categoryIdentifier
        self.threadIdentifier = threadIdentifier
        self.targetContentIdentifier = targetContentIdentifier
        self.summaryArgument = summaryArgument
        self.summaryArgumentCount = summaryArgumentCount
        self.relevanceScore = relevanceScore
        self.interruptionLevel = interruptionLevel
        self.attachments = attachments
        self.envelopeData = envelopeData
    }
}

nonisolated
enum LocalNotificationSystemTrigger: Hashable, Sendable {
    case immediate
    case timeInterval(seconds: TimeInterval, repeats: Bool)
    case calendar(DateComponents, repeats: Bool)
    case unknown
}

nonisolated
struct LocalNotificationSystemRequest: Hashable, Sendable {
    let identifier: String
    let content: LocalNotificationSystemContent
    let trigger: LocalNotificationSystemTrigger
    let nextTriggerDate: Date?

    init(
        identifier: String,
        content: LocalNotificationSystemContent,
        trigger: LocalNotificationSystemTrigger,
        nextTriggerDate: Date? = nil
    ) {
        self.identifier = identifier
        self.content = content
        self.trigger = trigger
        self.nextTriggerDate = nextTriggerDate
    }
}

nonisolated
struct LocalNotificationSystemDelivered: Hashable, Sendable {
    let request: LocalNotificationSystemRequest
    let deliveredAt: Date

    init(request: LocalNotificationSystemRequest, deliveredAt: Date) {
        self.request = request
        self.deliveredAt = deliveredAt
    }
}

nonisolated
struct LocalNotificationSystemButtonAction: Hashable, Sendable {
    let identifier: String
    let title: String
    let options: LocalNotificationActionOptions

    init(
        identifier: String,
        title: String,
        options: LocalNotificationActionOptions
    ) {
        self.identifier = identifier
        self.title = title
        self.options = options
    }
}

nonisolated
struct LocalNotificationSystemTextInputAction: Hashable, Sendable {
    let identifier: String
    let title: String
    let options: LocalNotificationActionOptions
    let textInputButtonTitle: String
    let textInputPlaceholder: String?

    init(
        identifier: String,
        title: String,
        options: LocalNotificationActionOptions,
        textInputButtonTitle: String,
        textInputPlaceholder: String?
    ) {
        self.identifier = identifier
        self.title = title
        self.options = options
        self.textInputButtonTitle = textInputButtonTitle
        self.textInputPlaceholder = textInputPlaceholder
    }
}

nonisolated
enum LocalNotificationSystemAction: Hashable, Sendable {
    case button(LocalNotificationSystemButtonAction)
    case textInput(LocalNotificationSystemTextInputAction)
}

nonisolated
struct LocalNotificationSystemCategory: Hashable, Sendable {
    let identifier: String
    let actions: [LocalNotificationSystemAction]
    let hiddenPreviewsBodyPlaceholder: String?
    let categorySummaryFormat: String?
    let hiddenPreviewsShowTitle: Bool
    let hiddenPreviewsShowSubtitle: Bool
    let reportsDismissal: Bool

    init(
        identifier: String,
        actions: [LocalNotificationSystemAction],
        hiddenPreviewsBodyPlaceholder: String?,
        categorySummaryFormat: String?,
        hiddenPreviewsShowTitle: Bool,
        hiddenPreviewsShowSubtitle: Bool,
        reportsDismissal: Bool
    ) {
        self.identifier = identifier
        self.actions = actions
        self.hiddenPreviewsBodyPlaceholder = hiddenPreviewsBodyPlaceholder
        self.categorySummaryFormat = categorySummaryFormat
        self.hiddenPreviewsShowTitle = hiddenPreviewsShowTitle
        self.hiddenPreviewsShowSubtitle = hiddenPreviewsShowSubtitle
        self.reportsDismissal = reportsDismissal
    }
}
