import Foundation
import Testing
@testable import AppTemplate

nonisolated
struct LocalNotificationModelTests {
    @Test
    func identifiersRoundTripThroughThePhysicalNamespace() throws {
        let namespace = try LocalNotificationNamespace("AppTemplate.LocalNotification")
        let logical = try LocalNotificationID("Заказ / 42")
        let physical = namespace.physicalRequestID(logical)

        #expect(physical.hasPrefix("AppTemplate.LocalNotification.request."))
        #expect(namespace.logicalRequestID(physical) == logical)
        #expect(namespace.logicalRequestID("remote.request") == nil)
    }

    @Test
    func namespaceRoundTripsEveryOwnedIdentifierFamilyAndRejectsMalformedValues() throws {
        let namespace = try LocalNotificationNamespace()
        let request = try LocalNotificationID("request")
        let category = try LocalNotificationCategoryID("category")
        let action = try LocalNotificationActionID("action")
        let attachment = try LocalNotificationAttachmentID("attachment")

        #expect(namespace.logicalCategoryID(namespace.physicalCategoryID(category)) == category)
        let physicalAction = namespace.physicalActionID(category: category, action: action)
        #expect(namespace.logicalActionID(physicalAction)?.category == category)
        #expect(namespace.logicalActionID(physicalAction)?.action == action)
        let physicalAttachment = namespace.physicalAttachmentID(request: request, attachment: attachment)
        #expect(namespace.logicalAttachmentID(physicalAttachment)?.request == request)
        #expect(namespace.logicalAttachmentID(physicalAttachment)?.attachment == attachment)

        #expect(namespace.logicalRequestID(namespace.physicalCategoryID(category)) == nil)
        #expect(namespace.logicalCategoryID(namespace.physicalRequestID(request)) == nil)
        #expect(namespace.logicalRequestID("AppTemplate.LocalNotification.request.cmVxdWVzdA=") == nil)
        #expect(namespace.logicalActionID("AppTemplate.LocalNotification.action.cmVxdWVzdA") == nil)
        #expect(namespace.logicalAttachmentID("AppTemplate.LocalNotification.attachment.cmVxdWVzdA..YXR0YWNobWVudA") == nil)
    }

    @Test(arguments: [0, 128, 129])
    func identifierEnforcesUTF8ByteBoundary(_ count: Int) throws {
        let value = String(repeating: "a", count: count)
        if count == 128 {
            #expect(try LocalNotificationID(value).value == value)
        } else {
            #expect(throws: LocalNotificationServiceError.invalidIdentifier(.request)) {
                try LocalNotificationID(value)
            }
        }
    }

    @Test(arguments: ["   ", "\n\t", "id\u{0000}", "id\u{001F}"])
    func identifierRejectsWhitespaceAndControls(_ value: String) {
        #expect(throws: LocalNotificationServiceError.invalidIdentifier(.request)) {
            try LocalNotificationID(value)
        }
    }

    @Test
    func identifierDecodingCannotBypassValidation() throws {
        let data = try JSONEncoder().encode("\t")
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LocalNotificationID.self, from: data)
        }
    }

    @Test
    func everyIdentifierUsesUTF8ByteBoundsForMultibyteInput() throws {
        let valid = String(repeating: "é", count: 64)
        let invalid = String(repeating: "é", count: 65)
        for value in [valid, invalid] {
            let isValid = value.utf8.count == 128
            for makeIdentifier in [
            { try LocalNotificationID(value).value },
            { try LocalNotificationCategoryID(value).value },
            { try LocalNotificationActionID(value).value },
            { try LocalNotificationAttachmentID(value).value }
            ] {
                if isValid {
                    #expect(try makeIdentifier() == value)
                } else {
                    #expect(throws: LocalNotificationServiceError.self) { try makeIdentifier() }
                }
            }
        }
    }

    @Test
    func everyIdentifierDecodingAppliesValidation() throws {
        let data = try JSONEncoder().encode("\u{0000}")
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(LocalNotificationCategoryID.self, from: data) }
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(LocalNotificationActionID.self, from: data) }
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(LocalNotificationAttachmentID.self, from: data) }
    }

    @Test
    func actionOptionsDecodingCannotBypassUnknownBitValidation() throws {
        let data = try JSONEncoder().encode(1 << 20)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LocalNotificationActionOptions.self, from: data)
        }
    }

    @Test
    func serviceErrorHasStableCodableAndRedactedPresentation() throws {
        let error = LocalNotificationServiceError.system(
            operation: .schedule,
            domain: "com.example.private",
            code: 42
        )
        let data = try JSONEncoder().encode(error)
        #expect(try JSONDecoder().decode(LocalNotificationServiceError.self, from: data) == error)
        #expect(error.errorDescription == "Local notification system operation failed.")
    }

    @Test
    func interruptionLevelContainsOnlyApprovedCases() {
        #expect(LocalNotificationInterruptionLevel.allCases == [.passive, .active])
    }

    @Test
    func authorizationOptionsRejectUnknownBits() {
        let unknown = LocalNotificationAuthorizationOptions(rawValue: 1 << 20)
        #expect(throws: LocalNotificationServiceError.invalidAuthorizationOptions) {
            try LocalNotificationValidator.validate(authorization: unknown)
        }
    }

    @Test
    func optionSetDecodingCannotBypassUnknownBitValidation() throws {
        let authorizationData = try JSONEncoder().encode(1 << 20)
        let foregroundData = try JSONEncoder().encode(1 << 20)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LocalNotificationAuthorizationOptions.self, from: authorizationData)
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LocalNotificationForegroundPresentation.self, from: foregroundData)
        }
    }

    @Test
    func metadataRoundTripsWithoutAny() throws {
        let value: LocalNotificationMetadataValue = .object([
            "count": .integer(42),
            "flags": .array([.boolean(true), .null]),
            "ratio": .double(0.5)
        ])
        let data = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(LocalNotificationMetadataValue.self, from: data) == value)
    }
}
