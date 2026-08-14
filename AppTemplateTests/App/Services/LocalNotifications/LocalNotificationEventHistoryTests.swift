import Foundation
import Testing
@testable import AppTemplate

struct LocalNotificationEventHistoryTests {
    @Test
    func historyKeepsNewestHundredSafeSemanticSummaries() async throws {
        let history = LocalNotificationEventHistory(clock: .historyFixture)
        for index in 0..<101 {
            await history.append(.diagnostic(.init(
                id: try LocalNotificationID("private-request-\(index)"),
                reason: .missingEnvelope
            )))
        }

        let records = await history.records()
        #expect(records.count == 100)
        #expect(records.first?.id == 1)
        #expect(records.last?.id == 100)
        let rendered = String(describing: records)
        #expect(!rendered.contains("private-request"))
    }

    @Test
    func historyMapsEveryFixedStoreAndLabActionWithoutRetainingRawContent() async throws {
        let history = LocalNotificationEventHistory(clock: .historyFixture)
        let store = try historyNotification(
            id: "store.product-reminder.7",
            categoryID: AppNotificationIdentifiers.storeCategory,
            title: "PRIVATE-TITLE",
            body: "PRIVATE-BODY",
            metadata: ["PRIVATE-METADATA": .string("PRIVATE-VALUE")],
            deepLink: URL(string: "apptemplate://store/product/PRIVATE-PATH")
        )
        let labButton = try LocalNotificationActionID("services.private-button")
        let labText = try LocalNotificationActionID("services.private-text")

        await history.append(.opened(notification: store, deepLink: nil))
        await history.append(.action(
            notification: store,
            id: AppNotificationIdentifiers.openProductAction,
            deepLink: nil
        ))
        await history.append(.action(
            notification: store,
            id: AppNotificationIdentifiers.favoriteAction,
            deepLink: nil
        ))
        await history.append(.action(
            notification: store,
            id: AppNotificationIdentifiers.remindLaterAction,
            deepLink: nil
        ))
        await history.append(.action(
            notification: try historyNotification(id: "lab-button", categoryID: nil),
            id: labButton,
            deepLink: nil
        ))
        await history.append(.textAction(
            notification: try historyNotification(id: "lab-text", categoryID: nil),
            id: labText,
            text: "PRIVATE-TEXT",
            deepLink: nil
        ))

        let records = await history.records()
        #expect(records.map(\.summary.actionKind) == [
            .openProduct,
            .openProduct,
            .favorite,
            .remindLater,
            .labButton,
            .labTextInput
        ])
        #expect(records.map(\.summary.textInputCharacterCount) == [
            nil, nil, nil, nil, nil, 12
        ])
        let rendered = String(describing: records)
        for sentinel in [
            AppNotificationIdentifiers.openProductAction.value,
            AppNotificationIdentifiers.favoriteAction.value,
            AppNotificationIdentifiers.remindLaterAction.value,
            "PRIVATE-TITLE", "PRIVATE-BODY", "PRIVATE-METADATA",
            "PRIVATE-VALUE", "PRIVATE-PATH", "PRIVATE-TEXT",
            labButton.value, labText.value
        ] {
            #expect(!rendered.contains(sentinel))
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func updatesYieldSnapshotAtomicallyAndTerminationRemovesSubscriber() async throws {
        let history = LocalNotificationEventHistory(clock: .historyFixture)
        await history.append(.diagnostic(.init(id: nil, reason: .corruptEnvelope)))
        let stream = await history.updates()
        #expect(await history.activeSubscriptionCount == 1)
        let task = Task { () -> [LocalNotificationEventRecord]? in
            var iterator = stream.makeAsyncIterator()
            return await iterator.next()
        }
        #expect(await task.value?.count == 1)

        let waiting = Task { () -> [LocalNotificationEventRecord]? in
            var iterator = stream.makeAsyncIterator()
            return await iterator.next()
        }
        waiting.cancel()
        _ = await waiting.value
        await history.waitUntilSubscriptionCountForTesting(0)
        #expect(await history.activeSubscriptionCount == 0)
    }
}

private extension AppClock {
    static let historyFixture = AppClock(
        now: { Date(timeIntervalSince1970: 123) },
        monotonicNow: { ContinuousClock().now },
        sleep: { _ in }
    )
}

private func historyNotification(
    id: String,
    categoryID: LocalNotificationCategoryID?,
    title: String = "",
    body: String = "",
    metadata: [String: LocalNotificationMetadataValue] = [:],
    deepLink: URL? = nil
) throws -> LocalNotificationEventNotification {
    let requestID = try LocalNotificationID(id)
    return LocalNotificationEventNotification(
        id: requestID,
        payload: .decoded(LocalNotificationStoredRequest(
            id: requestID,
            content: LocalNotificationStoredContent(
                title: title,
                body: body,
                categoryID: categoryID,
                metadata: metadata,
                deepLink: deepLink
            ),
            trigger: .immediate
        ))
    )
}
