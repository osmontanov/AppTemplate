import Foundation
import UniformTypeIdentifiers

actor InMemoryLocalNotificationService: ILocalNotificationService {
    private let configuredSettings: LocalNotificationSettings
    private let authorizationResult: Bool
    private let deepLinkPolicy: LocalNotificationDeepLinkPolicy
    private let eventHub: LocalNotificationEventHub

    private var categoriesByID: [LocalNotificationCategoryID: LocalNotificationCategory]
    private var pendingByID: [LocalNotificationID: LocalNotificationPendingSnapshot] = [:]
    private var deliveredByID: [LocalNotificationID: LocalNotificationDeliveredSnapshot] = [:]
    private var badgeCount = 0

    init(
        settings: LocalNotificationSettings,
        authorizationResult: Bool,
        categories: [LocalNotificationCategory],
        deepLinkPolicy: LocalNotificationDeepLinkPolicy,
        eventHub: LocalNotificationEventHub
    ) {
        configuredSettings = settings
        self.authorizationResult = authorizationResult
        categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        self.deepLinkPolicy = deepLinkPolicy
        self.eventHub = eventHub
    }

    func settings() async -> LocalNotificationSettings {
        configuredSettings
    }

    func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        try Task.checkCancellation()
        try LocalNotificationValidator.validate(authorization: options)
        try Task.checkCancellation()
        return authorizationResult
    }

    func setCategories(
        _ categories: [LocalNotificationCategory]
    ) async throws {
        try Task.checkCancellation()
        try LocalNotificationValidator.validate(categories: categories)
        try validateDeepLinks(in: categories)
        let replacement = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        try Task.checkCancellation()
        categoriesByID = replacement
    }

    func schedule(
        _ request: LocalNotificationRequest
    ) async throws {
        try Task.checkCancellation()
        try LocalNotificationValidator.validate(request: request)
        try validateDeepLink(request.content.deepLink)
        if let categoryID = request.content.categoryID,
           categoriesByID[categoryID] == nil {
            throw LocalNotificationServiceError.invalidCategory(.unknownCategory)
        }
        let nextTriggerDate = try nextTriggerDate(for: request.trigger)
        let storedRequest = try makeStoredRequest(from: request)
        let snapshot = LocalNotificationPendingSnapshot(
            id: request.id,
            payload: .decoded(storedRequest),
            nextTriggerDate: nextTriggerDate
        )
        try Task.checkCancellation()
        pendingByID[request.id] = snapshot
    }

    func pending() async -> [LocalNotificationPendingSnapshot] {
        pendingByID.values.sorted(by: Self.pendingPrecedes)
    }

    func delivered() async -> [LocalNotificationDeliveredSnapshot] {
        deliveredByID.values.sorted(by: Self.deliveredPrecedes)
    }

    func removePending(
        _ identifiers: Set<LocalNotificationID>
    ) async {
        for identifier in identifiers { pendingByID[identifier] = nil }
    }

    func removeAllPending() async {
        pendingByID.removeAll()
    }

    func removeDelivered(
        _ identifiers: Set<LocalNotificationID>
    ) async {
        for identifier in identifiers { deliveredByID[identifier] = nil }
    }

    func removeAllDelivered() async {
        deliveredByID.removeAll()
    }

    func setBadgeCount(_ count: Int) async throws {
        try Task.checkCancellation()
        guard count >= 0 else {
            throw LocalNotificationServiceError.invalidContent(.invalidBadge)
        }
        try Task.checkCancellation()
        badgeCount = count
    }

    func clearBadge() async throws {
        try await setBadgeCount(0)
    }

    func events() async -> AsyncStream<LocalNotificationEvent> {
        await eventHub.events()
    }

    func deliverForTesting(id: LocalNotificationID, at date: Date) {
        guard let pending = pendingByID.removeValue(forKey: id) else { return }
        deliveredByID[id] = LocalNotificationDeliveredSnapshot(
            id: id,
            payload: pending.payload,
            deliveredAt: date
        )
    }

    func publishForTesting(_ event: LocalNotificationEvent) async {
        await eventHub.publish(event)
    }

    func registeredCategoriesForTesting() -> [LocalNotificationCategory] {
        categoriesByID.values.sorted { $0.id.value < $1.id.value }
    }

    func badgeCountForTesting() -> Int {
        badgeCount
    }

    private func validateDeepLinks(
        in categories: [LocalNotificationCategory]
    ) throws {
        for category in categories {
            for action in category.actions {
                switch action {
                case let .button(button):
                    try validateDeepLink(button.deepLink)
                case let .textInput(textInput):
                    try validateDeepLink(textInput.deepLink)
                }
            }
        }
    }

    private func validateDeepLink(_ deepLink: URL?) throws {
        guard let deepLink else { return }
        guard deepLinkPolicy.isValid(deepLink) else {
            throw LocalNotificationServiceError.invalidDeepLink
        }
    }

    private func makeStoredRequest(
        from request: LocalNotificationRequest
    ) throws -> LocalNotificationStoredRequest {
        let storedAttachments = try request.content.attachments.map(validateAndStore)
        let content = request.content
        return LocalNotificationStoredRequest(
            id: request.id,
            content: LocalNotificationStoredContent(
                title: content.title,
                subtitle: content.subtitle,
                body: content.body,
                badge: content.badge,
                sound: content.sound,
                categoryID: content.categoryID,
                threadIdentifier: content.threadIdentifier,
                targetContentIdentifier: content.targetContentIdentifier,
                summaryArgument: content.summaryArgument,
                summaryArgumentCount: content.summaryArgumentCount,
                relevanceScore: content.relevanceScore,
                interruptionLevel: content.interruptionLevel,
                attachments: storedAttachments,
                metadata: content.metadata,
                deepLink: content.deepLink,
                foregroundPresentation: content.foregroundPresentation
            ),
            trigger: request.trigger
        )
    }

    private func validateAndStore(
        _ attachment: LocalNotificationAttachment
    ) throws -> LocalNotificationStoredAttachment {
        let fileURL = attachment.fileURL
        guard fileURL.isFileURL else {
            throw attachmentError(attachment.id, .notFileURL)
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw attachmentError(attachment.id, .missing)
        }

        let values: URLResourceValues
        do {
            values = try fileURL.resourceValues(
                forKeys: [.contentTypeKey, .isRegularFileKey, .isSymbolicLinkKey]
            )
        } catch {
            throw attachmentError(attachment.id, .unreadable)
        }
        guard values.isSymbolicLink != true else {
            throw attachmentError(attachment.id, .symbolicLink)
        }
        guard values.isRegularFile == true else {
            throw attachmentError(attachment.id, .notRegularFile)
        }
        guard fileManager.isReadableFile(atPath: fileURL.path) else {
            throw attachmentError(attachment.id, .unreadable)
        }

        let contentType = attachment.options.typeHint.flatMap(UTType.init)
            ?? values.contentType
        guard let contentType,
              contentType.conforms(to: .image)
                || contentType.conforms(to: .audio)
                || contentType.conforms(to: .movie) else {
            throw attachmentError(attachment.id, .unsupportedType)
        }
        return LocalNotificationStoredAttachment(
            id: attachment.id,
            fileURL: fileURL,
            typeIdentifier: contentType.identifier
        )
    }

    private func attachmentError(
        _ identifier: LocalNotificationAttachmentID,
        _ failure: LocalNotificationAttachmentFailure
    ) -> LocalNotificationServiceError {
        .invalidAttachment(identifier, failure)
    }

    private func nextTriggerDate(
        for trigger: LocalNotificationTrigger
    ) throws -> Date? {
        let referenceDate = Date.now
        switch trigger {
        case .immediate:
            return nil
        case let .timeInterval(seconds, _):
            return referenceDate.addingTimeInterval(seconds)
        case let .calendar(components, _):
            guard let date = (components.calendar ?? Calendar.current).nextDate(
                after: referenceDate,
                matching: components,
                matchingPolicy: .strict
            ) else {
                throw LocalNotificationServiceError.invalidTrigger(.noNextTriggerDate)
            }
            return date
        }
    }

    private nonisolated static func pendingPrecedes(
        _ lhs: LocalNotificationPendingSnapshot,
        _ rhs: LocalNotificationPendingSnapshot
    ) -> Bool {
        switch (lhs.nextTriggerDate, rhs.nextTriggerDate) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.id.value < rhs.id.value
        }
    }

    private nonisolated static func deliveredPrecedes(
        _ lhs: LocalNotificationDeliveredSnapshot,
        _ rhs: LocalNotificationDeliveredSnapshot
    ) -> Bool {
        if lhs.deliveredAt != rhs.deliveredAt {
            return lhs.deliveredAt > rhs.deliveredAt
        }
        return lhs.id.value < rhs.id.value
    }
}
