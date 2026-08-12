import Foundation
import CoreGraphics

nonisolated struct LocalNotificationAttachmentOptions: Hashable, Codable, Sendable {
    let typeHint: String?; let hidesThumbnail: Bool; let thumbnailClippingRect: CGRect?; let thumbnailTime: TimeInterval?
    init(typeHint: String? = nil, hidesThumbnail: Bool = false, thumbnailClippingRect: CGRect? = nil, thumbnailTime: TimeInterval? = nil) { self.typeHint = typeHint; self.hidesThumbnail = hidesThumbnail; self.thumbnailClippingRect = thumbnailClippingRect; self.thumbnailTime = thumbnailTime }
}
nonisolated struct LocalNotificationAttachment: Hashable, Codable, Sendable {
    let id: LocalNotificationAttachmentID; let fileURL: URL; let options: LocalNotificationAttachmentOptions
    init(id: LocalNotificationAttachmentID, fileURL: URL, options: LocalNotificationAttachmentOptions = .init()) { self.id = id; self.fileURL = fileURL; self.options = options }
}
nonisolated struct LocalNotificationStoredAttachment: Hashable, Codable, Sendable {
    let id: LocalNotificationAttachmentID; let fileURL: URL; let typeIdentifier: String
    init(id: LocalNotificationAttachmentID, fileURL: URL, typeIdentifier: String) { self.id = id; self.fileURL = fileURL; self.typeIdentifier = typeIdentifier }
}
