import Foundation
import Synchronization
import UserNotifications

nonisolated
struct LocalNotificationSystemDelivery: Hashable, Sendable {
    let request: LocalNotificationSystemRequest
    let deliveredAt: Date

    init(request: LocalNotificationSystemRequest, deliveredAt: Date) {
        self.request = request
        self.deliveredAt = deliveredAt
    }
}

nonisolated
struct LocalNotificationSystemResponse: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case defaultOpen
        case dismiss
        case button(identifier: String)
        case text(identifier: String, text: String)
    }

    let request: LocalNotificationSystemRequest
    let deliveredAt: Date
    let kind: Kind

    init(
        request: LocalNotificationSystemRequest,
        deliveredAt: Date,
        kind: Kind
    ) {
        self.request = request
        self.deliveredAt = deliveredAt
        self.kind = kind
    }
}

nonisolated
struct NotificationCenterUnmanagedHandler: Sendable {
    let foreground: @Sendable (
        LocalNotificationSystemDelivery
    ) async throws -> LocalNotificationForegroundPresentation
    let response: @Sendable (LocalNotificationSystemResponse) async throws -> Void

    init(
        foreground: @escaping @Sendable (
            LocalNotificationSystemDelivery
        ) async throws -> LocalNotificationForegroundPresentation,
        response: @escaping @Sendable (
            LocalNotificationSystemResponse
        ) async throws -> Void
    ) {
        self.foreground = foreground
        self.response = response
    }
}

nonisolated
struct LocalNotificationDelegateEventPublisher: Sendable {
    let publish: @Sendable (LocalNotificationEvent) async -> Void

    init(
        _ publish: @escaping @Sendable (LocalNotificationEvent) async -> Void
    ) {
        self.publish = publish
    }

    init(eventHub: LocalNotificationEventHub) {
        publish = { event in await eventHub.publish(event) }
    }
}

// Objective-C delegate callbacks are not modeled as Sendable by the SDK. The
// bridge crosses that boundary only through immutable Sendable values; its only
// callback state is protected by NotificationCenterDelegateCompletion's Mutex.
nonisolated
final class NotificationCenterDelegateBridge:
    NSObject,
    UNUserNotificationCenterDelegate,
    @unchecked Sendable
{
    private let namespace: LocalNotificationNamespace
    private let deepLinkPolicy: LocalNotificationDeepLinkPolicy
    private let eventPublisher: LocalNotificationDelegateEventPublisher
    private let unmanagedHandler: NotificationCenterUnmanagedHandler?

    init(
        namespace: LocalNotificationNamespace,
        deepLinkPolicy: LocalNotificationDeepLinkPolicy,
        eventHub: LocalNotificationEventHub,
        unmanagedHandler: NotificationCenterUnmanagedHandler?
    ) {
        self.namespace = namespace
        self.deepLinkPolicy = deepLinkPolicy
        eventPublisher = LocalNotificationDelegateEventPublisher(eventHub: eventHub)
        self.unmanagedHandler = unmanagedHandler
    }

    init(
        namespace: LocalNotificationNamespace,
        deepLinkPolicy: LocalNotificationDeepLinkPolicy,
        eventPublisher: LocalNotificationDelegateEventPublisher,
        unmanagedHandler: NotificationCenterUnmanagedHandler?
    ) {
        self.namespace = namespace
        self.deepLinkPolicy = deepLinkPolicy
        self.eventPublisher = eventPublisher
        self.unmanagedHandler = unmanagedHandler
    }

    func processDelivery(
        _ delivery: LocalNotificationSystemDelivery,
        completion: @escaping @Sendable (
            LocalNotificationForegroundPresentation
        ) -> Void
    ) async {
        let completion = NotificationCenterDelegateCompletion(completion)
        defer { completion.complete([]) }

        guard let logicalID = namespace.logicalRequestID(
            delivery.request.identifier
        ) else {
            let presentation: LocalNotificationForegroundPresentation
            do {
                presentation = try await unmanagedHandler?.foreground(delivery) ?? []
            } catch {
                presentation = []
            }
            completion.complete(presentation)
            return
        }

        do {
            let decoded = try decodedNotification(
                request: delivery.request,
                logicalID: logicalID
            )
            await eventPublisher.publish(
                .foreground(
                    notification: decoded.notification,
                    presentation: decoded.envelope.foregroundPresentation
                )
            )
            completion.complete(decoded.envelope.foregroundPresentation)
        } catch {
            await eventPublisher.publish(
                .diagnostic(
                    LocalNotificationDiagnostic(
                        id: logicalID,
                        reason: Self.diagnosticReason(for: error)
                    )
                )
            )
            completion.complete([])
        }
    }

    func processResponse(
        _ response: LocalNotificationSystemResponse,
        completion: @escaping @Sendable () -> Void
    ) async {
        let completion = NotificationCenterDelegateCompletion<Void> { _ in
            completion()
        }
        defer { completion.complete(()) }

        guard let logicalID = namespace.logicalRequestID(
            response.request.identifier
        ) else {
            do {
                try await unmanagedHandler?.response(response)
            } catch {
                // Unmanaged failures are intentionally private to their owner.
            }
            completion.complete(())
            return
        }

        do {
            let decoded = try decodedNotification(
                request: response.request,
                logicalID: logicalID
            )
            let event = event(
                for: response.kind,
                decoded: decoded,
                logicalID: logicalID
            )
            await eventPublisher.publish(event)
            completion.complete(())
        } catch {
            await eventPublisher.publish(
                .diagnostic(
                    LocalNotificationDiagnostic(
                        id: logicalID,
                        reason: Self.diagnosticReason(for: error)
                    )
                )
            )
            completion.complete(())
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (
            UNNotificationPresentationOptions
        ) -> Void
    ) {
        _ = center
        let delivery = LocalNotificationSystemDelivery(
            request: LocalNotificationSystemMapper.systemRequest(
                notification.request
            ),
            deliveredAt: notification.date
        )
        let frameworkCompletion = NotificationCenterFrameworkCompletion(
            completionHandler
        )
        Task { [self, delivery, frameworkCompletion] in
            await processDelivery(delivery) { presentation in
                frameworkCompletion.complete(
                    LocalNotificationSystemMapper.presentationOptions(
                        presentation
                    )
                )
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        _ = center
        let systemResponse = LocalNotificationSystemResponse(
            request: LocalNotificationSystemMapper.systemRequest(
                response.notification.request
            ),
            deliveredAt: response.notification.date,
            kind: Self.responseKind(response)
        )
        let frameworkCompletion = NotificationCenterFrameworkCompletion<Void> {
            _ in completionHandler()
        }
        Task { [self, systemResponse, frameworkCompletion] in
            await processResponse(systemResponse) {
                frameworkCompletion.complete(())
            }
        }
    }

    private func decodedNotification(
        request: LocalNotificationSystemRequest,
        logicalID: LocalNotificationID
    ) throws -> DecodedDelegateNotification {
        let envelope = try LocalNotificationEnvelopeCodec.decodeManaged(
            request.content.envelopeData,
            physicalRequestID: request.identifier,
            namespace: namespace,
            deepLinkPolicy: deepLinkPolicy
        )
        let categoryID = try storedCategoryID(
            request.content.categoryIdentifier
        )
        let attachments: [LocalNotificationStoredAttachment] =
            request.content.attachments.compactMap { attachment in
                guard let decoded = namespace.logicalAttachmentID(
                    attachment.identifier
                ),
                decoded.request == logicalID,
                let typeIdentifier = attachment.typeIdentifier else {
                    return nil
                }
                return LocalNotificationStoredAttachment(
                    id: decoded.attachment,
                    fileURL: attachment.fileURL,
                    typeIdentifier: typeIdentifier
                )
            }
        let content = request.content
        let stored = LocalNotificationStoredRequest(
            id: logicalID,
            content: LocalNotificationStoredContent(
                title: content.title,
                subtitle: content.subtitle,
                body: content.body,
                badge: content.badge,
                sound: envelope.sound,
                categoryID: categoryID,
                threadIdentifier: content.threadIdentifier,
                targetContentIdentifier: content.targetContentIdentifier,
                summaryArgument: content.summaryArgument,
                summaryArgumentCount: content.summaryArgumentCount,
                relevanceScore: content.relevanceScore,
                interruptionLevel: content.interruptionLevel,
                attachments: attachments,
                metadata: envelope.metadata,
                deepLink: envelope.defaultDeepLink,
                foregroundPresentation: envelope.foregroundPresentation
            ),
            trigger: try Self.storedTrigger(request.trigger)
        )
        return DecodedDelegateNotification(
            notification: LocalNotificationEventNotification(
                id: logicalID,
                payload: .decoded(stored)
            ),
            envelope: envelope
        )
    }

    private func storedCategoryID(
        _ physicalIdentifier: String?
    ) throws -> LocalNotificationCategoryID? {
        guard let physicalIdentifier, !physicalIdentifier.isEmpty else {
            return nil
        }
        guard let identifier = namespace.logicalCategoryID(
            physicalIdentifier
        ) else {
            throw LocalNotificationEnvelopeError.identifierMismatch
        }
        return identifier
    }

    private func event(
        for kind: LocalNotificationSystemResponse.Kind,
        decoded: DecodedDelegateNotification,
        logicalID: LocalNotificationID
    ) -> LocalNotificationEvent {
        switch kind {
        case .defaultOpen:
            return .opened(
                notification: decoded.notification,
                deepLink: decoded.envelope.defaultDeepLink
            )
        case .dismiss:
            return .dismissed(notification: decoded.notification)
        case let .button(identifier):
            guard let action = decodedAction(
                identifier,
                envelope: decoded.envelope
            ) else {
                return .diagnostic(
                    LocalNotificationDiagnostic(
                        id: logicalID,
                        reason: .unrecognizedAction
                    )
                )
            }
            return .action(
                notification: decoded.notification,
                id: action.id,
                deepLink: action.deepLink
            )
        case let .text(identifier, text):
            guard let action = decodedAction(
                identifier,
                envelope: decoded.envelope
            ) else {
                return .diagnostic(
                    LocalNotificationDiagnostic(
                        id: logicalID,
                        reason: .unrecognizedAction
                    )
                )
            }
            return .textAction(
                notification: decoded.notification,
                id: action.id,
                text: text,
                deepLink: action.deepLink
            )
        }
    }

    private func decodedAction(
        _ physicalIdentifier: String,
        envelope: LocalNotificationEnvelopeV1
    ) -> DecodedDelegateAction? {
        guard let decoded = namespace.logicalActionID(physicalIdentifier),
              decoded.category == envelope.categoryID else {
            return nil
        }
        return DecodedDelegateAction(
            id: decoded.action,
            deepLink: envelope.actionRoutes.first {
                $0.id == decoded.action
            }?.deepLink
        )
    }

    private static func responseKind(
        _ response: UNNotificationResponse
    ) -> LocalNotificationSystemResponse.Kind {
        let identifier = response.actionIdentifier
        if identifier == UNNotificationDefaultActionIdentifier {
            return .defaultOpen
        }
        if identifier == UNNotificationDismissActionIdentifier {
            return .dismiss
        }
        if let textResponse = response as? UNTextInputNotificationResponse {
            return .text(
                identifier: identifier,
                text: textResponse.userText
            )
        }
        return .button(identifier: identifier)
    }

    private static func storedTrigger(
        _ trigger: LocalNotificationSystemTrigger
    ) throws -> LocalNotificationTrigger {
        switch trigger {
        case .immediate:
            .immediate
        case let .timeInterval(seconds, repeats):
            .timeInterval(seconds: seconds, repeats: repeats)
        case let .calendar(components, repeats):
            .calendar(components, repeats: repeats)
        case .unknown:
            throw DelegateSnapshotError.unsupportedTrigger
        }
    }

    private static func diagnosticReason(
        for error: any Error
    ) -> LocalNotificationDiagnosticReason {
        switch error {
        case LocalNotificationEnvelopeError.missingEnvelope:
            .missingEnvelope
        case LocalNotificationEnvelopeError.identifierMismatch:
            .identifierMismatch
        case LocalNotificationServiceError.unsupportedEnvelopeVersion:
            .unsupportedEnvelopeVersion
        case LocalNotificationServiceError.invalidDeepLink:
            .invalidDeepLink
        default:
            .corruptEnvelope
        }
    }
}

private nonisolated struct DecodedDelegateNotification: Sendable {
    let notification: LocalNotificationEventNotification
    let envelope: LocalNotificationEnvelopeV1
}

private nonisolated struct DecodedDelegateAction: Sendable {
    let id: LocalNotificationActionID
    let deepLink: URL?
}

private nonisolated enum DelegateSnapshotError: Error, Sendable {
    case unsupportedTrigger
}

private nonisolated final class NotificationCenterDelegateCompletion<Value: Sendable>:
    Sendable
{
    private struct State: Sendable {
        var didComplete = false
        let completion: @Sendable (Value) -> Void
    }

    private let state: Mutex<State>

    init(_ completion: @escaping @Sendable (Value) -> Void) {
        state = Mutex(State(completion: completion))
    }

    func complete(_ value: Value) {
        let callback: (@Sendable (Value) -> Void)? = state.withLock { state in
            guard !state.didComplete else { return nil }
            state.didComplete = true
            return state.completion
        }
        callback?(value)
    }
}

// The imported Objective-C completion block is not Sendable even though the
// bridge calls it through one Mutex-protected owner and never exposes it.
private nonisolated final class NotificationCenterFrameworkCompletion<Value: Sendable>:
    @unchecked Sendable
{
    private let completion: (Value) -> Void

    init(_ completion: @escaping (Value) -> Void) {
        self.completion = completion
    }

    func complete(_ value: Value) {
        completion(value)
    }
}
