import Foundation
import Synchronization
import Testing
import UserNotifications
@testable import AppTemplate

@Suite(.serialized)
struct NotificationCenterDelegateBridgeTests {
    @Test(.timeLimit(.minutes(1)))
    func responseRecordsPublishesDispatchesThenCompletesOnce() async throws {
        let trace = DelegateOrderTrace()
        let history = LocalNotificationEventHistory(clock: .live)
        let hub = LocalNotificationEventHub(history: history)
        let bridge = NotificationCenterDelegateBridge(
            namespace: try LocalNotificationNamespace(),
            deepLinkPolicy: .init { $0.scheme == "apptemplate" },
            eventPublisher: LocalNotificationDelegateEventPublisher { event in
                await hub.publish(event)
                trace.record(.history)
                trace.record(.published)
            },
            responseDispatcher: DelegateOrderDispatcher(trace: trace),
            unmanagedHandler: nil
        )

        await bridge.processResponse(
            try .delegateFixture(kind: .defaultOpen),
            completion: { trace.record(.completion) }
        )

        #expect(trace.values == [.history, .published, .dispatched, .completion])
        #expect(await history.records().count == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func foregroundPublishesFullPayloadBeforeCompletingWithEveryPresentationOption() async throws {
        let hub = makeLocalNotificationEventHub()
        let stream = await hub.events()
        let recorder = DelegateCallbackRecorder()
        let bridge = try NotificationCenterDelegateBridge.fixture(
            eventHub: hub,
            recorder: recorder
        )
        let delivery = try LocalNotificationSystemDelivery(
            request: .delegateFixture(
                categoryIdentifier: .logical("secondary"),
                attachments: [
                    .delegateFixture(requestID: "request", attachmentID: "image"),
                    .delegateFixture(requestID: "other", attachmentID: "wrong-request"),
                    .delegateFixture(
                        requestID: "request",
                        attachmentID: "nil-type",
                        typeIdentifier: nil
                    )
                ]
            ),
            deliveredAt: Date(timeIntervalSince1970: 456)
        )

        await bridge.processDelivery(delivery) { options in
            recorder.complete(foreground: options)
        }

        let event = try await firstDelegateEvent(from: stream)
        recorder.recordObservedEvent(event)
        let expectedAttachmentURL = URL(fileURLWithPath: "/system/image.png")
        let expected = try LocalNotificationStoredRequest(
            id: .init("request"),
            content: LocalNotificationStoredContent(
                title: "Visible title",
                subtitle: "Visible subtitle",
                body: "Visible body",
                badge: 7,
                sound: .named(resourceName: "reminder.aiff"),
                categoryID: .init("secondary"),
                threadIdentifier: "thread",
                targetContentIdentifier: "target",
                summaryArgument: "Summary",
                summaryArgumentCount: 3,
                relevanceScore: 0.75,
                interruptionLevel: .passive,
                attachments: [
                    .init(
                        id: .init("image"),
                        fileURL: expectedAttachmentURL,
                        typeIdentifier: "public.png"
                    )
                ],
                metadata: ["private": .string("metadata")],
                deepLink: URL(string: "apptemplate://projects/project/request"),
                foregroundPresentation: [.banner, .list, .sound, .badge]
            ),
            trigger: .timeInterval(seconds: 120, repeats: true)
        )

        #expect(event == .foreground(
            notification: .init(id: expected.id, payload: .decoded(expected)),
            presentation: [.banner, .list, .sound, .badge]
        ))
        #expect(recorder.foregroundCompletions == [[.banner, .list, .sound, .badge]])
        #expect(recorder.completionCount == 1)
        #expect(recorder.order == [.published, .completion, .observedEvent])
    }

    @Test(.timeLimit(.minutes(1)))
    func defaultOpenUsesOnlyTheRequestDeepLinkAndCompletesOnceAfterPublishing() async throws {
        let hub = makeLocalNotificationEventHub()
        let stream = await hub.events()
        let recorder = DelegateCallbackRecorder()
        let bridge = try NotificationCenterDelegateBridge.fixture(
            eventHub: hub,
            recorder: recorder
        )

        await bridge.processResponse(
            try .delegateFixture(kind: .defaultOpen),
            completion: { recorder.completeResponse() }
        )

        let event = try await firstDelegateEvent(from: stream)
        recorder.recordObservedEvent(event)
        guard case let .opened(notification, deepLink) = event else {
            Issue.record("Expected opened event")
            return
        }
        let expectedID = try LocalNotificationID("request")
        #expect(notification.id == expectedID)
        #expect(deepLink == URL(string: "apptemplate://projects/project/request"))
        #expect(recorder.completionCount == 1)
        #expect(recorder.order == [.published, .completion, .observedEvent])
    }

    @Test(.timeLimit(.minutes(1)))
    func emptySystemCategoryIsSystemTruthAndReconstructsAsNil() async throws {
        let hub = makeLocalNotificationEventHub()
        let stream = await hub.events()
        let recorder = DelegateCallbackRecorder()
        let bridge = try NotificationCenterDelegateBridge.fixture(
            eventHub: hub,
            recorder: recorder
        )
        let request = try LocalNotificationSystemRequest.delegateFixture(
            categoryIdentifier: .none
        )

        await bridge.processDelivery(
            .init(request: request, deliveredAt: Date(timeIntervalSince1970: 456)),
            completion: { recorder.complete(foreground: $0) }
        )
        let event = try await firstDelegateEvent(from: stream)
        recorder.recordObservedEvent(event)

        guard case let .foreground(notification, _) = event,
              case let .decoded(stored) = notification.payload else {
            Issue.record("Expected decoded foreground event")
            return
        }
        #expect(stored.content.categoryID == nil)
        #expect(recorder.order == [.published, .completion, .observedEvent])
        #expect(recorder.completionCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func defaultOpenPreservesANilRequestDeepLinkWithoutFallback() async throws {
        let requestID = try LocalNotificationID("request")
        let request = try LocalNotificationSystemRequest.delegateFixture(
            envelope: LocalNotificationEnvelopeV1.delegateFixture(
                requestID: requestID,
                defaultDeepLink: nil
            )
        )

        let result = try await processOwnedResponse(
            .delegateFixture(kind: .defaultOpen, request: request)
        )

        guard case let .opened(notification, deepLink) = result.event else {
            Issue.record("Expected opened event")
            return
        }
        #expect(notification.id == requestID)
        #expect(deepLink == nil)
        result.recorder.expectOneResponseCompletionAfterPublish()
    }

    @Test(.timeLimit(.minutes(1)))
    func dismissPublishesWithoutARouteAndCompletesOnceAfterPublishing() async throws {
        let result = try await processOwnedResponse(.delegateFixture(kind: .dismiss))

        guard case let .dismissed(notification) = result.event else {
            Issue.record("Expected dismissed event")
            return
        }
        let expectedID = try LocalNotificationID("request")
        #expect(notification.id == expectedID)
        result.recorder.expectOneResponseCompletionAfterPublish()
    }

    @Test(.timeLimit(.minutes(1)))
    func buttonUsesOnlyItsImmutableActionRoute() async throws {
        let namespace = try LocalNotificationNamespace()
        let categoryID = try LocalNotificationCategoryID("category")
        let actionID = try LocalNotificationActionID("open")
        let response = try LocalNotificationSystemResponse.delegateFixture(
            kind: .button(
                identifier: namespace.physicalActionID(
                    category: categoryID,
                    action: actionID
                )
            )
        )

        let result = try await processOwnedResponse(response)

        guard case let .action(notification, actualID, deepLink) = result.event else {
            Issue.record("Expected button action event")
            return
        }
        let expectedID = try LocalNotificationID("request")
        #expect(notification.id == expectedID)
        #expect(actualID == actionID)
        #expect(deepLink == URL(string: "apptemplate://projects/project/action"))
        result.recorder.expectOneResponseCompletionAfterPublish()
    }

    @Test(.timeLimit(.minutes(1)))
    func buttonWithNoActionRouteDoesNotFallBackToTheRequestRoute() async throws {
        let namespace = try LocalNotificationNamespace()
        let categoryID = try LocalNotificationCategoryID("category")
        let actionID = try LocalNotificationActionID("no-route")
        let result = try await processOwnedResponse(
            .delegateFixture(
                kind: .button(
                    identifier: namespace.physicalActionID(
                        category: categoryID,
                        action: actionID
                    )
                )
            )
        )

        guard case let .action(_, actualID, deepLink) = result.event else {
            Issue.record("Expected button action event")
            return
        }
        #expect(actualID == actionID)
        #expect(deepLink == nil)
        result.recorder.expectOneResponseCompletionAfterPublish()
    }

    @Test(.timeLimit(.minutes(1)))
    func validActionMissingFromTheSnapshotStillPublishesWithNoRoute() async throws {
        let namespace = try LocalNotificationNamespace()
        let categoryID = try LocalNotificationCategoryID("category")
        let actionID = try LocalNotificationActionID("later-action")
        let result = try await processOwnedResponse(
            .delegateFixture(
                kind: .button(
                    identifier: namespace.physicalActionID(
                        category: categoryID,
                        action: actionID
                    )
                )
            )
        )

        guard case let .action(_, actualID, deepLink) = result.event else {
            Issue.record("Expected button action event")
            return
        }
        #expect(actualID == actionID)
        #expect(deepLink == nil)
        result.recorder.expectOneResponseCompletionAfterPublish()
    }

    @Test(.timeLimit(.minutes(1)))
    func textActionPublishesTheExactTextAndOnlyItsImmutableRoute() async throws {
        let namespace = try LocalNotificationNamespace()
        let categoryID = try LocalNotificationCategoryID("category")
        let actionID = try LocalNotificationActionID("reply")
        let result = try await processOwnedResponse(
            .delegateFixture(
                kind: .text(
                    identifier: namespace.physicalActionID(
                        category: categoryID,
                        action: actionID
                    ),
                    text: "PRIVATE-REPLY"
                )
            )
        )

        guard case let .textAction(notification, actualID, text, deepLink) = result.event else {
            Issue.record("Expected text action event")
            return
        }
        let expectedID = try LocalNotificationID("request")
        #expect(notification.id == expectedID)
        #expect(actualID == actionID)
        #expect(text == "PRIVATE-REPLY")
        #expect(deepLink == URL(string: "apptemplate://projects/project/reply"))
        #expect(result.recorder.publishedEvents == [result.event])
        result.recorder.expectOneResponseCompletionAfterPublish()
    }

    @Test(.timeLimit(.minutes(1)))
    func malformedActionPublishesOneUnrecognizedActionDiagnostic() async throws {
        let result = try await processOwnedResponse(
            .delegateFixture(kind: .button(identifier: "malformed-action"))
        )

        #expect(result.event == .diagnostic(.init(
            id: try LocalNotificationID("request"),
            reason: .unrecognizedAction
        )))
        #expect(result.recorder.publishedEvents == [result.event])
        result.recorder.expectOneResponseCompletionAfterPublish()
    }

    @Test(.timeLimit(.minutes(1)))
    func categoryMismatchedActionPublishesOneUnrecognizedActionDiagnostic() async throws {
        let namespace = try LocalNotificationNamespace()
        let result = try await processOwnedResponse(
            .delegateFixture(
                kind: .button(
                    identifier: namespace.physicalActionID(
                        category: try LocalNotificationCategoryID("other-category"),
                        action: try LocalNotificationActionID("open")
                    )
                )
            )
        )

        #expect(result.event == .diagnostic(.init(
            id: try LocalNotificationID("request"),
            reason: .unrecognizedAction
        )))
        #expect(result.recorder.publishedEvents == [result.event])
        result.recorder.expectOneResponseCompletionAfterPublish()
    }

    @Test(.timeLimit(.minutes(1)))
    func missingEnvelopePublishesOneRedactedDiagnosticAndNoForegroundOptions() async throws {
        try await expectForegroundDiagnostic(
            request: .delegateFixture(envelopeData: .value(nil)),
            reason: .missingEnvelope
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func corruptEnvelopePublishesOneRedactedDiagnosticAndNoForegroundOptions() async throws {
        try await expectForegroundDiagnostic(
            request: .delegateFixture(envelopeData: .value(Data("not-json".utf8))),
            reason: .corruptEnvelope
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func futureEnvelopePublishesOneRedactedDiagnosticAndNoForegroundOptions() async throws {
        try await expectForegroundDiagnostic(
            request: .delegateFixture(
                envelopeData: .value(Data(#"{"schemaVersion":99}"#.utf8))
            ),
            reason: .unsupportedEnvelopeVersion
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func envelopeRequestMismatchPublishesOneRedactedDiagnosticAndNoForegroundOptions() async throws {
        let envelope = try LocalNotificationEnvelopeV1.delegateFixture(
            requestID: LocalNotificationID("other-request")
        )
        try await expectForegroundDiagnostic(
            request: .delegateFixture(envelope: envelope),
            reason: .identifierMismatch
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func invalidEnvelopeDeepLinkPublishesOneRedactedDiagnosticAndNoForegroundOptions() async throws {
        let envelope = try LocalNotificationEnvelopeV1.delegateFixture(
            requestID: LocalNotificationID("request"),
            defaultDeepLink: URL(string: "https://private.invalid/route")
        )
        try await expectForegroundDiagnostic(
            request: .delegateFixture(envelope: envelope),
            reason: .invalidDeepLink
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func foreignSystemCategoryPublishesIdentifierMismatchInsteadOfTrustingEnvelopeCategory() async throws {
        try await expectForegroundDiagnostic(
            request: .delegateFixture(categoryIdentifier: .raw("remote.category")),
            reason: .identifierMismatch
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func noncanonicalOwnedSystemCategoryPublishesIdentifierMismatch() async throws {
        try await expectForegroundDiagnostic(
            request: .delegateFixture(
                categoryIdentifier: .raw(
                    "AppTemplate.LocalNotification.category.Y2F0ZWdvcnk="
                )
            ),
            reason: .identifierMismatch
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func unreadableResponsePublishesOnlyOneDiagnosticAndCompletesWithoutNavigation() async throws {
        let request = try LocalNotificationSystemRequest.delegateFixture(
            envelopeData: .value(Data("not-json".utf8))
        )
        let result = try await processOwnedResponse(
            .delegateFixture(kind: .defaultOpen, request: request)
        )

        #expect(result.event == .diagnostic(.init(
            id: try LocalNotificationID("request"),
            reason: .corruptEnvelope
        )))
        #expect(result.recorder.publishedEvents == [result.event])
        result.recorder.expectOneResponseCompletionAfterPublish()
    }

    @Test(.timeLimit(.minutes(1)))
    func absentUnmanagedHandlerDefaultsForegroundToNoneAndCompletesResponse() async throws {
        let foreign = try LocalNotificationSystemRequest.delegateFixture(
            physicalRequestID: "remote.request"
        )
        let foregroundRecorder = DelegateCallbackRecorder()
        let responseRecorder = DelegateCallbackRecorder()
        let bridge = try NotificationCenterDelegateBridge.fixture(
            eventHub: makeLocalNotificationEventHub(),
            recorder: foregroundRecorder,
            unmanagedHandler: nil
        )

        await bridge.processDelivery(
            .init(request: foreign, deliveredAt: Date(timeIntervalSince1970: 1)),
            completion: { foregroundRecorder.complete(foreground: $0) }
        )
        await bridge.processResponse(
            .init(
                request: foreign,
                deliveredAt: Date(timeIntervalSince1970: 1),
                kind: .defaultOpen
            ),
            completion: { responseRecorder.completeResponse() }
        )

        #expect(foregroundRecorder.foregroundCompletions == [[]])
        #expect(foregroundRecorder.completionCount == 1)
        #expect(foregroundRecorder.publishedEvents.isEmpty)
        #expect(responseRecorder.completionCount == 1)
        #expect(responseRecorder.publishedEvents.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func prefixInvalidRequestIsUnmanagedAndPublishesNoDiagnostic() async throws {
        let recorder = DelegateCallbackRecorder()
        let handler = NotificationCenterUnmanagedHandler(
            foreground: { _ in
                recorder.recordUnmanagedWork()
                return [.banner]
            },
            response: { _ in recorder.recordUnmanagedWork() }
        )
        let bridge = try NotificationCenterDelegateBridge.fixture(
            eventHub: makeLocalNotificationEventHub(),
            recorder: recorder,
            unmanagedHandler: handler
        )
        let request = try LocalNotificationSystemRequest.delegateFixture(
            physicalRequestID: "AppTemplate.LocalNotification.request.invalid="
        )

        await bridge.processDelivery(
            .init(request: request, deliveredAt: Date(timeIntervalSince1970: 1)),
            completion: { recorder.complete(foreground: $0) }
        )

        #expect(recorder.foregroundCompletions == [[.banner]])
        #expect(recorder.order == [.unmanaged, .completion])
        #expect(recorder.publishedEvents.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func successfulUnmanagedHandlerFinishesWorkBeforeBridgeCompletion() async throws {
        let recorder = DelegateCallbackRecorder()
        let handler = NotificationCenterUnmanagedHandler(
            foreground: { _ in
                recorder.recordUnmanagedWork()
                return [.list, .sound]
            },
            response: { _ in recorder.recordUnmanagedWork() }
        )
        let bridge = try NotificationCenterDelegateBridge.fixture(
            eventHub: makeLocalNotificationEventHub(),
            recorder: recorder,
            unmanagedHandler: handler
        )
        let request = try LocalNotificationSystemRequest.delegateFixture(
            physicalRequestID: "remote.request"
        )

        await bridge.processDelivery(
            .init(request: request, deliveredAt: Date(timeIntervalSince1970: 1)),
            completion: { recorder.complete(foreground: $0) }
        )
        await bridge.processResponse(
            .init(
                request: request,
                deliveredAt: Date(timeIntervalSince1970: 1),
                kind: .button(identifier: "remote.action")
            ),
            completion: { recorder.completeResponse() }
        )

        #expect(recorder.foregroundCompletions == [[.list, .sound]])
        #expect(recorder.completionCount == 2)
        #expect(recorder.order == [.unmanaged, .completion, .unmanaged, .completion])
        #expect(recorder.publishedEvents.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func throwingUnmanagedHandlerDefaultsBothCallbacksAndCompletesOnce() async throws {
        let recorder = DelegateCallbackRecorder()
        let handler = NotificationCenterUnmanagedHandler(
            foreground: { _ in throw DelegateBridgeTestError.unmanaged },
            response: { _ in throw DelegateBridgeTestError.unmanaged }
        )
        let bridge = try NotificationCenterDelegateBridge.fixture(
            eventHub: makeLocalNotificationEventHub(),
            recorder: recorder,
            unmanagedHandler: handler
        )
        let request = try LocalNotificationSystemRequest.delegateFixture(
            physicalRequestID: "remote.request"
        )

        await bridge.processDelivery(
            .init(request: request, deliveredAt: Date(timeIntervalSince1970: 1)),
            completion: { recorder.complete(foreground: $0) }
        )
        await bridge.processResponse(
            .init(request: request, deliveredAt: Date(timeIntervalSince1970: 1), kind: .dismiss),
            completion: { recorder.completeResponse() }
        )

        #expect(recorder.foregroundCompletions == [[]])
        #expect(recorder.completionCount == 2)
        #expect(recorder.order == [.completion, .completion])
        #expect(recorder.publishedEvents.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelledUnmanagedHandlerDefaultsBothCallbacksAndCompletesOnce() async throws {
        let recorder = DelegateCallbackRecorder()
        let handler = NotificationCenterUnmanagedHandler(
            foreground: { _ in throw CancellationError() },
            response: { _ in throw CancellationError() }
        )
        let bridge = try NotificationCenterDelegateBridge.fixture(
            eventHub: makeLocalNotificationEventHub(),
            recorder: recorder,
            unmanagedHandler: handler
        )
        let request = try LocalNotificationSystemRequest.delegateFixture(
            physicalRequestID: "remote.request"
        )

        await bridge.processDelivery(
            .init(request: request, deliveredAt: Date(timeIntervalSince1970: 1)),
            completion: { recorder.complete(foreground: $0) }
        )
        await bridge.processResponse(
            .init(request: request, deliveredAt: Date(timeIntervalSince1970: 1), kind: .dismiss),
            completion: { recorder.completeResponse() }
        )

        #expect(recorder.foregroundCompletions == [[]])
        #expect(recorder.completionCount == 2)
        #expect(recorder.order == [.completion, .completion])
        #expect(recorder.publishedEvents.isEmpty)
    }

    @Test
    func bridgeIsOneNSObjectDelegateThatCanBeStronglyRetained() throws {
        let bridge = try NotificationCenterDelegateBridge.fixture(
            eventHub: makeLocalNotificationEventHub(),
            recorder: DelegateCallbackRecorder()
        )
        let retained: NSObject & UNUserNotificationCenterDelegate = bridge

        #expect(retained === bridge)
    }

    @Test
    @MainActor
    func runtimeFactoryInstallsInjectedDelegateWithoutResolvingTheSharedCenter() throws {
        let recorder = RuntimeInstallerRecorder()
        let client = UserNotificationCenterClient(api: EmptyUserNotificationCenterAPI())
        let runtime = UserNotificationCenterRuntimeFactory.make(
            makeClient: { client },
            installDelegate: { delegate in recorder.install(delegate) }
        )
        let bridge = try NotificationCenterDelegateBridge.fixture(
            eventHub: makeLocalNotificationEventHub(),
            recorder: DelegateCallbackRecorder()
        )

        runtime.installDelegate(bridge)

        #expect(runtime.client === client)
        #expect(recorder.delegates.count == 1)
        #expect(recorder.delegates.first === bridge)
    }
}

private extension NotificationCenterDelegateBridge {
    static func fixture(
        eventHub: LocalNotificationEventHub,
        recorder: DelegateCallbackRecorder,
        unmanagedHandler: NotificationCenterUnmanagedHandler? = nil
    ) throws -> NotificationCenterDelegateBridge {
        NotificationCenterDelegateBridge(
            namespace: try LocalNotificationNamespace(),
            deepLinkPolicy: .init { $0.scheme == "apptemplate" },
            eventPublisher: LocalNotificationDelegateEventPublisher { event in
                await eventHub.publish(event)
                recorder.recordPublishBoundary(event)
            },
            responseDispatcher: DelegateDispatcherNoop(),
            unmanagedHandler: unmanagedHandler
        )
    }
}

private actor DelegateDispatcherNoop: IStoreNotificationActionDispatching {
    func handle(_ response: ManagedLocalNotificationResponse) async {
        _ = response
    }
}

private nonisolated final class DelegateOrderTrace: Sendable {
    enum Step: Equatable, Sendable {
        case history
        case published
        case dispatched
        case completion
    }

    private let state = Mutex<[Step]>([])
    var values: [Step] { state.withLock { $0 } }
    func record(_ value: Step) { state.withLock { $0.append(value) } }
}

private actor DelegateOrderDispatcher: IStoreNotificationActionDispatching {
    let trace: DelegateOrderTrace
    init(trace: DelegateOrderTrace) { self.trace = trace }
    func handle(_ response: ManagedLocalNotificationResponse) async {
        _ = response
        trace.record(.dispatched)
    }
}

private extension LocalNotificationSystemResponse {
    static func delegateFixture(
        kind: LocalNotificationSystemResponse.Kind,
        request: LocalNotificationSystemRequest? = nil
    ) throws -> Self {
        Self(
            request: try request ?? .delegateFixture(),
            deliveredAt: Date(timeIntervalSince1970: 456),
            kind: kind
        )
    }
}

private extension LocalNotificationEnvelopeV1 {
    static func delegateFixture(
        requestID: LocalNotificationID
    ) throws -> Self {
        try delegateFixture(
            requestID: requestID,
            defaultDeepLink: URL(string: "apptemplate://projects/project/request")
        )
    }

    static func delegateFixture(
        requestID: LocalNotificationID,
        defaultDeepLink: URL?
    ) throws -> Self {
        Self(
            requestID: requestID,
            categoryID: try LocalNotificationCategoryID("category"),
            sound: .named(resourceName: "reminder.aiff"),
            metadata: ["private": .string("metadata")],
            defaultDeepLink: defaultDeepLink,
            foregroundPresentation: [.banner, .list, .sound, .badge],
            actionRoutes: [
                .button(
                    id: try LocalNotificationActionID("open"),
                    deepLink: URL(string: "apptemplate://projects/project/action")
                ),
                .button(id: try LocalNotificationActionID("no-route"), deepLink: nil),
                .textInput(
                    id: try LocalNotificationActionID("reply"),
                    deepLink: URL(string: "apptemplate://projects/project/reply")
                )
            ]
        )
    }
}

private enum DelegateEnvelopeData {
    case encoded
    case value(Data?)
}

private enum DelegateCategoryIdentifier {
    case none
    case logical(String)
    case raw(String)
}

private extension LocalNotificationSystemRequest {
    static func delegateFixture(
        physicalRequestID: String? = nil,
        envelope: LocalNotificationEnvelopeV1? = nil,
        envelopeData: DelegateEnvelopeData = .encoded,
        categoryIdentifier: DelegateCategoryIdentifier = .logical("category"),
        trigger: LocalNotificationSystemTrigger = .timeInterval(seconds: 120, repeats: true),
        attachments: [LocalNotificationSystemAttachment] = []
    ) throws -> Self {
        let namespace = try LocalNotificationNamespace()
        let requestID = try LocalNotificationID("request")
        let envelope = try envelope ?? .delegateFixture(requestID: requestID)
        let encodedEnvelope: Data?
        switch envelopeData {
        case .encoded:
            encodedEnvelope = try LocalNotificationEnvelopeCodec.encode(envelope)
        case let .value(value):
            encodedEnvelope = value
        }
        let physicalCategoryID: String?
        switch categoryIdentifier {
        case .none:
            physicalCategoryID = nil
        case let .logical(value):
            physicalCategoryID = namespace.physicalCategoryID(
                try LocalNotificationCategoryID(value)
            )
        case let .raw(value):
            physicalCategoryID = value
        }
        return LocalNotificationSystemRequest(
            identifier: physicalRequestID ?? namespace.physicalRequestID(requestID),
            content: LocalNotificationSystemContent(
                title: "Visible title",
                subtitle: "Visible subtitle",
                body: "Visible body",
                badge: 7,
                sound: .default,
                categoryIdentifier: physicalCategoryID,
                threadIdentifier: "thread",
                targetContentIdentifier: "target",
                summaryArgument: "Summary",
                summaryArgumentCount: 3,
                relevanceScore: 0.75,
                interruptionLevel: .passive,
                attachments: attachments,
                envelopeData: encodedEnvelope
            ),
            trigger: trigger,
            nextTriggerDate: Date(timeIntervalSince1970: 576)
        )
    }
}

private extension LocalNotificationSystemAttachment {
    static func delegateFixture(
        requestID: String,
        attachmentID: String,
        typeIdentifier: String? = "public.png"
    ) throws -> Self {
        let namespace = try LocalNotificationNamespace()
        return Self(
            identifier: namespace.physicalAttachmentID(
                try LocalNotificationID(requestID),
                try LocalNotificationAttachmentID(attachmentID)
            ),
            fileURL: URL(fileURLWithPath: "/system/" + attachmentID + ".png"),
            typeIdentifier: typeIdentifier
        )
    }
}

private struct OwnedResponseResult {
    let event: LocalNotificationEvent
    let recorder: DelegateCallbackRecorder
}

private func processOwnedResponse(
    _ response: LocalNotificationSystemResponse
) async throws -> OwnedResponseResult {
    let hub = makeLocalNotificationEventHub()
    let stream = await hub.events()
    let recorder = DelegateCallbackRecorder()
    let bridge = try NotificationCenterDelegateBridge.fixture(
        eventHub: hub,
        recorder: recorder
    )

    await bridge.processResponse(response) { recorder.completeResponse() }
    let event = try await firstDelegateEvent(from: stream)
    recorder.recordObservedEvent(event)
    return OwnedResponseResult(event: event, recorder: recorder)
}

private func expectForegroundDiagnostic(
    request: LocalNotificationSystemRequest,
    reason: LocalNotificationDiagnosticReason
) async throws {
    let hub = makeLocalNotificationEventHub()
    let stream = await hub.events()
    let recorder = DelegateCallbackRecorder()
    let bridge = try NotificationCenterDelegateBridge.fixture(
        eventHub: hub,
        recorder: recorder
    )

    await bridge.processDelivery(
        .init(request: request, deliveredAt: Date(timeIntervalSince1970: 456)),
        completion: { recorder.complete(foreground: $0) }
    )
    let event = try await firstDelegateEvent(from: stream)
    recorder.recordObservedEvent(event)

    #expect(event == .diagnostic(.init(
        id: try LocalNotificationID("request"),
        reason: reason
    )))
    #expect(recorder.foregroundCompletions == [[]])
    #expect(recorder.completionCount == 1)
    #expect(recorder.publishedEvents == [event])
    #expect(recorder.order == [.published, .completion, .observedEvent])
}

private func firstDelegateEvent(
    from stream: AsyncStream<LocalNotificationEvent>
) async throws -> LocalNotificationEvent {
    var iterator = stream.makeAsyncIterator()
    return try #require(await iterator.next())
}

private nonisolated final class DelegateCallbackRecorder: Sendable {
    enum Step: Hashable, Sendable {
        case published
        case unmanaged
        case completion
        case observedEvent
    }

    private struct State: Sendable {
        var order: [Step] = []
        var foregroundCompletions: [LocalNotificationForegroundPresentation] = []
        var responseCompletions = 0
        var publishedEvents: [LocalNotificationEvent] = []
    }

    private let state = Mutex(State())

    var order: [Step] { state.withLock { $0.order } }
    var completionCount: Int {
        state.withLock { $0.foregroundCompletions.count + $0.responseCompletions }
    }
    var foregroundCompletions: [LocalNotificationForegroundPresentation] {
        state.withLock { $0.foregroundCompletions }
    }
    var publishedEvents: [LocalNotificationEvent] { state.withLock { $0.publishedEvents } }

    func recordObservedEvent(_ event: LocalNotificationEvent) {
        _ = event
        state.withLock { $0.order.append(.observedEvent) }
    }

    func recordPublishBoundary(_ event: LocalNotificationEvent) {
        state.withLock {
            $0.order.append(.published)
            $0.publishedEvents.append(event)
        }
    }

    func complete(foreground options: LocalNotificationForegroundPresentation) {
        state.withLock {
            $0.order.append(.completion)
            $0.foregroundCompletions.append(options)
        }
    }

    func completeResponse() {
        state.withLock {
            $0.order.append(.completion)
            $0.responseCompletions += 1
        }
    }

    func recordUnmanagedWork() {
        state.withLock { $0.order.append(.unmanaged) }
    }

    func expectOneResponseCompletionAfterPublish() {
        #expect(completionCount == 1)
        #expect(order == [.published, .completion, .observedEvent])
    }
}

@MainActor
private final class RuntimeInstallerRecorder {
    var delegates: [any UNUserNotificationCenterDelegate] = []

    func install(_ delegate: any UNUserNotificationCenterDelegate) {
        delegates.append(delegate)
    }
}

private enum DelegateBridgeTestError: Error, Sendable {
    case unmanaged
}

@MainActor
private final class EmptyUserNotificationCenterAPI: UserNotificationCenterAPI {
    func notificationSettings() async -> UNNotificationSettings {
        preconditionFailure("Unused")
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        preconditionFailure("Unused")
    }

    func notificationCategories() async -> Set<UNNotificationCategory> { [] }
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) async {}
    func add(_ request: UNNotificationRequest) async throws {}
    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
    func deliveredNotifications() async -> [UNNotification] { [] }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async {}
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) async {}
    func setBadgeCount(_ count: Int) async throws {}
}
