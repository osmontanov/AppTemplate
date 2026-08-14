import Foundation
import Testing
@testable import AppTemplate

struct ProductReminderMetadataTests {
    @Test
    func metadataRoundTripsOnlyOnePositiveInteger() throws {
        let metadata = try ProductReminderMetadata(productID: 7)

        #expect(metadata.notificationValues == ["productID": .integer(7)])
        #expect(try ProductReminderMetadata.decode(metadata.notificationValues) == metadata)
    }

    @Test(arguments: [0, -1])
    func metadataAndIdentifiersRejectNonPositiveProductIDs(_ productID: Int) {
        #expect(throws: ProductReminderError.invalidProductID) {
            _ = try ProductReminderMetadata(productID: productID)
        }
        #expect(throws: ProductReminderError.invalidProductID) {
            _ = try AppNotificationIdentifiers.productRequest(productID)
        }
        #expect(throws: ProductReminderError.invalidProductID) {
            _ = try AppNotificationIdentifiers.productDeepLink(productID)
        }
    }

    @Test
    func metadataRejectsMissingWrongTypedAndExtraValues() {
        let malformed: [[String: LocalNotificationMetadataValue]] = [
            [:],
            ["productID": .string("7")],
            ["productID": .integer(0)],
            ["productID": .integer(-7)],
            ["productID": .integer(7), "extra": .boolean(true)]
        ]

        for values in malformed {
            #expect(throws: ProductReminderError.invalidRescheduleSource) {
                _ = try ProductReminderMetadata.decode(values)
            }
        }
    }

    @Test
    func rescheduleSourceCopiesOnlySafeStoredTextAndSound() throws {
        let source = try ProductReminderRescheduleSource.decode(
            from: ProductReminderFixtures.event()
        )

        #expect(source.requestID.value == "store.product-reminder.7")
        #expect(source.metadata.productID == 7)
        #expect(source.title == "Price reminder")
        #expect(source.subtitle == "Product")
        #expect(source.body == "Take another look.")
        #expect(source.sound == .default)
    }

    @Test
    func rescheduleSourceRejectsUnreadableForeignAndMismatchedStoredRequests() throws {
        let expectedID = try AppNotificationIdentifiers.productRequest(7)
        let foreignCategory = try LocalNotificationCategoryID("foreign")
        let foreign = try ProductReminderFixtures.storedRequest(categoryID: foreignCategory)
        let wrongRequestID = try ProductReminderFixtures.storedRequest(
            notificationID: LocalNotificationID("store.product-reminder.8")
        )
        let wrongMetadata = try ProductReminderFixtures.storedRequest(
            metadata: ["productID": .integer(8)]
        )
        let wrongLink = try ProductReminderFixtures.storedRequest(
            deepLink: URL(string: "apptemplate://store/product/8")!
        )
        let cases: [LocalNotificationEvent] = [
            .opened(
                notification: LocalNotificationEventNotification(
                    id: expectedID,
                    payload: .unreadable(.corruptEnvelope)
                ),
                deepLink: nil
            ),
            try ProductReminderFixtures.event(request: foreign),
            try ProductReminderFixtures.event(request: wrongRequestID),
            try ProductReminderFixtures.event(request: wrongMetadata),
            try ProductReminderFixtures.event(request: wrongLink),
            try ProductReminderFixtures.event(
                eventID: LocalNotificationID("store.product-reminder.8")
            ),
            .diagnostic(LocalNotificationDiagnostic(id: expectedID, reason: .corruptEnvelope))
        ]

        for event in cases {
            #expect(throws: ProductReminderError.invalidRescheduleSource) {
                _ = try ProductReminderRescheduleSource.decode(from: event)
            }
        }
    }
}
