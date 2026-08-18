import Foundation
import Testing
import UniformTypeIdentifiers
@testable import AppTemplate

struct ProductReminderRepositoryTests {
    @Test(arguments: [
        LocalNotificationAuthorizationStatus.denied,
        .notSupported,
        .unknown
    ])
    func existingUnavailableSettingsNeverPromptOrLoadImage(
        _ status: LocalNotificationAuthorizationStatus
    ) async throws {
        let fixture = try makeFixture(status: status)
        defer { fixture.cleanup() }

        await #expect(throws: ProductReminderError.authorizationDenied) {
            try await fixture.repository.schedule(product: .fixture(id: 7), selection: .quickTest)
        }
        #expect(await fixture.trace.values == [.settings])
    }

    @Test
    func refusedAuthorizationStopsBeforeImageAndSchedule() async throws {
        let fixture = try makeFixture(status: .notDetermined, authorizationResult: false)
        defer { fixture.cleanup() }

        await #expect(throws: ProductReminderError.authorizationDenied) {
            try await fixture.repository.schedule(product: .fixture(id: 7), selection: .quickTest)
        }
        #expect(await fixture.trace.values == [
            .settings,
            .authorization([.alert, .sound])
        ])
    }

    @Test
    func notDeterminedOrdersPromptBeforeImageAndSchedule() async throws {
        let fixture = try makeFixture(status: .notDetermined)
        defer { fixture.cleanup() }

        _ = try await fixture.repository.schedule(product: .fixture(id: 7), selection: .quickTest)

        #expect(await fixture.trace.values == [
            .settings,
            .authorization([.alert, .sound]),
            .categoryBootstrap,
            .imageLoad(URL(string: "https://cdn.dummyjson.com/product.png")!),
            .schedule
        ])
    }

    @Test
    func ephemeralSchedulesWithoutPrompting() async throws {
        let fixture = try makeFixture(status: .ephemeral)
        defer { fixture.cleanup() }

        _ = try await fixture.repository.schedule(product: .fixture(id: 7), selection: .quickTest)

        #expect(await fixture.trace.values == [
            .settings,
            .categoryBootstrap,
            .imageLoad(URL(string: "https://cdn.dummyjson.com/product.png")!),
            .schedule
        ])
    }

    @Test
    func categoryFailureStopsBeforeImageAndScheduleAndLaterRetrySucceeds() async throws {
        let directory = try ProductReminderFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let trace = ProductReminderOperationTrace()
        let service = ProductReminderNotificationServiceSpy(trace: trace)
        let catalog = RetryableProductReminderCatalog(trace: trace)
        let repository = ProductReminderRepository(
            service: service,
            images: ProductReminderImageBytesSpy(trace: trace),
            attachmentStager: ReminderAttachmentStager(directory: directory),
            categoryCatalog: catalog,
            clock: ProductReminderFixtures.clock
        )

        await #expect(throws: ProductReminderError.categoryRegistrationFailed) {
            try await repository.schedule(product: .fixture(id: 7), selection: .quickTest)
        }
        #expect(await trace.values == [.settings, .categoryBootstrap])

        await catalog.allowSuccess()
        _ = try await repository.schedule(product: .fixture(id: 7), selection: .quickTest)
        #expect(await trace.values == [
            .settings,
            .categoryBootstrap,
            .settings,
            .categoryBootstrap,
            .imageLoad(URL(string: "https://cdn.dummyjson.com/product.png")!),
            .schedule
        ])
    }

    @Test(.timeLimit(.minutes(1)))
    func simultaneousSceneBootstrapAndFirstScheduleWriteCategoryUnionOnce() async throws {
        let directory = try ProductReminderFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let barrier = ProductReminderCategoryWriteBarrier()
        let service = ProductReminderNotificationServiceSpy(
            categoryHandler: { _ in await barrier.suspend() }
        )
        let gate = AsyncOperationGate()
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: StoreProductNotificationCategory.make(),
            gate: gate
        )
        let repository = ProductReminderRepository(
            service: service,
            images: ProductReminderImageBytesSpy(),
            attachmentStager: ReminderAttachmentStager(directory: directory),
            categoryCatalog: catalog,
            clock: ProductReminderFixtures.clock
        )
        let sceneBootstrap = Task { try await catalog.bootstrapIfNeeded() }
        await barrier.waitUntilSuspended()
        let firstSchedule = Task {
            try await repository.schedule(
                product: .fixture(id: 7, thumbnailURL: nil),
                selection: .quickTest
            )
        }
        await gate.waitUntilWaiterCountForTesting(1)

        await barrier.resume()
        try await sceneBootstrap.value
        _ = try await firstSchedule.value

        #expect(await service.categoryWrites == [
            [StoreProductNotificationCategory.make()]
        ])
        #expect(await service.requests.count == 1)
    }

    @Test
    func validationOccursBeforeNotificationOrImageWork() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let calendar = Calendar(identifier: .gregorian)
        let tooLate = calendar.date(byAdding: .year, value: 1, to: ProductReminderFixtures.now)!
            .addingTimeInterval(1)
        let invalid: [(Product, ProductReminderSelection, ProductReminderError)] = [
            (.fixture(id: 0), .quickTest, .invalidProductID),
            (.fixture(id: 7), .interval(seconds: .nan, repeats: false), .intervalOutOfRange),
            (.fixture(id: 7), .interval(seconds: 0, repeats: false), .intervalOutOfRange),
            (.fixture(id: 7), .interval(seconds: 604_801, repeats: false), .intervalOutOfRange),
            (.fixture(id: 7), .interval(seconds: 59.999, repeats: true), .repeatingIntervalBelowMinimum),
            (.fixture(id: 7), .calendar(date: ProductReminderFixtures.now, timeZone: .gmt), .calendarNotInFuture),
            (.fixture(id: 7), .calendar(date: tooLate, timeZone: .gmt), .calendarBeyondOneYear)
        ]

        for (product, selection, expected) in invalid {
            await #expect(throws: expected) {
                try await fixture.repository.schedule(product: product, selection: selection)
            }
        }
        #expect(await fixture.trace.values.isEmpty)
    }

    @Test
    func intervalAndCalendarBoundariesProduceExactSafeTriggers() async throws {
        let fixture = try makeFixture(imageResult: .failure(ImageServiceError.transport))
        defer { fixture.cleanup() }
        let calendarDate = ProductReminderFixtures.now.addingTimeInterval(3_600)

        _ = try await fixture.repository.schedule(
            product: .fixture(id: 7),
            selection: .interval(seconds: 1, repeats: false)
        )
        _ = try await fixture.repository.schedule(
            product: .fixture(id: 8),
            selection: .interval(seconds: 60, repeats: true)
        )
        _ = try await fixture.repository.schedule(
            product: .fixture(id: 9),
            selection: .calendar(date: calendarDate, timeZone: .gmt)
        )

        let requests = await fixture.service.requests
        try #require(requests.count == 3)
        #expect(requests[0].trigger == .timeInterval(seconds: 1, repeats: false))
        #expect(requests[1].trigger == .timeInterval(seconds: 60, repeats: true))
        guard case let .calendar(components, repeats) = requests[2].trigger else {
            Issue.record("Expected calendar trigger")
            return
        }
        #expect(!repeats)
        #expect(components.calendar?.identifier == .gregorian)
        #expect(components.timeZone == .gmt)
        #expect(components.year == 2027)
        #expect(components.month == 1)
        #expect(components.day == 15)
        #expect(components.hour == 9)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test
    func scheduleBuildsTrustedDeterministicRequestAndCleansAttachment() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let result = try await fixture.repository.schedule(
            product: .fixture(id: 7, title: "Pocket Phone"),
            selection: .quickTest
        )

        #expect(result == .scheduled)
        let requests = await fixture.service.requests
        let request = try #require(requests.first)
        #expect(request.id.value == "store.product-reminder.7")
        #expect(request.content.title == "Product reminder")
        #expect(request.content.subtitle == "Pocket Phone")
        #expect(request.content.body == "Take another look at Pocket Phone.")
        #expect(request.content.sound == .default)
        #expect(request.content.categoryID == AppNotificationIdentifiers.storeCategory)
        #expect(request.content.metadata == ["productID": .integer(7)])
        #expect(request.content.deepLink?.absoluteString == "apptemplate://store/product/7")
        #expect(request.trigger == .timeInterval(seconds: 5, repeats: false))
        let attachment = try #require(request.content.attachments.first)
        #expect(attachment.options.typeHint == UTType.png.identifier)
        #expect(await fixture.service.attachmentExistence == [true])
        #expect(!FileManager.default.fileExists(atPath: attachment.fileURL.path))
    }

    @Test
    func imageAndStagingFailuresScheduleTextOnlyWithWarning() async throws {
        let imageFailure = try makeFixture(
            imageResult: .failure(ImageServiceError.transport)
        )
        defer { imageFailure.cleanup() }
        let invalidDirectory = imageFailure.directory.appendingPathComponent("not-a-directory")
        try Data("file".utf8).write(to: invalidDirectory)
        let stageFailureService = ProductReminderNotificationServiceSpy()
        let stageFailureImage = ProductReminderImageBytesSpy()
        let stageFailure = ProductReminderRepository(
            service: stageFailureService,
            images: stageFailureImage,
            attachmentStager: ReminderAttachmentStager(directory: invalidDirectory),
            categoryCatalog: ProductReminderCategoryCatalogSpy(),
            clock: ProductReminderFixtures.clock
        )

        let first = try await imageFailure.repository.schedule(
            product: .fixture(id: 7),
            selection: .quickTest
        )
        let second = try await stageFailure.schedule(
            product: .fixture(id: 8),
            selection: .quickTest
        )

        #expect(first == .scheduledWithWarning(.textOnlyAttachmentFallback))
        #expect(second == .scheduledWithWarning(.textOnlyAttachmentFallback))
        #expect(await imageFailure.service.requests.first?.content.attachments == [])
        #expect(await stageFailureService.requests.first?.content.attachments == [])
    }

    @Test
    func systemRejectedOwnedAttachmentRetriesTextOnlyWithWarning() async throws {
        let attachmentID = try LocalNotificationAttachmentID("store.product.thumbnail")
        let fixture = try makeFixture(
            scheduleFailure: LocalNotificationServiceError.invalidAttachment(
                attachmentID,
                .systemRejected
            )
        )
        defer { fixture.cleanup() }

        let result = try await fixture.repository.schedule(
            product: .fixture(id: 7),
            selection: .quickTest
        )

        #expect(result == .scheduledWithWarning(.textOnlyAttachmentFallback))
        let requests = await fixture.service.requests
        #expect(requests.count == 2)
        #expect(requests.first?.content.attachments.map(\.id) == [attachmentID])
        #expect(requests.last?.content.attachments == [])
        #expect(requests.first?.id == requests.last?.id)
        #expect(requests.first?.trigger == requests.last?.trigger)
        #expect(requests.first?.content.title == requests.last?.content.title)
        #expect(requests.first?.content.subtitle == requests.last?.content.subtitle)
        #expect(requests.first?.content.body == requests.last?.content.body)
        #expect(requests.first?.content.sound == requests.last?.content.sound)
        #expect(requests.first?.content.categoryID == requests.last?.content.categoryID)
        #expect(requests.first?.content.metadata == requests.last?.content.metadata)
        #expect(requests.first?.content.deepLink == requests.last?.content.deepLink)
        #expect(
            requests.first?.content.foregroundPresentation
                == requests.last?.content.foregroundPresentation
        )
        #expect(await fixture.service.attachmentExistence == [true, true])
        let stagedURL = try #require(requests.first?.content.attachments.first?.fileURL)
        #expect(!FileManager.default.fileExists(atPath: stagedURL.path))
    }

    @Test
    func onlyOwnedSystemRejectedAttachmentUsesTextOnlyRetry() async throws {
        let ownedID = try LocalNotificationAttachmentID("store.product.thumbnail")
        let foreignID = try LocalNotificationAttachmentID("other.thumbnail")
        let failures: [LocalNotificationServiceError] = [
            .invalidAttachment(foreignID, .systemRejected),
            .invalidAttachment(ownedID, .stagingFailed),
        ]

        for failure in failures {
            let fixture = try makeFixture(scheduleFailure: failure)
            defer { fixture.cleanup() }

            await #expect(throws: failure) {
                try await fixture.repository.schedule(
                    product: .fixture(id: 7),
                    selection: .quickTest
                )
            }

            let requests = await fixture.service.requests
            #expect(requests.count == 1)
            #expect(requests.first?.content.attachments.map(\.id) == [ownedID])
            #expect(await fixture.service.attachmentExistence == [true])
            let stagedURL = try #require(requests.first?.content.attachments.first?.fileURL)
            #expect(!FileManager.default.fileExists(atPath: stagedURL.path))
        }
    }

    @Test
    func cancellationPropagatesAndScheduleFailureStillCleansAttachment() async throws {
        let imageCancellation = try makeFixture(
            imageResult: .failure(ImageServiceError.cancelled)
        )
        defer { imageCancellation.cleanup() }
        let scheduleCancellation = try makeFixture(scheduleFailure: CancellationError())
        defer { scheduleCancellation.cleanup() }

        await #expect(throws: CancellationError.self) {
            try await imageCancellation.repository.schedule(
                product: .fixture(id: 7),
                selection: .quickTest
            )
        }
        await #expect(throws: CancellationError.self) {
            try await scheduleCancellation.repository.schedule(
                product: .fixture(id: 9),
                selection: .quickTest
            )
        }

        #expect(await imageCancellation.service.requests.isEmpty)
        let request = try #require(await scheduleCancellation.service.requests.first)
        let attachment = try #require(request.content.attachments.first)
        #expect(await scheduleCancellation.service.attachmentExistence == [true])
        #expect(!FileManager.default.fileExists(atPath: attachment.fileURL.path))
    }

    @Test
    func deterministicIDReplacesAndStatusAndCancelSelectOnlyOneProduct() async throws {
        let nextDate = ProductReminderFixtures.now.addingTimeInterval(120)
        let selected = try ProductReminderFixtures.pending(productID: 7, nextTriggerDate: nextDate)
        let other = try ProductReminderFixtures.pending(productID: 8, nextTriggerDate: nil)
        let fixture = try makeFixture(pending: [selected, other])
        defer { fixture.cleanup() }

        #expect(await fixture.repository.status(productID: 7) == .scheduled(nextTriggerDate: nextDate))
        #expect(await fixture.repository.status(productID: 9) == .notScheduled)
        await fixture.repository.cancel(productID: 7)
        #expect(await fixture.repository.status(productID: 7) == .notScheduled)
        #expect(await fixture.repository.status(productID: 8) == .scheduled(nextTriggerDate: nil))

        _ = try await fixture.repository.schedule(product: .fixture(id: 9), selection: .quickTest)
        _ = try await fixture.repository.schedule(
            product: .fixture(id: 9),
            selection: .interval(seconds: 90, repeats: false)
        )
        let ids = await fixture.service.requests.suffix(2).map(\.id.value)
        #expect(ids == ["store.product-reminder.9", "store.product-reminder.9"])
    }

    @Test
    func remindLaterIsExactlyTenMinutesTextOnlyAndDoesNoAcquisitionWork() async throws {
        let trace = ProductReminderOperationTrace()
        let fixture = try makeFixture(trace: trace)
        defer { fixture.cleanup() }
        let source = try ProductReminderRescheduleSource.decode(
            from: ProductReminderFixtures.event()
        )

        try await fixture.repository.remindLater(from: source, after: .seconds(600))

        #expect(await trace.values == [.schedule])
        let request = try #require(await fixture.service.requests.first)
        #expect(request.id == source.requestID)
        #expect(request.trigger == .timeInterval(seconds: 600, repeats: false))
        #expect(request.content.title == source.title)
        #expect(request.content.subtitle == source.subtitle)
        #expect(request.content.body == source.body)
        #expect(request.content.sound == source.sound)
        #expect(request.content.attachments.isEmpty)
        #expect(request.content.categoryID == AppNotificationIdentifiers.storeCategory)
        #expect(request.content.metadata == source.metadata.notificationValues)
        let expectedDeepLink = try AppNotificationIdentifiers.productDeepLink(7)
        #expect(request.content.deepLink == expectedDeepLink)
    }

    @Test
    func remindLaterRejectsWrongDelayAndMismatchedTypedSource() async throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let source = try ProductReminderRescheduleSource.decode(
            from: ProductReminderFixtures.event()
        )
        let mismatched = ProductReminderRescheduleSource(
            requestID: try AppNotificationIdentifiers.productRequest(8),
            metadata: source.metadata,
            title: source.title,
            subtitle: source.subtitle,
            body: source.body,
            sound: source.sound
        )

        await #expect(throws: ProductReminderError.invalidRescheduleSource) {
            try await fixture.repository.remindLater(from: source, after: .seconds(599))
        }
        await #expect(throws: ProductReminderError.invalidRescheduleSource) {
            try await fixture.repository.remindLater(from: mismatched, after: .seconds(600))
        }
        #expect(await fixture.trace.values.isEmpty)
    }

    @Test
    func attachmentStagerValidatesRepresentationAndCleansOnlyItsOwnFile() async throws {
        let directory = try ProductReminderFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("input.txt")
        try Data("keep".utf8).write(to: input)
        let stager = ReminderAttachmentStager(directory: directory)

        await #expect(throws: (any Error).self) {
            _ = try await stager.stage(
                ImageBytes(data: Data("html".utf8), mimeType: "text/html", pixelWidth: 1, pixelHeight: 1),
                productID: 7
            )
        }
        let staged = try await stager.stage(.productReminderPNG, productID: 7)
        #expect(staged.attachment.fileURL.deletingLastPathComponent() == directory.standardizedFileURL)
        #expect(staged.attachment.fileURL.pathExtension == "png")
        #expect(FileManager.default.fileExists(atPath: staged.attachment.fileURL.path))

        staged.cleanup()

        #expect(!FileManager.default.fileExists(atPath: staged.attachment.fileURL.path))
        #expect(FileManager.default.fileExists(atPath: input.path))
    }
}

private actor RetryableProductReminderCatalog: IAppNotificationCategoryCatalog {
    private let trace: ProductReminderOperationTrace
    private var shouldFail = true

    init(trace: ProductReminderOperationTrace) { self.trace = trace }
    func categories() async -> [LocalNotificationCategory] { [] }
    func bootstrapIfNeeded() async throws {
        await trace.append(.categoryBootstrap)
        if shouldFail { throw ProductReminderTestFailure.schedule }
    }
    func replaceLabCategories(_ categories: [LocalNotificationCategory]) async throws {
        _ = categories
    }
    func resetLabCategories() async throws {}
    func allowSuccess() { shouldFail = false }
}

private actor ProductReminderCategoryWriteBarrier {
    private var isSuspended = false
    private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []
    private var continuation: CheckedContinuation<Void, Never>?

    func suspend() async {
        isSuspended = true
        let waiters = suspensionWaiters
        suspensionWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilSuspended() async {
        guard !isSuspended else { return }
        await withCheckedContinuation { suspensionWaiters.append($0) }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private extension ProductReminderRepositoryTests {
    struct Fixture {
        let repository: ProductReminderRepository
        let service: ProductReminderNotificationServiceSpy
        let trace: ProductReminderOperationTrace
        let directory: URL

        func cleanup() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    func makeFixture(
        status: LocalNotificationAuthorizationStatus = .authorized,
        authorizationResult: Bool = true,
        pending: [LocalNotificationPendingSnapshot] = [],
        scheduleFailure: (any Error & Sendable)? = nil,
        imageResult: Result<ImageBytes, ImageServiceError> = .success(.productReminderPNG),
        trace: ProductReminderOperationTrace = ProductReminderOperationTrace()
    ) throws -> Fixture {
        let directory = try ProductReminderFixtures.temporaryDirectory()
        let service = ProductReminderNotificationServiceSpy(
            status: status,
            authorizationResult: authorizationResult,
            pending: pending,
            scheduleFailure: scheduleFailure,
            trace: trace
        )
        let images = ProductReminderImageBytesSpy(result: imageResult, trace: trace)
        return Fixture(
            repository: ProductReminderFixtures.repository(
                service: service,
                images: images,
                directory: directory,
                trace: trace
            ),
            service: service,
            trace: trace,
            directory: directory
        )
    }
}
