import Foundation

nonisolated
struct LocalNotificationServiceValidator: Sendable {
    let validateAuthorization: @Sendable (LocalNotificationAuthorizationOptions) throws -> Void
    let validateRequest: @Sendable (LocalNotificationRequest) throws -> Void
    let validateCategories: @Sendable ([LocalNotificationCategory]) throws -> Void

    static let live = Self(
        validateAuthorization: LocalNotificationValidator.validate(authorization:),
        validateRequest: LocalNotificationValidator.validate(request:),
        validateCategories: LocalNotificationValidator.validate(categories:)
    )
}

nonisolated
struct LocalNotificationServiceEnvelopeCodec: Sendable {
    typealias DecodeManaged = @Sendable (
        Data?,
        String,
        LocalNotificationNamespace,
        LocalNotificationDeepLinkPolicy
    ) throws -> LocalNotificationEnvelopeV1

    let encode: @Sendable (LocalNotificationEnvelopeV1) throws -> Data
    let decodeManaged: DecodeManaged

    static let live = Self(
        encode: LocalNotificationEnvelopeCodec.encode,
        decodeManaged: { data, physicalRequestID, namespace, deepLinkPolicy in
            try LocalNotificationEnvelopeCodec.decodeManaged(
                data,
                physicalRequestID: physicalRequestID,
                namespace: namespace,
                deepLinkPolicy: deepLinkPolicy
            )
        }
    )
}

nonisolated
struct LocalNotificationServiceAttachmentStager: Sendable {
    let stage: @Sendable (
        [LocalNotificationAttachment],
        LocalNotificationID
    ) async throws -> [LocalNotificationStagedAttachment]
    let cleanup: @Sendable ([LocalNotificationStagedAttachment]) -> Void

    static let live = Self(
        stage: { attachments, requestID in
            try LocalNotificationAttachmentStager.live().stage(
                attachments,
                requestID: requestID
            )
        },
        cleanup: { staged in
            _ = LocalNotificationAttachmentStager.live().cleanup(staged)
        }
    )
}

actor LocalNotificationService: ILocalNotificationService {
    private struct PreparedCategories: Sendable {
        let ordered: [LocalNotificationCategory]
        let byID: [LocalNotificationCategoryID: LocalNotificationCategory]
        let system: [LocalNotificationSystemCategory]
    }

    private enum SnapshotConstructionError: Error {
        case unsupportedTrigger
    }

    private let namespace: LocalNotificationNamespace
    private let validator: LocalNotificationServiceValidator
    private let deepLinkPolicy: LocalNotificationDeepLinkPolicy
    private let envelopeCodec: LocalNotificationServiceEnvelopeCodec
    private let stager: LocalNotificationServiceAttachmentStager
    private let eventHub: LocalNotificationEventHub
    private let client: any LocalNotificationCenterClient
    private let catalogOperationGate = LocalNotificationServiceOperationGate()

    private var startupCategories: [LocalNotificationCategory]
    private var registeredCategoriesByID: [
        LocalNotificationCategoryID: LocalNotificationCategory
    ] = [:]
    private var didBootstrapCategories = false

    init(
        namespace: LocalNotificationNamespace,
        validator: LocalNotificationServiceValidator,
        deepLinkPolicy: LocalNotificationDeepLinkPolicy,
        envelopeCodec: LocalNotificationServiceEnvelopeCodec,
        stager: LocalNotificationServiceAttachmentStager,
        eventHub: LocalNotificationEventHub,
        startupCategories: [LocalNotificationCategory],
        client: any LocalNotificationCenterClient
    ) {
        self.namespace = namespace
        self.validator = validator
        self.deepLinkPolicy = deepLinkPolicy
        self.envelopeCodec = envelopeCodec
        self.stager = stager
        self.eventHub = eventHub
        self.startupCategories = startupCategories
        self.client = client
    }

    func settings() async -> LocalNotificationSettings {
        await client.settings()
    }

    func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        try Task.checkCancellation()
        try validator.validateAuthorization(options)
        try Task.checkCancellation()
        do {
            return try await client.requestAuthorization(options)
        } catch {
            try Self.throwSystemError(error, operation: .authorization)
        }
    }

    func setCategories(
        _ categories: [LocalNotificationCategory]
    ) async throws {
        try await catalogOperationGate.withExclusiveAccess { [self] in
            try await performSetCategories(categories)
        }
    }

    func bootstrapCategoriesIfNeeded() async throws {
        try await catalogOperationGate.withExclusiveAccess { [self] in
            try await performBootstrapCategoriesIfNeeded()
        }
    }

    func schedule(
        _ request: LocalNotificationRequest
    ) async throws {
        try await catalogOperationGate.withExclusiveAccess { [self] in
            try await performSchedule(request)
        }
    }

    func pending() async -> [LocalNotificationPendingSnapshot] {
        let requests = await client.pending()
        return requests.compactMap { request in
            guard let logicalID = namespace.logicalRequestID(request.identifier) else {
                return nil
            }
            return LocalNotificationPendingSnapshot(
                id: logicalID,
                payload: snapshotPayload(for: request, logicalID: logicalID),
                nextTriggerDate: request.nextTriggerDate
            )
        }.sorted(by: Self.pendingPrecedes)
    }

    func delivered() async -> [LocalNotificationDeliveredSnapshot] {
        let notifications = await client.delivered()
        return notifications.compactMap { notification in
            let request = notification.request
            guard let logicalID = namespace.logicalRequestID(request.identifier) else {
                return nil
            }
            return LocalNotificationDeliveredSnapshot(
                id: logicalID,
                payload: snapshotPayload(for: request, logicalID: logicalID),
                deliveredAt: notification.deliveredAt
            )
        }.sorted(by: Self.deliveredPrecedes)
    }

    func removePending(
        _ identifiers: Set<LocalNotificationID>
    ) async {
        await client.removePending(Set(identifiers.map(namespace.physicalRequestID)))
    }

    func removeAllPending() async {
        let ownedIdentifiers = Set(
            await client.pending().compactMap { request in
                namespace.logicalRequestID(request.identifier).map { _ in request.identifier }
            }
        )
        await client.removePending(ownedIdentifiers)
    }

    func removeDelivered(
        _ identifiers: Set<LocalNotificationID>
    ) async {
        await client.removeDelivered(Set(identifiers.map(namespace.physicalRequestID)))
    }

    func removeAllDelivered() async {
        let ownedIdentifiers = Set(
            await client.delivered().compactMap { notification in
                let identifier = notification.request.identifier
                return namespace.logicalRequestID(identifier).map { _ in identifier }
            }
        )
        await client.removeDelivered(ownedIdentifiers)
    }

    func setBadgeCount(_ count: Int) async throws {
        try Task.checkCancellation()
        guard count >= 0 else {
            throw LocalNotificationServiceError.invalidContent(.invalidBadge)
        }
        try Task.checkCancellation()
        do {
            try await client.setBadgeCount(count)
        } catch {
            try Self.throwSystemError(error, operation: .setBadge)
        }
    }

    func clearBadge() async throws {
        try await setBadgeCount(0)
    }

    func events() async -> AsyncStream<LocalNotificationEvent> {
        await eventHub.events()
    }

    private func performSetCategories(
        _ categories: [LocalNotificationCategory]
    ) async throws {
        try Task.checkCancellation()
        let prepared = try prepareCategories(categories)
        try Task.checkCancellation()
        do {
            try await client.replaceManagedCategories(
                prefix: categoryNamespacePrefix,
                categories: prepared.system
            )
        } catch {
            try Self.throwSystemError(error, operation: .setCategories)
        }
        startupCategories = prepared.ordered
        registeredCategoriesByID = prepared.byID
        didBootstrapCategories = true
    }

    private func performBootstrapCategoriesIfNeeded() async throws {
        guard !didBootstrapCategories else { return }
        try Task.checkCancellation()
        let prepared = try prepareCategories(startupCategories)
        try Task.checkCancellation()
        do {
            try await client.replaceManagedCategories(
                prefix: categoryNamespacePrefix,
                categories: prepared.system
            )
        } catch {
            try Self.throwSystemError(error, operation: .setCategories)
        }
        registeredCategoriesByID = prepared.byID
        didBootstrapCategories = true
    }

    private func performSchedule(
        _ request: LocalNotificationRequest
    ) async throws {
        try Task.checkCancellation()
        try validator.validateRequest(request)
        try validateDeepLink(request.content.deepLink)

        try await performBootstrapCategoriesIfNeeded()

        let category = try registeredCategory(for: request.content.categoryID)
        let envelope = LocalNotificationEnvelopeV1(
            requestID: request.id,
            categoryID: request.content.categoryID,
            sound: request.content.sound,
            metadata: request.content.metadata,
            defaultDeepLink: request.content.deepLink,
            foregroundPresentation: request.content.foregroundPresentation,
            actionRoutes: category.map(actionRoutes) ?? []
        )
        let envelopeData = try envelopeCodec.encode(envelope)
        let staged = try await stager.stage(request.content.attachments, request.id)
        defer { stager.cleanup(staged) }

        let systemRequest = makeSystemRequest(
            from: request,
            envelopeData: envelopeData,
            staged: staged
        )
        try Task.checkCancellation()
        do {
            try await client.add(systemRequest)
        } catch {
            try Self.throwSystemError(error, operation: .schedule)
        }
    }

    private var categoryNamespacePrefix: String {
        "\(namespace.value).category."
    }

    private func prepareCategories(
        _ categories: [LocalNotificationCategory]
    ) throws -> PreparedCategories {
        try validator.validateCategories(categories)
        for category in categories {
            for action in category.actions {
                try validateDeepLink(action.deepLink)
            }
        }
        return PreparedCategories(
            ordered: categories,
            byID: Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) }),
            system: categories.map(systemCategory)
        )
    }

    private func registeredCategory(
        for identifier: LocalNotificationCategoryID?
    ) throws -> LocalNotificationCategory? {
        guard let identifier else { return nil }
        guard let category = registeredCategoriesByID[identifier] else {
            throw LocalNotificationServiceError.invalidCategory(.unknownCategory)
        }
        return category
    }

    private func validateDeepLink(_ deepLink: URL?) throws {
        guard let deepLink else { return }
        guard deepLinkPolicy.isValid(deepLink) else {
            throw LocalNotificationServiceError.invalidDeepLink
        }
    }

    private func actionRoutes(
        _ category: LocalNotificationCategory
    ) -> [LocalNotificationActionRoute] {
        category.actions.map { action in
            switch action {
            case let .button(button):
                .button(id: button.id, deepLink: button.deepLink)
            case let .textInput(textInput):
                .textInput(id: textInput.id, deepLink: textInput.deepLink)
            }
        }
    }

    private func systemCategory(
        _ category: LocalNotificationCategory
    ) -> LocalNotificationSystemCategory {
        LocalNotificationSystemCategory(
            identifier: namespace.physicalCategoryID(category.id),
            actions: category.actions.map { action in
                switch action {
                case let .button(button):
                    .button(
                        LocalNotificationSystemButtonAction(
                            identifier: namespace.physicalActionID(
                                category: category.id,
                                action: button.id
                            ),
                            title: button.title,
                            options: button.options
                        )
                    )
                case let .textInput(textInput):
                    .textInput(
                        LocalNotificationSystemTextInputAction(
                            identifier: namespace.physicalActionID(
                                category: category.id,
                                action: textInput.id
                            ),
                            title: textInput.title,
                            options: textInput.options,
                            textInputButtonTitle: textInput.textInputButtonTitle,
                            textInputPlaceholder: textInput.textInputPlaceholder
                        )
                    )
                }
            },
            hiddenPreviewsBodyPlaceholder: category.hiddenPreviewsBodyPlaceholder,
            categorySummaryFormat: category.categorySummaryFormat,
            hiddenPreviewsShowTitle: category.hiddenPreviewsShowTitle,
            hiddenPreviewsShowSubtitle: category.hiddenPreviewsShowSubtitle,
            reportsDismissal: category.reportsDismissal
        )
    }

    private func makeSystemRequest(
        from request: LocalNotificationRequest,
        envelopeData: Data,
        staged: [LocalNotificationStagedAttachment]
    ) -> LocalNotificationSystemRequest {
        let content = request.content
        return LocalNotificationSystemRequest(
            identifier: namespace.physicalRequestID(request.id),
            content: LocalNotificationSystemContent(
                title: content.title,
                subtitle: content.subtitle,
                body: content.body,
                badge: content.badge,
                sound: Self.systemSound(content.sound),
                categoryIdentifier: content.categoryID.map(namespace.physicalCategoryID),
                threadIdentifier: content.threadIdentifier,
                targetContentIdentifier: content.targetContentIdentifier,
                summaryArgument: content.summaryArgument,
                summaryArgumentCount: content.summaryArgumentCount,
                relevanceScore: content.relevanceScore,
                interruptionLevel: content.interruptionLevel,
                attachments: staged.map(\.systemAttachment),
                envelopeData: envelopeData
            ),
            trigger: Self.systemTrigger(request.trigger)
        )
    }

    private func snapshotPayload(
        for request: LocalNotificationSystemRequest,
        logicalID: LocalNotificationID
    ) -> LocalNotificationSnapshotPayload {
        do {
            let envelope = try envelopeCodec.decodeManaged(
                request.content.envelopeData,
                request.identifier,
                namespace,
                deepLinkPolicy
            )
            let trigger = try Self.storedTrigger(request.trigger)
            let attachments: [LocalNotificationStoredAttachment] = request.content.attachments.compactMap { attachment in
                guard let decoded = namespace.logicalAttachmentID(attachment.identifier),
                      decoded.request == logicalID,
                      let typeIdentifier = attachment.typeIdentifier else {
                    return nil
                }
                return LocalNotificationStoredAttachment(
                    id: decoded.attachment,
                    fileURL: attachment.fileURL,
                    typeIdentifier: typeIdentifier
                )
            }
            let content = request.content
            return .decoded(
                LocalNotificationStoredRequest(
                    id: logicalID,
                    content: LocalNotificationStoredContent(
                        title: content.title,
                        subtitle: content.subtitle,
                        body: content.body,
                        badge: content.badge,
                        sound: envelope.sound,
                        categoryID: envelope.categoryID,
                        threadIdentifier: content.threadIdentifier,
                        targetContentIdentifier: content.targetContentIdentifier,
                        summaryArgument: content.summaryArgument,
                        summaryArgumentCount: content.summaryArgumentCount,
                        relevanceScore: content.relevanceScore,
                        interruptionLevel: content.interruptionLevel,
                        attachments: attachments,
                        metadata: envelope.metadata,
                        deepLink: envelope.defaultDeepLink,
                        foregroundPresentation: envelope.foregroundPresentation
                    ),
                    trigger: trigger
                )
            )
        } catch {
            return .unreadable(Self.unreadableReason(for: error))
        }
    }

    private nonisolated static func systemSound(
        _ sound: LocalNotificationSound
    ) -> LocalNotificationSystemSound {
        switch sound {
        case .none: .none
        case .default: .default
        case let .named(resourceName): .named(resourceName: resourceName)
        }
    }

    private nonisolated static func systemTrigger(
        _ trigger: LocalNotificationTrigger
    ) -> LocalNotificationSystemTrigger {
        switch trigger {
        case .immediate: .immediate
        case let .timeInterval(seconds, repeats):
            .timeInterval(seconds: seconds, repeats: repeats)
        case let .calendar(components, repeats):
            .calendar(components, repeats: repeats)
        }
    }

    private nonisolated static func storedTrigger(
        _ trigger: LocalNotificationSystemTrigger
    ) throws -> LocalNotificationTrigger {
        switch trigger {
        case .immediate: .immediate
        case let .timeInterval(seconds, repeats):
            .timeInterval(seconds: seconds, repeats: repeats)
        case let .calendar(components, repeats):
            .calendar(components, repeats: repeats)
        case .unknown:
            throw SnapshotConstructionError.unsupportedTrigger
        }
    }

    private nonisolated static func unreadableReason(
        for error: any Error
    ) -> LocalNotificationUnreadableReason {
        switch error {
        case LocalNotificationEnvelopeError.missingEnvelope:
            .missingEnvelope
        case LocalNotificationEnvelopeError.identifierMismatch:
            .identifierMismatch
        case LocalNotificationServiceError.unsupportedEnvelopeVersion:
            .unsupportedEnvelopeVersion
        default:
            .corruptEnvelope
        }
    }

    private nonisolated static func pendingPrecedes(
        _ lhs: LocalNotificationPendingSnapshot,
        _ rhs: LocalNotificationPendingSnapshot
    ) -> Bool {
        switch (lhs.nextTriggerDate, rhs.nextTriggerDate) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            lhsDate < rhsDate
        case (_?, nil):
            true
        case (nil, _?):
            false
        default:
            lhs.id.value < rhs.id.value
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

    private nonisolated static func throwSystemError(
        _ error: any Error,
        operation: LocalNotificationSystemOperation
    ) throws -> Never {
        if error is CancellationError {
            throw CancellationError()
        }
        let systemError = error as NSError
        throw LocalNotificationServiceError.system(
            operation: operation,
            domain: systemError.domain,
            code: systemError.code
        )
    }
}

nonisolated
private extension LocalNotificationAction {
    var deepLink: URL? {
        switch self {
        case let .button(button): button.deepLink
        case let .textInput(textInput): textInput.deepLink
        }
    }
}

private actor LocalNotificationServiceOperationGate {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func withExclusiveAccess<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        await acquire()
        do {
            let result = try await operation()
            release()
            return result
        } catch {
            release()
            throw error
        }
    }

    private func acquire() async {
        guard isLocked else {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard let next = waiters.first else {
            isLocked = false
            return
        }
        waiters.removeFirst()
        next.resume()
    }
}
