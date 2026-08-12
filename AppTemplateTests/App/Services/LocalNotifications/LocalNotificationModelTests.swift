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
