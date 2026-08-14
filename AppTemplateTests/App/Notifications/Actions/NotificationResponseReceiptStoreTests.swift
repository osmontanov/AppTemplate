import Foundation
import Testing
@testable import AppTemplate

struct NotificationResponseReceiptStoreTests {
    @Test
    func duplicateReceiptIsIgnoredButDifferentActionForRequestIsAccepted() async throws {
        let store = NotificationResponseReceiptStore()
        let requestID = try LocalNotificationID("request")
        let deliveredAt = Date(timeIntervalSince1970: 7)
        let opened = NotificationResponseReceipt(
            requestID: requestID,
            kind: .opened,
            deliveredAt: deliveredAt
        )
        let favorite = NotificationResponseReceipt(
            requestID: requestID,
            kind: .action(AppNotificationIdentifiers.favoriteAction),
            deliveredAt: deliveredAt
        )

        #expect(await store.insertIfNew(opened))
        #expect(!(await store.insertIfNew(opened)))
        #expect(await store.insertIfNew(favorite))
    }

    @Test
    func capacityEvictsOldestReceiptAtOneHundredAndOne() async throws {
        let store = NotificationResponseReceiptStore(capacity: 100)
        let deliveredAt = Date(timeIntervalSince1970: 7)
        let first = NotificationResponseReceipt(
            requestID: try LocalNotificationID("request-0"),
            kind: .opened,
            deliveredAt: deliveredAt
        )
        #expect(await store.insertIfNew(first))
        for index in 1...100 {
            #expect(await store.insertIfNew(.init(
                requestID: try LocalNotificationID("request-\(index)"),
                kind: .opened,
                deliveredAt: deliveredAt
            )))
        }

        #expect(await store.insertIfNew(first))
        #expect(!(await store.insertIfNew(.init(
            requestID: try LocalNotificationID("request-100"),
            kind: .opened,
            deliveredAt: deliveredAt
        ))))
    }
}
