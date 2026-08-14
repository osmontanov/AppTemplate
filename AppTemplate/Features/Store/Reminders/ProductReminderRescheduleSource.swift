nonisolated
struct ProductReminderRescheduleSource: Equatable, Sendable {
    let requestID: LocalNotificationID
    let metadata: ProductReminderMetadata
    let title: String
    let subtitle: String
    let body: String
    let sound: LocalNotificationSound

    init(
        requestID: LocalNotificationID,
        metadata: ProductReminderMetadata,
        title: String,
        subtitle: String,
        body: String,
        sound: LocalNotificationSound
    ) {
        self.requestID = requestID
        self.metadata = metadata
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.sound = sound
    }

    static func decode(
        from event: LocalNotificationEvent
    ) throws -> Self {
        let notification: LocalNotificationEventNotification
        switch event {
        case let .foreground(value, _),
             let .opened(value, _),
             let .dismissed(value),
             let .action(value, _, _),
             let .textAction(value, _, _, _):
            notification = value
        case .diagnostic:
            throw ProductReminderError.invalidRescheduleSource
        }

        guard case let .decoded(request) = notification.payload,
              notification.id == request.id,
              request.content.categoryID == AppNotificationIdentifiers.storeCategory else {
            throw ProductReminderError.invalidRescheduleSource
        }

        let metadata = try ProductReminderMetadata.decode(request.content.metadata)
        let expectedID = try AppNotificationIdentifiers.productRequest(metadata.productID)
        let expectedDeepLink = try AppNotificationIdentifiers.productDeepLink(metadata.productID)
        guard request.id == expectedID,
              request.content.deepLink == expectedDeepLink else {
            throw ProductReminderError.invalidRescheduleSource
        }

        return Self(
            requestID: request.id,
            metadata: metadata,
            title: request.content.title,
            subtitle: request.content.subtitle,
            body: request.content.body,
            sound: request.content.sound
        )
    }
}
