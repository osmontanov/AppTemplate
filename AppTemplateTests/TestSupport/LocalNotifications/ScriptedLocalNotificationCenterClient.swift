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
    private let configuredSettings: LocalNotificationSettings
    private let authorizationResult: Result<Bool, any Error>
    private let categoryError: (any Error)?
    private let addError: (any Error)?
    private let pendingResult: [LocalNotificationSystemRequest]
    private let deliveredResult: [LocalNotificationSystemDelivered]
    private let badgeError: (any Error)?
    private var recordedOperations: [ScriptedLocalNotificationCenterOperation] = []

    init(
        settings: LocalNotificationSettings,
        authorizationResult: Result<Bool, any Error> = .success(true),
        categoryError: (any Error)? = nil,
        addError: (any Error)? = nil,
        pending: [LocalNotificationSystemRequest] = [],
        delivered: [LocalNotificationSystemDelivered] = [],
        badgeError: (any Error)? = nil
    ) {
        configuredSettings = settings
        self.authorizationResult = authorizationResult
        self.categoryError = categoryError
        self.addError = addError
        pendingResult = pending
        deliveredResult = delivered
        self.badgeError = badgeError
    }

    func settings() async -> LocalNotificationSettings {
        recordedOperations.append(.settings)
        return configuredSettings
    }

    func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        recordedOperations.append(.requestAuthorization(options))
        return try authorizationResult.get()
    }

    func replaceManagedCategories(
        prefix: String,
        categories: [LocalNotificationSystemCategory]
    ) async throws {
        recordedOperations.append(.replaceManagedCategories(prefix: prefix, categories: categories))
        if let categoryError { throw categoryError }
    }

    func add(_ request: LocalNotificationSystemRequest) async throws {
        recordedOperations.append(.add(request))
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
        if let badgeError { throw badgeError }
    }

    func operations() -> [ScriptedLocalNotificationCenterOperation] {
        recordedOperations
    }
}
