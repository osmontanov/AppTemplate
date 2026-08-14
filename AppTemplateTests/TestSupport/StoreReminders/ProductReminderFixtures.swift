import Foundation
@testable import AppTemplate

nonisolated
enum ProductReminderTestFailure: Error, Equatable, Sendable {
    case image
    case schedule
}

nonisolated
enum ProductReminderOperation: Equatable, Sendable {
    case settings
    case authorization(LocalNotificationAuthorizationOptions)
    case imageLoad(URL, ImageLoadPolicy)
    case schedule
    case pending
    case removePending(Set<LocalNotificationID>)
}

actor ProductReminderOperationTrace {
    private var storedValues: [ProductReminderOperation] = []

    func append(_ value: ProductReminderOperation) {
        storedValues.append(value)
    }

    var values: [ProductReminderOperation] {
        storedValues
    }
}

actor ProductReminderNotificationServiceSpy: ILocalNotificationService {
    private let configuredSettings: LocalNotificationSettings
    private let authorizationResult: Bool
    private let scheduleFailure: (any Error & Sendable)?
    private let trace: ProductReminderOperationTrace
    private var pendingSnapshots: [LocalNotificationPendingSnapshot]
    private var storedRequests: [LocalNotificationRequest] = []
    private var stagedFilesExistedDuringSchedule: [Bool] = []

    init(
        status: LocalNotificationAuthorizationStatus = .authorized,
        authorizationResult: Bool = true,
        pending: [LocalNotificationPendingSnapshot] = [],
        scheduleFailure: (any Error & Sendable)? = nil,
        trace: ProductReminderOperationTrace = ProductReminderOperationTrace()
    ) {
        configuredSettings = .productReminderFixture(status: status)
        self.authorizationResult = authorizationResult
        pendingSnapshots = pending
        self.scheduleFailure = scheduleFailure
        self.trace = trace
    }

    func settings() async -> LocalNotificationSettings {
        await trace.append(.settings)
        return configuredSettings
    }

    func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        await trace.append(.authorization(options))
        return authorizationResult
    }

    func setCategories(_ categories: [LocalNotificationCategory]) async throws {
        _ = categories
    }

    func schedule(_ request: LocalNotificationRequest) async throws {
        await trace.append(.schedule)
        storedRequests.append(request)
        stagedFilesExistedDuringSchedule.append(
            request.content.attachments.allSatisfy {
                FileManager.default.fileExists(atPath: $0.fileURL.path)
            }
        )
        if let scheduleFailure { throw scheduleFailure }
    }

    func pending() async -> [LocalNotificationPendingSnapshot] {
        await trace.append(.pending)
        return pendingSnapshots
    }

    func delivered() async -> [LocalNotificationDeliveredSnapshot] { [] }

    func removePending(_ identifiers: Set<LocalNotificationID>) async {
        await trace.append(.removePending(identifiers))
        pendingSnapshots.removeAll { identifiers.contains($0.id) }
    }

    func removeAllPending() async {}
    func removeDelivered(_ identifiers: Set<LocalNotificationID>) async { _ = identifiers }
    func removeAllDelivered() async {}
    func setBadgeCount(_ count: Int) async throws { _ = count }
    func clearBadge() async throws {}

    func events() async -> AsyncStream<LocalNotificationEvent> {
        AsyncStream { $0.finish() }
    }

    var requests: [LocalNotificationRequest] { storedRequests }
    var attachmentExistence: [Bool] { stagedFilesExistedDuringSchedule }
}

actor ProductReminderImageLoaderSpy: IImageLoader {
    private let result: Result<LoadedImage, any Error & Sendable>
    private let trace: ProductReminderOperationTrace

    init(
        result: Result<LoadedImage, any Error & Sendable> = .success(.productReminderPNG),
        trace: ProductReminderOperationTrace = ProductReminderOperationTrace()
    ) {
        self.result = result
        self.trace = trace
    }

    func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage {
        await trace.append(.imageLoad(url, policy))
        return try result.get()
    }
}

nonisolated extension LoadedImage {
    static let productReminderPNG = LoadedImage(
        data: Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!,
        mimeType: "image/png",
        pixelWidth: 1,
        pixelHeight: 1
    )
}

nonisolated extension LocalNotificationSettings {
    static func productReminderFixture(
        status: LocalNotificationAuthorizationStatus
    ) -> LocalNotificationSettings {
        LocalNotificationSettings(
            authorizationStatus: status,
            alertSetting: .enabled,
            soundSetting: .enabled,
            badgeSetting: .enabled,
            notificationCenterSetting: .enabled,
            lockScreenSetting: .enabled,
            alertStyle: .banner,
            previewSetting: .always
        )
    }
}

nonisolated
enum ProductReminderFixtures {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let clock = AppClock(
        now: { now },
        monotonicNow: { ContinuousClock().now },
        sleep: { _ in }
    )

    static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppTemplate-ProductReminderTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    static func repository(
        service: ProductReminderNotificationServiceSpy,
        imageLoader: ProductReminderImageLoaderSpy,
        directory: URL
    ) -> ProductReminderRepository {
        ProductReminderRepository(
            service: service,
            imageLoader: imageLoader,
            attachmentStager: ReminderAttachmentStager(directory: directory),
            clock: clock
        )
    }

    static func storedRequest(
        productID: Product.ID = 7,
        notificationID: LocalNotificationID? = nil,
        categoryID: LocalNotificationCategoryID? = AppNotificationIdentifiers.storeCategory,
        metadata: [String: LocalNotificationMetadataValue]? = nil,
        deepLink: URL? = nil,
        attachments: [LocalNotificationStoredAttachment] = [],
        title: String = "Price reminder",
        subtitle: String = "Product",
        body: String = "Take another look.",
        sound: LocalNotificationSound = .default
    ) throws -> LocalNotificationStoredRequest {
        let id = try notificationID ?? AppNotificationIdentifiers.productRequest(productID)
        let typedMetadata = try ProductReminderMetadata(productID: productID)
        let resolvedDeepLink: URL
        if let deepLink {
            resolvedDeepLink = deepLink
        } else {
            resolvedDeepLink = try AppNotificationIdentifiers.productDeepLink(productID)
        }
        return LocalNotificationStoredRequest(
            id: id,
            content: LocalNotificationStoredContent(
                title: title,
                subtitle: subtitle,
                body: body,
                sound: sound,
                categoryID: categoryID,
                attachments: attachments,
                metadata: metadata ?? typedMetadata.notificationValues,
                deepLink: resolvedDeepLink
            ),
            trigger: .timeInterval(seconds: 5, repeats: false)
        )
    }

    static func event(
        productID: Product.ID = 7,
        eventID: LocalNotificationID? = nil,
        request: LocalNotificationStoredRequest? = nil
    ) throws -> LocalNotificationEvent {
        let stored = try request ?? storedRequest(productID: productID)
        return .action(
            notification: LocalNotificationEventNotification(
                id: try eventID ?? AppNotificationIdentifiers.productRequest(productID),
                payload: .decoded(stored)
            ),
            id: AppNotificationIdentifiers.remindLaterAction,
            deepLink: nil
        )
    }

    static func pending(
        productID: Product.ID,
        nextTriggerDate: Date?
    ) throws -> LocalNotificationPendingSnapshot {
        let request = try storedRequest(productID: productID)
        return LocalNotificationPendingSnapshot(
            id: request.id,
            payload: .decoded(request),
            nextTriggerDate: nextTriggerDate
        )
    }
}
