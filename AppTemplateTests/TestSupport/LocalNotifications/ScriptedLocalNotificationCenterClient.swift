import Foundation
@testable import AppTemplate

nonisolated
enum ScriptedLocalNotificationCenterOperation: Hashable, Sendable {
    case settings
    case requestAuthorization(LocalNotificationAuthorizationOptions)
    case replaceManagedCategories(prefix: String, categories: [LocalNotificationSystemCategory])
    case add(LocalNotificationSystemRequest)
    case pending
    case delivered
    case removePending(Set<String>)
    case removeDelivered(Set<String>)
    case setBadgeCount(Int)
}

actor ScriptedLocalNotificationCenterClient: LocalNotificationCenterClient {
    typealias AuthorizationHandler = @Sendable (LocalNotificationAuthorizationOptions) async throws -> Bool
    typealias CategoryHandler = @Sendable (String, [LocalNotificationSystemCategory]) async throws -> Void
    typealias AddHandler = @Sendable (LocalNotificationSystemRequest) async throws -> Void
    typealias BadgeHandler = @Sendable (Int) async throws -> Void

    private let configuredSettings: LocalNotificationSettings
    private let authorizationResult: Result<Bool, any Error>
    private let categoryError: (any Error)?
    private let addError: (any Error)?
    private let pendingResult: [LocalNotificationSystemRequest]
    private let deliveredResult: [LocalNotificationSystemDelivered]
    private let badgeError: (any Error)?
    private let authorizationHandler: AuthorizationHandler?
    private let categoryHandler: CategoryHandler?
    private let addHandler: AddHandler?
    private let badgeHandler: BadgeHandler?
    private var recordedOperations: [ScriptedLocalNotificationCenterOperation] = []

    init(
        settings: LocalNotificationSettings = .scriptedFixture,
        authorizationResult: Result<Bool, any Error> = .success(true),
        categoryError: (any Error)? = nil,
        addError: (any Error)? = nil,
        pending: [LocalNotificationSystemRequest] = [],
        delivered: [LocalNotificationSystemDelivered] = [],
        badgeError: (any Error)? = nil,
        authorizationHandler: AuthorizationHandler? = nil,
        categoryHandler: CategoryHandler? = nil,
        addHandler: AddHandler? = nil,
        badgeHandler: BadgeHandler? = nil
    ) {
        configuredSettings = settings
        self.authorizationResult = authorizationResult
        self.categoryError = categoryError
        self.addError = addError
        pendingResult = pending
        deliveredResult = delivered
        self.badgeError = badgeError
        self.authorizationHandler = authorizationHandler
        self.categoryHandler = categoryHandler
        self.addHandler = addHandler
        self.badgeHandler = badgeHandler
    }

    func settings() async -> LocalNotificationSettings {
        recordedOperations.append(.settings)
        return configuredSettings
    }

    func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        recordedOperations.append(.requestAuthorization(options))
        if let authorizationHandler {
            return try await authorizationHandler(options)
        }
        return try authorizationResult.get()
    }

    func replaceManagedCategories(
        prefix: String,
        categories: [LocalNotificationSystemCategory]
    ) async throws {
        recordedOperations.append(.replaceManagedCategories(prefix: prefix, categories: categories))
        if let categoryHandler {
            try await categoryHandler(prefix, categories)
            return
        }
        if let categoryError { throw categoryError }
    }

    func add(_ request: LocalNotificationSystemRequest) async throws {
        recordedOperations.append(.add(request))
        if let addHandler {
            try await addHandler(request)
            return
        }
        if let addError { throw addError }
    }

    func pending() async -> [LocalNotificationSystemRequest] {
        recordedOperations.append(.pending)
        return pendingResult
    }

    func delivered() async -> [LocalNotificationSystemDelivered] {
        recordedOperations.append(.delivered)
        return deliveredResult
    }

    func removePending(_ physicalIDs: Set<String>) async {
        recordedOperations.append(.removePending(physicalIDs))
    }

    func removeDelivered(_ physicalIDs: Set<String>) async {
        recordedOperations.append(.removeDelivered(physicalIDs))
    }

    func setBadgeCount(_ count: Int) async throws {
        recordedOperations.append(.setBadgeCount(count))
        if let badgeHandler {
            try await badgeHandler(count)
            return
        }
        if let badgeError { throw badgeError }
    }

    func operations() -> [ScriptedLocalNotificationCenterOperation] {
        recordedOperations
    }

    func addedRequests() -> [LocalNotificationSystemRequest] {
        recordedOperations.compactMap { operation in
            guard case let .add(request) = operation else { return nil }
            return request
        }
    }

    func categoryReplacements() -> [(prefix: String, categories: [LocalNotificationSystemCategory])] {
        recordedOperations.compactMap { operation in
            guard case let .replaceManagedCategories(prefix, categories) = operation else {
                return nil
            }
            return (prefix, categories)
        }
    }

    func removedPendingIDs() -> [Set<String>] {
        recordedOperations.compactMap { operation in
            guard case let .removePending(identifiers) = operation else { return nil }
            return identifiers
        }
    }

    func removedDeliveredIDs() -> [Set<String>] {
        recordedOperations.compactMap { operation in
            guard case let .removeDelivered(identifiers) = operation else { return nil }
            return identifiers
        }
    }

    func badgeCounts() -> [Int] {
        recordedOperations.compactMap { operation in
            guard case let .setBadgeCount(count) = operation else { return nil }
            return count
        }
    }
}

nonisolated
extension LocalNotificationSystemRequest {
    static func fixture(
        logicalID: String,
        body: String = "Body"
    ) throws -> Self {
        let namespace = try LocalNotificationNamespace()
        let requestID = try LocalNotificationID(logicalID)
        let envelope = LocalNotificationEnvelopeV1(
            requestID: requestID,
            categoryID: nil,
            sound: .none,
            metadata: [:],
            defaultDeepLink: nil,
            foregroundPresentation: [],
            actionRoutes: []
        )
        return Self(
            identifier: namespace.physicalRequestID(requestID),
            content: LocalNotificationSystemContent(
                title: "",
                subtitle: "",
                body: body,
                badge: nil,
                sound: .none,
                categoryIdentifier: nil,
                threadIdentifier: nil,
                targetContentIdentifier: nil,
                summaryArgument: nil,
                summaryArgumentCount: nil,
                relevanceScore: nil,
                interruptionLevel: .active,
                attachments: [],
                envelopeData: try LocalNotificationEnvelopeCodec.encode(envelope)
            ),
            trigger: .immediate
        )
    }
}

nonisolated
private extension LocalNotificationSettings {
    static let scriptedFixture = LocalNotificationSettings(
        authorizationStatus: .notDetermined,
        alertSetting: .disabled,
        soundSetting: .disabled,
        badgeSetting: .disabled,
        notificationCenterSetting: .disabled,
        lockScreenSetting: .disabled,
        alertStyle: .none,
        previewSetting: .never
    )
}
