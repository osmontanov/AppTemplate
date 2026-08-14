import Foundation

nonisolated struct LocalNotificationEventNotification: Hashable, Codable, Sendable { let id: LocalNotificationID; let payload: LocalNotificationSnapshotPayload; init(id: LocalNotificationID, payload: LocalNotificationSnapshotPayload) { self.id = id; self.payload = payload } }
nonisolated enum LocalNotificationDiagnosticReason: String, Codable, CaseIterable, Hashable, Sendable { case missingEnvelope, corruptEnvelope, unsupportedEnvelopeVersion, identifierMismatch, invalidDeepLink, unrecognizedAction, invalidStoreMetadata, notificationQueueOverflow, storeActionFailed }
nonisolated struct LocalNotificationDiagnostic: Hashable, Codable, Sendable { let id: LocalNotificationID?; let reason: LocalNotificationDiagnosticReason; init(id: LocalNotificationID?, reason: LocalNotificationDiagnosticReason) { self.id = id; self.reason = reason } }
nonisolated enum LocalNotificationEvent: Hashable, Codable, Sendable {
    case foreground(notification: LocalNotificationEventNotification, presentation: LocalNotificationForegroundPresentation)
    case opened(notification: LocalNotificationEventNotification, deepLink: URL?)
    case dismissed(notification: LocalNotificationEventNotification)
    case action(notification: LocalNotificationEventNotification, id: LocalNotificationActionID, deepLink: URL?)
    case textAction(notification: LocalNotificationEventNotification, id: LocalNotificationActionID, text: String, deepLink: URL?)
    case diagnostic(LocalNotificationDiagnostic)
}
