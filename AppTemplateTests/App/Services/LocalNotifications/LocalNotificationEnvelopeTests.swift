import Foundation
import Testing
@testable import AppTemplate

nonisolated
struct LocalNotificationEnvelopeTests {
    @Test
    func envelopeRoundTripsAllServiceOwnedState() throws {
        let envelope = LocalNotificationEnvelopeV1(
            requestID: try .init("request"),
            categoryID: try .init("category"),
            sound: .named(resourceName: "reminder.aiff"),
            metadata: ["project": .object(["priority": .integer(2)])],
            defaultDeepLink: URL(string: "apptemplate://projects/project/p1")!,
            foregroundPresentation: [.banner, .list],
            actionRoutes: [
                .button(
                    id: try .init("open"),
                    deepLink: URL(string: "apptemplate://projects/project/p1")!
                ),
                .textInput(
                    id: try .init("reply"),
                    deepLink: URL(string: "apptemplate://projects/project/p1")!
                )
            ]
        )

        let data = try LocalNotificationEnvelopeCodec.encode(envelope)

        #expect(try LocalNotificationEnvelopeCodec.decode(data) == .v1(envelope))
        #expect(!String(decoding: data, as: UTF8.self).contains("VISIBLE-TITLE"))
        #expect(!String(decoding: data, as: UTF8.self).contains("/private/source.mov"))
    }

    @Test
    func futureVersionIsTypedAndRedacted() {
        let future = Data(#"{"schemaVersion":99}"#.utf8)

        #expect(throws: LocalNotificationServiceError.unsupportedEnvelopeVersion(99)) {
            try LocalNotificationEnvelopeCodec.decode(future)
        }
        #expect(LocalNotificationServiceError.unsupportedEnvelopeVersion(99).errorDescription == "Local notification envelope version is unsupported.")
    }

    @Test
    func missingEnvelopeIsTypedAndRedacted() throws {
        let physicalRequestID = try LocalNotificationNamespace().physicalRequestID(.init("request"))

        #expect(throws: LocalNotificationEnvelopeError.missingEnvelope) {
            try LocalNotificationEnvelopeCodec.decodeManaged(
                nil,
                physicalRequestID: physicalRequestID,
                namespace: try LocalNotificationNamespace(),
                deepLinkPolicy: acceptingDeepLinks()
            )
        }
        #expect(LocalNotificationEnvelopeError.missingEnvelope.errorDescription == "Local notification envelope is unavailable.")
    }

    @Test
    func corruptEnvelopeIsTypedAndRedacted() throws {
        let physicalRequestID = try LocalNotificationNamespace().physicalRequestID(.init("request"))
        let corrupt = Data("not-json".utf8)

        #expect(throws: LocalNotificationEnvelopeError.corruptEnvelope) {
            try LocalNotificationEnvelopeCodec.decodeManaged(
                corrupt,
                physicalRequestID: physicalRequestID,
                namespace: try LocalNotificationNamespace(),
                deepLinkPolicy: acceptingDeepLinks()
            )
        }
        #expect(LocalNotificationEnvelopeError.corruptEnvelope.errorDescription == "Local notification envelope is unreadable.")
    }

    @Test
    func envelopeRequestIDMustMatchThePhysicalRequestID() throws {
        let envelope = LocalNotificationEnvelopeV1.fixture(
            requestID: try .init("logical"),
            sound: .none,
            deepLink: nil
        )
        let data = try LocalNotificationEnvelopeCodec.encode(envelope)
        let physicalRequestID = try LocalNotificationNamespace().physicalRequestID(.init("other"))

        #expect(throws: LocalNotificationEnvelopeError.identifierMismatch) {
            try LocalNotificationEnvelopeCodec.decodeManaged(
                data,
                physicalRequestID: physicalRequestID,
                namespace: try LocalNotificationNamespace(),
                deepLinkPolicy: acceptingDeepLinks()
            )
        }
        #expect(LocalNotificationEnvelopeError.identifierMismatch.errorDescription == "Local notification envelope does not match its request.")
    }

    @Test
    func noncanonicalPhysicalRequestIDIsCorrupt() throws {
        let envelope = LocalNotificationEnvelopeV1.fixture(
            requestID: try .init("request"),
            sound: .none,
            deepLink: nil
        )
        let data = try LocalNotificationEnvelopeCodec.encode(envelope)
        let noncanonicalPhysicalRequestID = "AppTemplate.LocalNotification.request.cmVxdWVzdA="

        #expect(throws: LocalNotificationEnvelopeError.corruptEnvelope) {
            try LocalNotificationEnvelopeCodec.decodeManaged(
                data,
                physicalRequestID: noncanonicalPhysicalRequestID,
                namespace: try LocalNotificationNamespace(),
                deepLinkPolicy: acceptingDeepLinks()
            )
        }
    }

    @Test
    func actionRoutesPreserveButtonAndTextInputDeepLinks() throws {
        let buttonID = try LocalNotificationActionID("button")
        let textInputID = try LocalNotificationActionID("text-input")
        let route = URL(string: "apptemplate://projects/project/p1")!
        let envelope = LocalNotificationEnvelopeV1.fixture(
            requestID: try .init("request"),
            sound: .default,
            deepLink: nil,
            actionRoutes: [
                .button(id: buttonID, deepLink: route),
                .textInput(id: textInputID, deepLink: route)
            ]
        )

        #expect(try LocalNotificationEnvelopeCodec.decode(try LocalNotificationEnvelopeCodec.encode(envelope)) == .v1(envelope))
    }

    @Test
    func rejectedDefaultOrActionDeepLinksAreTypedAndRedacted() throws {
        let rejectedURL = URL(string: "https://private.example.invalid/token")!
        let envelope = LocalNotificationEnvelopeV1.fixture(
            requestID: try .init("request"),
            sound: .named(resourceName: "private-sound.aiff"),
            deepLink: rejectedURL,
            metadata: ["PRIVATE-METADATA": .string("PRIVATE-METADATA")],
            actionRoutes: [
                .textInput(id: try .init("reply"), deepLink: rejectedURL)
            ]
        )
        let data = try LocalNotificationEnvelopeCodec.encode(envelope)
        let physicalRequestID = try LocalNotificationNamespace().physicalRequestID(.init("request"))
        let rejectingPolicy = LocalNotificationDeepLinkPolicy { _ in false }

        #expect(try LocalNotificationEnvelopeCodec.decode(data) == .v1(envelope))

        #expect(throws: LocalNotificationServiceError.invalidDeepLink) {
            try LocalNotificationEnvelopeCodec.decodeManaged(
                data,
                physicalRequestID: physicalRequestID,
                namespace: try LocalNotificationNamespace(),
                deepLinkPolicy: rejectingPolicy
            )
        }

        let actionOnlyEnvelope = LocalNotificationEnvelopeV1.fixture(
            requestID: try .init("request"),
            sound: .none,
            deepLink: nil,
            actionRoutes: [
                .textInput(id: try .init("reply"), deepLink: rejectedURL)
            ]
        )
        #expect(throws: LocalNotificationServiceError.invalidDeepLink) {
            try LocalNotificationEnvelopeCodec.decodeManaged(
                try LocalNotificationEnvelopeCodec.encode(actionOnlyEnvelope),
                physicalRequestID: physicalRequestID,
                namespace: try LocalNotificationNamespace(),
                deepLinkPolicy: rejectingPolicy
            )
        }

        let description = try #require(LocalNotificationServiceError.invalidDeepLink.errorDescription)
        for sensitiveValue in [
            "VISIBLE-TITLE",
            "/private/source.mov",
            "private.example.invalid",
            "private-sound.aiff",
            "PRIVATE-METADATA",
            "token"
        ] {
            #expect(!description.contains(sensitiveValue))
        }
    }
}

private extension LocalNotificationEnvelopeV1 {
    nonisolated
    static func fixture(
        requestID: LocalNotificationID,
        sound: LocalNotificationSound,
        deepLink: URL?,
        metadata: [String: LocalNotificationMetadataValue] = [:],
        actionRoutes: [LocalNotificationActionRoute] = []
    ) -> Self {
        Self(
            requestID: requestID,
            categoryID: nil,
            sound: sound,
            metadata: metadata,
            defaultDeepLink: deepLink,
            foregroundPresentation: [.banner, .list],
            actionRoutes: actionRoutes
        )
    }
}

nonisolated
private func acceptingDeepLinks() -> LocalNotificationDeepLinkPolicy {
    LocalNotificationDeepLinkPolicy { _ in true }
}
