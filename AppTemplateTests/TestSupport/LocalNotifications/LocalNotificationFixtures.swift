import Foundation
@testable import AppTemplate

nonisolated
enum LocalNotificationFixtures {
    static func request(
        id: String,
        body: String = "Body",
        attachmentURL: URL? = nil
    ) throws -> LocalNotificationRequest {
        let attachments = try attachmentURL.map { url in
            [
                LocalNotificationAttachment(
                    id: try LocalNotificationAttachmentID("attachment"),
                    fileURL: url
                )
            ]
        } ?? []
        return LocalNotificationRequest(
            id: try LocalNotificationID(id),
            content: LocalNotificationContent(body: body, attachments: attachments),
            trigger: .immediate
        )
    }

    static func category(
        id: String = "category",
        actions: [LocalNotificationAction] = []
    ) throws -> LocalNotificationCategory {
        LocalNotificationCategory(id: try LocalNotificationCategoryID(id), actions: actions)
    }

    static func diagnostic(
        _ reason: LocalNotificationDiagnosticReason
    ) throws -> LocalNotificationEvent {
        .diagnostic(LocalNotificationDiagnostic(id: try LocalNotificationID("request"), reason: reason))
    }

    static func threeDiagnostics() throws -> [LocalNotificationEvent] {
        try [
            diagnostic(.missingEnvelope),
            diagnostic(.corruptEnvelope),
            diagnostic(.identifierMismatch)
        ]
    }

    static func openedFixture(url: String) throws -> LocalNotificationEvent {
        let id = try LocalNotificationID("request")
        let request = LocalNotificationStoredRequest(
            id: id,
            content: LocalNotificationStoredContent(body: "Body"),
            trigger: .immediate
        )
        return .opened(
            notification: LocalNotificationEventNotification(id: id, payload: .decoded(request)),
            deepLink: URL(string: url)
        )
    }
}
