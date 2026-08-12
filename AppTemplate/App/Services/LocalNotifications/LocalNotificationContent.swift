import Foundation

nonisolated enum LocalNotificationSound: Hashable, Codable, Sendable { case none; case `default`; case named(resourceName: String) }
nonisolated enum LocalNotificationInterruptionLevel: String, Codable, CaseIterable, Hashable, Sendable { case passive, active }
nonisolated struct LocalNotificationForegroundPresentation: OptionSet, Hashable, Sendable {
    let rawValue: UInt
    static let banner = Self(rawValue: 1 << 0); static let list = Self(rawValue: 1 << 1); static let sound = Self(rawValue: 1 << 2); static let badge = Self(rawValue: 1 << 3)
    static let allowed: Self = [.banner, .list, .sound, .badge]
    init(rawValue: UInt) { self.rawValue = rawValue }
}
nonisolated extension LocalNotificationForegroundPresentation: Codable {
    init(from decoder: any Decoder) throws { let container = try decoder.singleValueContainer(); let options = Self(rawValue: try container.decode(UInt.self)); guard (try? LocalNotificationValidator.validate(foregroundPresentation: options)) != nil else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid local notification foreground presentation options") }; self = options }
    func encode(to encoder: any Encoder) throws { try LocalNotificationValidator.validate(foregroundPresentation: self); var container = encoder.singleValueContainer(); try container.encode(rawValue) }
}
nonisolated struct LocalNotificationContent: Hashable, Codable, Sendable {
    let title: String; let subtitle: String; let body: String; let badge: Int?; let sound: LocalNotificationSound; let categoryID: LocalNotificationCategoryID?; let threadIdentifier: String?; let targetContentIdentifier: String?; let summaryArgument: String?; let summaryArgumentCount: Int?; let relevanceScore: Double?; let interruptionLevel: LocalNotificationInterruptionLevel; let attachments: [LocalNotificationAttachment]; let metadata: [String: LocalNotificationMetadataValue]; let deepLink: URL?; let foregroundPresentation: LocalNotificationForegroundPresentation
    init(title: String = "", subtitle: String = "", body: String = "", badge: Int? = nil, sound: LocalNotificationSound = .none, categoryID: LocalNotificationCategoryID? = nil, threadIdentifier: String? = nil, targetContentIdentifier: String? = nil, summaryArgument: String? = nil, summaryArgumentCount: Int? = nil, relevanceScore: Double? = nil, interruptionLevel: LocalNotificationInterruptionLevel = .active, attachments: [LocalNotificationAttachment] = [], metadata: [String: LocalNotificationMetadataValue] = [:], deepLink: URL? = nil, foregroundPresentation: LocalNotificationForegroundPresentation = []) {
        self.title = title; self.subtitle = subtitle; self.body = body; self.badge = badge; self.sound = sound; self.categoryID = categoryID; self.threadIdentifier = threadIdentifier; self.targetContentIdentifier = targetContentIdentifier; self.summaryArgument = summaryArgument; self.summaryArgumentCount = summaryArgumentCount; self.relevanceScore = relevanceScore; self.interruptionLevel = interruptionLevel; self.attachments = attachments; self.metadata = metadata; self.deepLink = deepLink; self.foregroundPresentation = foregroundPresentation
    }
}
nonisolated struct LocalNotificationStoredContent: Hashable, Codable, Sendable {
    let title: String; let subtitle: String; let body: String; let badge: Int?; let sound: LocalNotificationSound; let categoryID: LocalNotificationCategoryID?; let threadIdentifier: String?; let targetContentIdentifier: String?; let summaryArgument: String?; let summaryArgumentCount: Int?; let relevanceScore: Double?; let interruptionLevel: LocalNotificationInterruptionLevel; let attachments: [LocalNotificationStoredAttachment]; let metadata: [String: LocalNotificationMetadataValue]; let deepLink: URL?; let foregroundPresentation: LocalNotificationForegroundPresentation
    init(title: String = "", subtitle: String = "", body: String = "", badge: Int? = nil, sound: LocalNotificationSound = .none, categoryID: LocalNotificationCategoryID? = nil, threadIdentifier: String? = nil, targetContentIdentifier: String? = nil, summaryArgument: String? = nil, summaryArgumentCount: Int? = nil, relevanceScore: Double? = nil, interruptionLevel: LocalNotificationInterruptionLevel = .active, attachments: [LocalNotificationStoredAttachment] = [], metadata: [String: LocalNotificationMetadataValue] = [:], deepLink: URL? = nil, foregroundPresentation: LocalNotificationForegroundPresentation = []) {
        self.title = title; self.subtitle = subtitle; self.body = body; self.badge = badge; self.sound = sound; self.categoryID = categoryID; self.threadIdentifier = threadIdentifier; self.targetContentIdentifier = targetContentIdentifier; self.summaryArgument = summaryArgument; self.summaryArgumentCount = summaryArgumentCount; self.relevanceScore = relevanceScore; self.interruptionLevel = interruptionLevel; self.attachments = attachments; self.metadata = metadata; self.deepLink = deepLink; self.foregroundPresentation = foregroundPresentation
    }
}
