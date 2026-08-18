import Foundation

actor ProductReminderRepository: IProductReminderRepository {

    private let service: any ILocalNotificationService
    private let images: any IImageBytesLoading
    private let attachmentStager: ReminderAttachmentStager
    private let categoryCatalog: any IAppNotificationCategoryCatalog
    private let clock: AppClock

    init(
        service: any ILocalNotificationService,
        images: any IImageBytesLoading,
        attachmentStager: ReminderAttachmentStager,
        categoryCatalog: any IAppNotificationCategoryCatalog,
        clock: AppClock
    ) {
        self.service = service
        self.images = images
        self.attachmentStager = attachmentStager
        self.categoryCatalog = categoryCatalog
        self.clock = clock
    }

    func status(productID: Product.ID) async -> ProductReminderStatus {
        guard let requestID = try? AppNotificationIdentifiers.productRequest(productID) else {
            return .notScheduled
        }
        guard let snapshot = await service.pending().first(where: { $0.id == requestID }) else {
            return .notScheduled
        }
        return .scheduled(nextTriggerDate: snapshot.nextTriggerDate)
    }

    func schedule(
        product: Product,
        selection: ProductReminderSelection
    ) async throws -> ProductReminderScheduleResult {
        guard product.id > 0 else { throw ProductReminderError.invalidProductID }
        let trigger = try trigger(for: selection, now: clock.now())
        let requestID = try AppNotificationIdentifiers.productRequest(product.id)
        let metadata = try ProductReminderMetadata(productID: product.id)
        let deepLink = try AppNotificationIdentifiers.productDeepLink(product.id)

        try Task.checkCancellation()
        try await authorizeIfNeeded()
        try Task.checkCancellation()
        do {
            try await categoryCatalog.bootstrapIfNeeded()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ProductReminderError.categoryRegistrationFailed
        }
        try Task.checkCancellation()

        var stagedAttachment: StagedReminderAttachment?
        var usesTextOnlyFallback = product.thumbnailURL == nil
        if let thumbnailURL = product.thumbnailURL {
            do {
                let image = try await images.bytes(for: thumbnailURL)
                stagedAttachment = try await attachmentStager.stage(
                    image,
                    productID: product.id
                )
            } catch ImageServiceError.cancelled {
                throw CancellationError()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                usesTextOnlyFallback = true
            }
        }
        defer { stagedAttachment?.cleanup() }

        func makeRequest(
            attachments: [LocalNotificationAttachment]
        ) -> LocalNotificationRequest {
            LocalNotificationRequest(
                id: requestID,
                content: LocalNotificationContent(
                    title: AppText.string("Product reminder"),
                    subtitle: product.title,
                    body: AppText.string(
                        "store.reminder.body",
                        defaultValue: "Take another look at \(product.title)."
                    ),
                    sound: .default,
                    categoryID: AppNotificationIdentifiers.storeCategory,
                    attachments: attachments,
                    metadata: metadata.notificationValues,
                    deepLink: deepLink,
                    foregroundPresentation: [.banner, .sound]
                ),
                trigger: trigger
            )
        }

        let attachments = stagedAttachment.map { [$0.attachment] } ?? []
        do {
            try await service.schedule(makeRequest(attachments: attachments))
        } catch let error as LocalNotificationServiceError {
            guard case let .invalidAttachment(rejectedID, .systemRejected) = error,
                  attachments.contains(where: { $0.id == rejectedID }) else {
                throw error
            }
            try Task.checkCancellation()
            usesTextOnlyFallback = true
            try await service.schedule(makeRequest(attachments: []))
        }
        return usesTextOnlyFallback
            ? .scheduledWithWarning(.textOnlyAttachmentFallback)
            : .scheduled
    }

    func remindLater(
        from source: ProductReminderRescheduleSource,
        after delay: Duration
    ) async throws {
        guard delay == ProductReminderPolicy.remindLaterDelay,
              source.requestID == (try AppNotificationIdentifiers.productRequest(
                source.metadata.productID
              )) else {
            throw ProductReminderError.invalidRescheduleSource
        }

        let request = LocalNotificationRequest(
            id: source.requestID,
            content: LocalNotificationContent(
                title: source.title,
                subtitle: source.subtitle,
                body: source.body,
                sound: source.sound,
                categoryID: AppNotificationIdentifiers.storeCategory,
                metadata: source.metadata.notificationValues,
                deepLink: try AppNotificationIdentifiers.productDeepLink(
                    source.metadata.productID
                )
            ),
            trigger: .timeInterval(seconds: 600, repeats: false)
        )
        try await service.schedule(request)
    }

    func cancel(productID: Product.ID) async {
        guard let requestID = try? AppNotificationIdentifiers.productRequest(productID) else {
            return
        }
        await service.removePending([requestID])
    }

    private func authorizeIfNeeded() async throws {
        switch (await service.settings()).authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        case .notDetermined:
            guard try await service.requestAuthorization([.alert, .sound]) else {
                throw ProductReminderError.authorizationDenied
            }
        case .denied, .notSupported, .unknown:
            throw ProductReminderError.authorizationDenied
        }
    }

    private func trigger(
        for selection: ProductReminderSelection,
        now: Date
    ) throws -> LocalNotificationTrigger {
        switch selection {
        case .quickTest:
            return .timeInterval(seconds: ProductReminderPolicy.quickTestInterval, repeats: false)
        case let .interval(seconds, repeats):
            guard seconds.isFinite,
                  (1...ProductReminderPolicy.maximumInterval).contains(seconds) else {
                throw ProductReminderError.intervalOutOfRange
            }
            guard !repeats || seconds >= ProductReminderPolicy.minimumRepeatingInterval else {
                throw ProductReminderError.repeatingIntervalBelowMinimum
            }
            return .timeInterval(seconds: seconds, repeats: repeats)
        case let .calendar(date, timeZone):
            guard date > now else { throw ProductReminderError.calendarNotInFuture }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            guard let maximum = calendar.date(byAdding: .year, value: 1, to: now),
                  date <= maximum else {
                throw ProductReminderError.calendarBeyondOneYear
            }
            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
            components.calendar = calendar
            components.timeZone = timeZone
            guard let resolvedDate = calendar.date(from: components),
                  resolvedDate > now else {
                throw ProductReminderError.calendarNotInFuture
            }
            return .calendar(components, repeats: false)
        }
    }
}
