import Foundation

nonisolated enum LocalNotificationTrigger: Hashable, Codable, Sendable { case immediate; case timeInterval(seconds: TimeInterval, repeats: Bool); case calendar(DateComponents, repeats: Bool) }
nonisolated struct LocalNotificationRequest: Hashable, Codable, Sendable {
    let id: LocalNotificationID; let content: LocalNotificationContent; let trigger: LocalNotificationTrigger
    init(id: LocalNotificationID, content: LocalNotificationContent, trigger: LocalNotificationTrigger) { self.id = id; self.content = content; self.trigger = trigger }
}
nonisolated struct LocalNotificationStoredRequest: Hashable, Codable, Sendable {
    let id: LocalNotificationID; let content: LocalNotificationStoredContent; let trigger: LocalNotificationTrigger
    init(id: LocalNotificationID, content: LocalNotificationStoredContent, trigger: LocalNotificationTrigger) { self.id = id; self.content = content; self.trigger = trigger }
}
