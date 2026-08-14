import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct StoreNotificationActionDispatcherTests {
    @Test(.timeLimit(.minutes(1)))
    func defaultOpenAndOpenButtonConvergeWhileFavoriteRemainsDistinct() async throws {
        let fixture = try makeFixture()
        let responseDate = Date(timeIntervalSince1970: 10)
        let notification = try storeNotification(productID: 7)

        await fixture.dispatcher.handle(.init(
            event: .opened(
                notification: notification,
                deepLink: URL(string: "apptemplate://store/product/7")
            ),
            deliveredAt: responseDate
        ))
        await fixture.dispatcher.handle(.init(
            event: .action(
                notification: notification,
                id: AppNotificationIdentifiers.openProductAction,
                deepLink: URL(string: "apptemplate://store/product/7")
            ),
            deliveredAt: responseDate
        ))
        await fixture.dispatcher.handle(.init(
            event: .action(
                notification: notification,
                id: AppNotificationIdentifiers.favoriteAction,
                deepLink: nil
            ),
            deliveredAt: responseDate
        ))
        await fixture.receiver.waitForCount(2)

        #expect(fixture.receiver.commands == [
            .navigate(.openProduct(7)),
            .protected(.favorite(7))
        ])
        #expect(await fixture.diagnostics.values.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func remindLaterAwaitsTenMinuteRescheduleAndDuplicateDoesNotRepeat() async throws {
        let reminders = DispatcherReminderSpy(blocksRemindLater: true)
        let fixture = try makeFixture(reminders: reminders)
        let response = ManagedLocalNotificationResponse(
            event: try ProductReminderFixtures.event(productID: 7),
            deliveredAt: Date(timeIntervalSince1970: 10)
        )
        let task = Task { await fixture.dispatcher.handle(response) }
        await reminders.waitUntilRemindLaterStarted()
        #expect(!task.isCancelled)
        #expect(await reminders.invocations.count == 0)

        await reminders.finishRemindLater()
        await task.value
        await fixture.dispatcher.handle(response)

        let invocations = await reminders.invocations
        #expect(invocations.count == 1)
        #expect(invocations.first?.delay == .seconds(600))
    }

    @Test(.timeLimit(.minutes(1)))
    func invalidStoreMetadataAndActionFailurePublishSafeDiagnosticsWithoutCommands() async throws {
        let reminders = DispatcherReminderSpy(failure: DispatcherTestFailure.schedule)
        let fixture = try makeFixture(reminders: reminders)
        let invalid = try storeNotification(
            productID: 7,
            metadata: ["private": .string("SECRET")]
        )
        await fixture.dispatcher.handle(.init(
            event: .opened(notification: invalid, deepLink: nil),
            deliveredAt: Date(timeIntervalSince1970: 1)
        ))
        await fixture.dispatcher.handle(.init(
            event: try ProductReminderFixtures.event(productID: 8),
            deliveredAt: Date(timeIntervalSince1970: 2)
        ))

        #expect(fixture.receiver.commands.isEmpty)
        #expect(await fixture.diagnostics.values.map(\.reason) == [
            .invalidStoreMetadata,
            .storeActionFailed
        ])
        #expect(!String(describing: await fixture.diagnostics.values).contains("SECRET"))
    }

    @Test
    func dismissalAndTextInputAreObservationOnlyAndCreateNoReceipt() async throws {
        let fixture = try makeFixture()
        let notification = try storeNotification(productID: 7)
        let deliveredAt = Date(timeIntervalSince1970: 10)
        await fixture.dispatcher.handle(.init(
            event: .dismissed(notification: notification),
            deliveredAt: deliveredAt
        ))
        await fixture.dispatcher.handle(.init(
            event: .textAction(
                notification: notification,
                id: try LocalNotificationActionID("reply"),
                text: "PRIVATE",
                deepLink: nil
            ),
            deliveredAt: deliveredAt
        ))

        #expect(fixture.receiver.commands.isEmpty)
        #expect(await fixture.receipts.insertIfNew(.init(
            requestID: notification.id,
            kind: .opened,
            deliveredAt: deliveredAt
        )))
    }
}

private extension StoreNotificationActionDispatcherTests {
    struct Fixture {
        let dispatcher: StoreNotificationActionDispatcher
        let receiver: DispatcherReceiverSpy
        let receipts: NotificationResponseReceiptStore
        let diagnostics: DispatcherDiagnosticSpy
    }

    func makeFixture(
        reminders: DispatcherReminderSpy = DispatcherReminderSpy()
    ) throws -> Fixture {
        let receiver = DispatcherReceiverSpy()
        let coordinator = LocalNotificationNavigationCoordinator()
        let id = UUID()
        coordinator.register(id: id, receiver: receiver)
        coordinator.setReadiness(.init(
            isRestored: true,
            isMain: true,
            isReady: true,
            isPlatformEligible: true
        ), id: id)
        let receipts = NotificationResponseReceiptStore()
        let diagnostics = DispatcherDiagnosticSpy()
        return Fixture(
            dispatcher: StoreNotificationActionDispatcher(
                coordinator: coordinator,
                reminders: reminders,
                receipts: receipts,
                diagnosticSink: { await diagnostics.record($0) }
            ),
            receiver: receiver,
            receipts: receipts,
            diagnostics: diagnostics
        )
    }
}

private enum DispatcherTestFailure: Error, Sendable { case schedule }

private actor DispatcherReminderSpy: IProductReminderRepository {
    struct Invocation: Sendable {
        let source: ProductReminderRescheduleSource
        let delay: Duration
    }

    private let blocksRemindLater: Bool
    private let failure: (any Error & Sendable)?
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var finishContinuation: CheckedContinuation<Void, Never>?
    private(set) var invocations: [Invocation] = []

    init(
        blocksRemindLater: Bool = false,
        failure: (any Error & Sendable)? = nil
    ) {
        self.blocksRemindLater = blocksRemindLater
        self.failure = failure
    }

    func status(productID: Product.ID) async -> ProductReminderStatus {
        _ = productID
        return .notScheduled
    }

    func schedule(
        product: Product,
        selection: ProductReminderSelection
    ) async throws -> ProductReminderScheduleResult {
        _ = product
        _ = selection
        return .scheduled
    }

    func remindLater(
        from source: ProductReminderRescheduleSource,
        after delay: Duration
    ) async throws {
        started = true
        let waiters = startWaiters
        startWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        if blocksRemindLater {
            await withCheckedContinuation { finishContinuation = $0 }
        }
        if let failure { throw failure }
        invocations.append(.init(source: source, delay: delay))
    }

    func cancel(productID: Product.ID) async { _ = productID }

    func waitUntilRemindLaterStarted() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func finishRemindLater() {
        finishContinuation?.resume()
        finishContinuation = nil
    }
}

private actor DispatcherDiagnosticSpy {
    private(set) var values: [LocalNotificationDiagnostic] = []
    func record(_ value: LocalNotificationDiagnostic) { values.append(value) }
}

@MainActor
private final class DispatcherReceiverSpy: LocalNotificationSceneReceiving {
    private(set) var commands: [NotificationNavigationCommand] = []
    func receiveNotificationCommand(_ command: NotificationNavigationCommand) async {
        commands.append(command)
    }
    func waitForCount(_ count: Int) async {
        while commands.count < count { await Task.yield() }
    }
}

private func storeNotification(
    productID: Product.ID,
    metadata: [String: LocalNotificationMetadataValue]? = nil
) throws -> LocalNotificationEventNotification {
    let id = try AppNotificationIdentifiers.productRequest(productID)
    let typed = try ProductReminderMetadata(productID: productID)
    return LocalNotificationEventNotification(
        id: id,
        payload: .decoded(LocalNotificationStoredRequest(
            id: id,
            content: LocalNotificationStoredContent(
                title: "Product reminder",
                body: "Body",
                sound: .default,
                categoryID: AppNotificationIdentifiers.storeCategory,
                metadata: metadata ?? typed.notificationValues,
                deepLink: try AppNotificationIdentifiers.productDeepLink(productID)
            ),
            trigger: .immediate
        ))
    )
}
