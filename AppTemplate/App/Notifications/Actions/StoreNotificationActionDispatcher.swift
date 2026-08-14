import Foundation

nonisolated protocol IStoreNotificationActionDispatching: Sendable {
    func handle(_ response: ManagedLocalNotificationResponse) async
}

actor StoreNotificationActionDispatcher: IStoreNotificationActionDispatching {
    private let coordinator: LocalNotificationNavigationCoordinator
    private let reminders: any IProductReminderRepository
    private let receipts: NotificationResponseReceiptStore
    private let diagnosticSink: @Sendable (LocalNotificationDiagnostic) async -> Void

    init(
        coordinator: LocalNotificationNavigationCoordinator,
        reminders: any IProductReminderRepository,
        receipts: NotificationResponseReceiptStore,
        diagnosticSink: @escaping @Sendable (LocalNotificationDiagnostic) async -> Void
    ) {
        self.coordinator = coordinator
        self.reminders = reminders
        self.receipts = receipts
        self.diagnosticSink = diagnosticSink
    }

    func handle(_ response: ManagedLocalNotificationResponse) async {
        switch response.event {
        case let .opened(notification, _):
            await handleOpen(
                notification: notification,
                event: response.event,
                deliveredAt: response.deliveredAt
            )
        case let .action(notification, actionID, _):
            await handleAction(
                notification: notification,
                actionID: actionID,
                event: response.event,
                deliveredAt: response.deliveredAt
            )
        case .foreground, .dismissed, .textAction, .diagnostic:
            return
        }
    }

    private func handleOpen(
        notification: LocalNotificationEventNotification,
        event: LocalNotificationEvent,
        deliveredAt: Date
    ) async {
        guard let source = await validatedSource(event, notification: notification) else {
            return
        }
        let receipt = NotificationResponseReceipt(
            requestID: source.requestID,
            kind: .opened,
            deliveredAt: deliveredAt
        )
        guard await receipts.insertIfNew(receipt) else { return }
        await coordinator.deliver(.navigate(.openProduct(source.metadata.productID)))
    }

    private func handleAction(
        notification: LocalNotificationEventNotification,
        actionID: LocalNotificationActionID,
        event: LocalNotificationEvent,
        deliveredAt: Date
    ) async {
        guard isStoreNotification(notification) else { return }
        guard [
            AppNotificationIdentifiers.openProductAction,
            AppNotificationIdentifiers.favoriteAction,
            AppNotificationIdentifiers.remindLaterAction
        ].contains(actionID) else {
            await publishInvalidMetadata(id: notification.id)
            return
        }
        guard let source = await validatedSource(event, notification: notification) else {
            return
        }
        let kind: NotificationResponseKind = actionID == AppNotificationIdentifiers.openProductAction
            ? .opened : .action(actionID)
        guard await receipts.insertIfNew(.init(
            requestID: source.requestID,
            kind: kind,
            deliveredAt: deliveredAt
        )) else { return }

        if actionID == AppNotificationIdentifiers.openProductAction {
            await coordinator.deliver(.navigate(.openProduct(source.metadata.productID)))
        } else if actionID == AppNotificationIdentifiers.favoriteAction {
            await coordinator.deliver(.protected(.favorite(source.metadata.productID)))
        } else {
            do {
                try await reminders.remindLater(from: source, after: .seconds(600))
            } catch is CancellationError {
                return
            } catch {
                await diagnosticSink(.init(id: notification.id, reason: .storeActionFailed))
            }
        }
    }

    private func validatedSource(
        _ event: LocalNotificationEvent,
        notification: LocalNotificationEventNotification
    ) async -> ProductReminderRescheduleSource? {
        guard isStoreNotification(notification) else { return nil }
        do {
            return try ProductReminderRescheduleSource.decode(from: event)
        } catch {
            await publishInvalidMetadata(id: notification.id)
            return nil
        }
    }

    private func isStoreNotification(
        _ notification: LocalNotificationEventNotification
    ) -> Bool {
        guard case let .decoded(request) = notification.payload else { return false }
        return request.content.categoryID == AppNotificationIdentifiers.storeCategory
    }

    private func publishInvalidMetadata(id: LocalNotificationID) async {
        await diagnosticSink(.init(id: id, reason: .invalidStoreMetadata))
    }
}
