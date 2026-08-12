import Foundation

nonisolated enum LocalNotificationUnreadableReason: String, Codable, CaseIterable, Hashable, Sendable { case missingEnvelope, corruptEnvelope, unsupportedEnvelopeVersion, identifierMismatch }
nonisolated enum LocalNotificationSnapshotPayload: Hashable, Codable, Sendable { case decoded(LocalNotificationStoredRequest); case unreadable(LocalNotificationUnreadableReason) }
nonisolated struct LocalNotificationPendingSnapshot: Hashable, Codable, Sendable { let id: LocalNotificationID; let payload: LocalNotificationSnapshotPayload; let nextTriggerDate: Date?; init(id: LocalNotificationID, payload: LocalNotificationSnapshotPayload, nextTriggerDate: Date?) { self.id = id; self.payload = payload; self.nextTriggerDate = nextTriggerDate } }
nonisolated struct LocalNotificationDeliveredSnapshot: Hashable, Codable, Sendable { let id: LocalNotificationID; let payload: LocalNotificationSnapshotPayload; let deliveredAt: Date; init(id: LocalNotificationID, payload: LocalNotificationSnapshotPayload, deliveredAt: Date) { self.id = id; self.payload = payload; self.deliveredAt = deliveredAt } }
