import Foundation
import Testing
@testable import AppTemplate

struct InMemoryLocalNotificationServiceTests {
    @Test
    func settingsReturnTheConfiguredSnapshotWithoutRequestingAuthorization() async throws {
        let configured = LocalNotificationSettings.fixture(authorizationStatus: .denied)
        let service = InMemoryLocalNotificationService.fixture(
            settings: configured,
            authorizationResult: true
        )

        #expect(await service.settings() == configured)
        #expect(try await service.requestAuthorization([.alert]))
        #expect(await service.settings() == configured)
    }

    @Test(arguments: [true, false])
    func authorizationMirrorsTheConfiguredOutcome(_ expected: Bool) async throws {
        let service = InMemoryLocalNotificationService.fixture(
            authorizationResult: expected
        )

        #expect(try await service.requestAuthorization([.alert, .sound]) == expected)
    }

    @Test
    func authorizationRejectsInvalidOptions() async {
        let service = InMemoryLocalNotificationService.fixture()

        await #expect(throws: LocalNotificationServiceError.invalidAuthorizationOptions) {
            _ = try await service.requestAuthorization([])
        }
        await #expect(throws: LocalNotificationServiceError.invalidAuthorizationOptions) {
            _ = try await service.requestAuthorization(
                LocalNotificationAuthorizationOptions(rawValue: 1 << 20)
            )
        }
    }

    @Test
    func categoryReplacementIsAtomicAfterValidationAndDeepLinkPolicy() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        let original = try LocalNotificationFixtures.category(id: "original")
        let validReplacement = try LocalNotificationFixtures.category(id: "replacement")
        let invalidReplacement = try category(
            id: "invalid",
            actionID: "website",
            deepLink: URL(string: "https://example.com")!
        )

        try await service.setCategories([original])
        await #expect(throws: LocalNotificationServiceError.invalidDeepLink) {
            try await service.setCategories([validReplacement, invalidReplacement])
        }

        #expect(await service.registeredCategoriesForTesting() == [original])

        try await service.setCategories([validReplacement])
        #expect(await service.registeredCategoriesForTesting() == [validReplacement])
    }

    @Test
    func schedulingRejectsAnUnknownCategoryWithoutChangingPendingState() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        let request = try makeRequest(
            id: "unknown-category",
            categoryID: LocalNotificationCategoryID("missing")
        )

        await #expect(throws: LocalNotificationServiceError.invalidCategory(.unknownCategory)) {
            try await service.schedule(request)
        }
        #expect(await service.pending().isEmpty)
    }

    @Test
    func failedReplacementPreservesTheExistingPendingRequest() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        let original = try LocalNotificationFixtures.request(id: "same", body: "first")
        let invalid = try makeRequest(
            id: "same",
            body: "second",
            deepLink: URL(string: "https://example.com")!
        )

        try await service.schedule(original)
        await #expect(throws: LocalNotificationServiceError.invalidDeepLink) {
            try await service.schedule(invalid)
        }

        let pending = await service.pending()
        let payload = try #require(pending.first?.payload)
        guard case let .decoded(request) = payload else {
            Issue.record("Expected a decoded pending request")
            return
        }
        #expect(request.content.body == "first")
    }

    @Test
    func expiredCalendarReplacementIsRejectedWithoutRemovingExistingPendingRequest() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        let original = try LocalNotificationFixtures.request(id: "same", body: "first")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let expired = try makeRequest(
            id: "same",
            body: "expired",
            trigger: .calendar(
                DateComponents(
                    calendar: calendar,
                    timeZone: calendar.timeZone,
                    year: 2024,
                    month: 1,
                    day: 1,
                    hour: 0,
                    minute: 0,
                    second: 0
                ),
                repeats: false
            )
        )

        try await service.schedule(original)
        await #expect(throws: LocalNotificationServiceError.invalidTrigger(.noNextTriggerDate)) {
            try await service.schedule(expired)
        }

        let pending = await service.pending()
        #expect(pending.count == 1)
        guard case let .decoded(request)? = pending.first?.payload else {
            Issue.record("Expected the original decoded pending request")
            return
        }
        #expect(request.content.body == "first")
    }

    @Test
    func sameIdentifierReplacesOnlyPendingRequest() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        let first = try LocalNotificationFixtures.request(id: "same", body: "first")
        let second = try LocalNotificationFixtures.request(id: "same", body: "second")

        try await service.schedule(first)
        try await service.schedule(second)

        let pending = await service.pending()
        #expect(pending.count == 1)
        let payload = try #require(pending.first?.payload)
        guard case let .decoded(request) = payload else {
            Issue.record("Expected a decoded pending request")
            return
        }
        #expect(request.content.body == "second")
        #expect(await service.delivered().isEmpty)
    }

    @Test
    func schedulingAfterDeliveryLeavesTheDeliveredSnapshotIntact() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        let first = try LocalNotificationFixtures.request(id: "same", body: "delivered")
        let second = try LocalNotificationFixtures.request(id: "same", body: "pending")
        let deliveredAt = Date(timeIntervalSince1970: 1_800_000_000)

        try await service.schedule(first)
        await service.deliverForTesting(id: first.id, at: deliveredAt)
        try await service.schedule(second)

        #expect(await service.pending().count == 1)
        let delivered = await service.delivered()
        #expect(delivered.count == 1)
        #expect(delivered.first?.deliveredAt == deliveredAt)
        guard case let .decoded(request)? = delivered.first?.payload else {
            Issue.record("Expected a decoded delivered request")
            return
        }
        #expect(request.content.body == "delivered")
    }

    @Test
    func pendingSortsByDateWithNilLastThenIdentifier() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        var components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2099,
            month: 1,
            day: 2,
            hour: 3
        )
        components.minute = 4
        let secondTie = try makeRequest(
            id: "b",
            trigger: .calendar(components, repeats: false)
        )
        let firstTie = try makeRequest(
            id: "a",
            trigger: .calendar(components, repeats: false)
        )
        let nilDate = try makeRequest(id: "nil", trigger: .immediate)

        try await service.schedule(nilDate)
        try await service.schedule(secondTie)
        try await service.schedule(firstTie)

        #expect(await service.pending().map(\.id) == [firstTie.id, secondTie.id, nilDate.id])
    }

    @Test
    func deliveredSortsByNewestDateThenIdentifier() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        let firstTie = try LocalNotificationFixtures.request(id: "a")
        let secondTie = try LocalNotificationFixtures.request(id: "b")
        let newest = try LocalNotificationFixtures.request(id: "newest")
        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_800_000_000)

        for request in [secondTie, newest, firstTie] { try await service.schedule(request) }
        await service.deliverForTesting(id: secondTie.id, at: olderDate)
        await service.deliverForTesting(id: newest.id, at: newerDate)
        await service.deliverForTesting(id: firstTie.id, at: olderDate)

        #expect(await service.delivered().map(\.id) == [newest.id, firstTie.id, secondTie.id])
        #expect(await service.pending().isEmpty)
    }

    @Test
    func pointRemovalsAreIdempotentAndCollectionSpecific() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        let pending = try LocalNotificationFixtures.request(id: "pending")
        let delivered = try LocalNotificationFixtures.request(id: "delivered")
        let absent = try LocalNotificationID("absent")
        try await service.schedule(pending)
        try await service.schedule(delivered)
        await service.deliverForTesting(id: delivered.id, at: .distantPast)

        await service.removePending([absent, pending.id])
        await service.removePending([pending.id])
        #expect(await service.pending().isEmpty)
        #expect(await service.delivered().map(\.id) == [delivered.id])

        await service.removeDelivered([absent, delivered.id])
        await service.removeDelivered([delivered.id])
        #expect(await service.delivered().isEmpty)
    }

    @Test
    func removeAllOperationsAreIdempotentAndCollectionSpecific() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        let pending = try LocalNotificationFixtures.request(id: "pending")
        let delivered = try LocalNotificationFixtures.request(id: "delivered")
        try await service.schedule(pending)
        try await service.schedule(delivered)
        await service.deliverForTesting(id: delivered.id, at: .distantPast)

        await service.removeAllPending()
        await service.removeAllPending()
        #expect(await service.pending().isEmpty)
        #expect(await service.delivered().map(\.id) == [delivered.id])

        await service.removeAllDelivered()
        await service.removeAllDelivered()
        #expect(await service.delivered().isEmpty)
    }

    @Test
    func badgeRejectsNegativeValuesAndClearSetsZero() async throws {
        let service = InMemoryLocalNotificationService.fixture()

        try await service.setBadgeCount(7)
        await #expect(throws: LocalNotificationServiceError.invalidContent(.invalidBadge)) {
            try await service.setBadgeCount(-1)
        }
        #expect(await service.badgeCountForTesting() == 7)

        try await service.clearBadge()
        #expect(await service.badgeCountForTesting() == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func servicePublishesEventsThroughItsInjectedHub() async throws {
        let hub = LocalNotificationEventHub()
        let service = InMemoryLocalNotificationService.fixture(eventHub: hub)
        let stream = await service.events()
        let expected = try LocalNotificationFixtures.diagnostic(.missingEnvelope)
        let consumer = Task { await firstEvent(in: stream) }

        await service.publishForTesting(expected)

        #expect(await consumer.value == expected)
        #expect(await hub.activeSubscriptionCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellingAServiceEventConsumerRemovesItsHubSubscription() async {
        let hub = LocalNotificationEventHub()
        let service = InMemoryLocalNotificationService.fixture(eventHub: hub)
        let stream = await service.events()
        let consumer = Task { await firstEvent(in: stream) }

        consumer.cancel()
        #expect(await consumer.value == nil)
        await hub.waitUntilSubscriptionCountForTesting(0)
        #expect(await hub.activeSubscriptionCount == 0)
    }

    @Test
    func preCancelledFallibleOperationsDoNotValidateOrMutate() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        let originalCategory = try LocalNotificationFixtures.category(id: "original")
        let originalRequest = try LocalNotificationFixtures.request(id: "original")
        try await service.setCategories([originalCategory])
        try await service.schedule(originalRequest)
        try await service.setBadgeCount(4)

        let authorizationError = await preCancelledError {
            _ = try await service.requestAuthorization([])
        }
        let categoryError = await preCancelledError {
            try await service.setCategories([originalCategory, originalCategory])
        }
        let schedulingError = await preCancelledError {
            try await service.schedule(
                LocalNotificationRequest(
                    id: originalRequest.id,
                    content: LocalNotificationContent(),
                    trigger: .immediate
                )
            )
        }
        let badgeError = await preCancelledError {
            try await service.setBadgeCount(-1)
        }

        #expect(authorizationError is CancellationError)
        #expect(categoryError is CancellationError)
        #expect(schedulingError is CancellationError)
        #expect(badgeError is CancellationError)
        #expect(await service.registeredCategoriesForTesting() == [originalCategory])
        #expect(await service.pending().map(\.id) == [originalRequest.id])
        #expect(await service.badgeCountForTesting() == 4)
    }

    @Test
    func validAttachmentIsReadWithoutMovingItsSource() async throws {
        let fixture = try TemporaryAttachment(fileExtension: "png")
        defer { fixture.remove() }
        let attachment = LocalNotificationAttachment(
            id: try LocalNotificationAttachmentID("image"),
            fileURL: fixture.url
        )
        let service = InMemoryLocalNotificationService.fixture()

        try await service.schedule(try makeRequest(id: "attachment", attachments: [attachment]))

        #expect(FileManager.default.fileExists(atPath: fixture.url.path))
        let pending = try #require(await service.pending().first)
        guard case let .decoded(request) = pending.payload else {
            Issue.record("Expected a decoded attachment request")
            return
        }
        let stored = try #require(request.content.attachments.first)
        #expect(stored.id == attachment.id)
        #expect(stored.fileURL == fixture.url)
        #expect(stored.typeIdentifier == "public.png")
    }

    @Test
    func attachmentValidationRejectsNonFileMissingNonRegularAndUnsupportedSources() async throws {
        let service = InMemoryLocalNotificationService.fixture()
        let identifier = try LocalNotificationAttachmentID("attachment")
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "AppTemplate-InMemoryLocalNotification-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let unsupported = directory.appending(path: "document.txt", directoryHint: .notDirectory)
        try Data("text".utf8).write(to: unsupported)
        let missing = directory.appending(path: "missing.png", directoryHint: .notDirectory)
        let cases: [(URL, LocalNotificationAttachmentFailure)] = [
            (URL(string: "https://example.com/image.png")!, .notFileURL),
            (missing, .missing),
            (directory, .notRegularFile),
            (unsupported, .unsupportedType)
        ]

        for (url, failure) in cases {
            let attachment = LocalNotificationAttachment(id: identifier, fileURL: url)
            await #expect(throws: LocalNotificationServiceError.invalidAttachment(identifier, failure)) {
                try await service.schedule(
                    try makeRequest(id: "invalid-\(failure.rawValue)", attachments: [attachment])
                )
            }
        }
        #expect(await service.pending().isEmpty)
    }

    @Test
    func separateInstancesDoNotShareAnyMutableState() async throws {
        let first = InMemoryLocalNotificationService.fixture()
        let second = InMemoryLocalNotificationService.fixture()
        let category = try LocalNotificationFixtures.category(id: "category")
        let request = try LocalNotificationFixtures.request(id: "request")
        let event = try LocalNotificationFixtures.diagnostic(.missingEnvelope)
        try await first.setCategories([category])
        try await first.schedule(request)
        try await first.setBadgeCount(9)
        let secondStream = await second.events()
        let secondConsumer = Task { await firstEvent(in: secondStream) }

        await first.publishForTesting(event)

        #expect(await second.pending().isEmpty)
        #expect(await second.delivered().isEmpty)
        #expect(await second.registeredCategoriesForTesting().isEmpty)
        #expect(await second.badgeCountForTesting() == 0)
        secondConsumer.cancel()
        #expect(await secondConsumer.value == nil)
    }
}

private extension InMemoryLocalNotificationService {
    @MainActor
    static func fixture(
        settings: LocalNotificationSettings = .fixture(),
        authorizationResult: Bool = true,
        categories: [LocalNotificationCategory] = [],
        eventHub: LocalNotificationEventHub = LocalNotificationEventHub()
    ) -> InMemoryLocalNotificationService {
        let parser = DeepLinkParser(scheme: "apptemplate")
        let candidateURLs = [
            "apptemplate://home",
            "apptemplate://browse",
            "apptemplate://projects",
            "apptemplate://settings",
            "apptemplate://browse/item/fixture",
            "apptemplate://projects/project/fixture",
            "apptemplate://projects/project/fixture/task/fixture"
        ].compactMap(URL.init(string:))
        let acceptedURLs = Set(candidateURLs.filter { url in
            if case .success = parser.parse(url) { return true }
            return false
        })
        let deepLinkPolicy = LocalNotificationDeepLinkPolicy { acceptedURLs.contains($0) }
        return InMemoryLocalNotificationService(
            settings: settings,
            authorizationResult: authorizationResult,
            categories: categories,
            deepLinkPolicy: deepLinkPolicy,
            eventHub: eventHub
        )
    }
}

private nonisolated extension LocalNotificationSettings {
    static func fixture(
        authorizationStatus: LocalNotificationAuthorizationStatus = .notDetermined
    ) -> LocalNotificationSettings {
        LocalNotificationSettings(
            authorizationStatus: authorizationStatus,
            alertSetting: .disabled,
            soundSetting: .disabled,
            badgeSetting: .disabled,
            notificationCenterSetting: .disabled,
            lockScreenSetting: .disabled,
            alertStyle: .none,
            previewSetting: .never
        )
    }
}

private func category(
    id: String,
    actionID: String,
    deepLink: URL
) throws -> LocalNotificationCategory {
    LocalNotificationCategory(
        id: try LocalNotificationCategoryID(id),
        actions: [
            .button(
                LocalNotificationButtonAction(
                    id: try LocalNotificationActionID(actionID),
                    title: "Open",
                    deepLink: deepLink
                )
            )
        ]
    )
}

private func makeRequest(
    id: String,
    body: String = "Body",
    categoryID: LocalNotificationCategoryID? = nil,
    deepLink: URL? = nil,
    attachments: [LocalNotificationAttachment] = [],
    trigger: LocalNotificationTrigger = .immediate
) throws -> LocalNotificationRequest {
    LocalNotificationRequest(
        id: try LocalNotificationID(id),
        content: LocalNotificationContent(
            body: body,
            categoryID: categoryID,
            attachments: attachments,
            deepLink: deepLink
        ),
        trigger: trigger
    )
}

private func firstEvent(
    in stream: AsyncStream<LocalNotificationEvent>
) async -> LocalNotificationEvent? {
    var iterator = stream.makeAsyncIterator()
    return await iterator.next()
}

private func preCancelledError(
    _ operation: @escaping @Sendable () async throws -> Void
) async -> (any Error)? {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        try await operation()
    }
    do {
        try await task.value
        return nil
    } catch {
        return error
    }
}

private struct TemporaryAttachment {
    let url: URL

    init(fileExtension: String) throws {
        url = FileManager.default.temporaryDirectory.appending(
            path: "AppTemplate-InMemoryLocalNotification-\(UUID().uuidString).\(fileExtension)",
            directoryHint: .notDirectory
        )
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
