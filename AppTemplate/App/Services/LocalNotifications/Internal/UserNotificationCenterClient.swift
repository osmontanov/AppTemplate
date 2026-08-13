import Foundation
import UserNotifications

@MainActor
protocol UserNotificationCenterAPI: AnyObject, Sendable {
    func notificationSettings() async -> UNNotificationSettings
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func notificationCategories() async -> Set<UNNotificationCategory>
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) async
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func deliveredNotifications() async -> [UNNotification]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) async
    func setBadgeCount(_ count: Int) async throws
}

@MainActor
final class UserNotificationCenterClient: LocalNotificationCenterClient {
    private let center: UNUserNotificationCenter?
    private let api: (any UserNotificationCenterAPI)?
    private let requestMapper: @MainActor (
        LocalNotificationSystemRequest
    ) throws -> UNNotificationRequest

    init(center: UNUserNotificationCenter) {
        self.center = center
        api = nil
        requestMapper = { request in
            try LocalNotificationSystemMapper.notificationRequest(request)
        }
    }

    init(
        api: any UserNotificationCenterAPI,
        requestMapper: @escaping @MainActor (
            LocalNotificationSystemRequest
        ) throws -> UNNotificationRequest = { request in
            try LocalNotificationSystemMapper.notificationRequest(request)
        }
    ) {
        center = nil
        self.api = api
        self.requestMapper = requestMapper
    }

    nonisolated func settings() async -> LocalNotificationSettings {
        await mappedSettings()
    }

    nonisolated func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        try await requestMappedAuthorization(options)
    }

    nonisolated func replaceManagedCategories(
        prefix: String,
        categories: [LocalNotificationSystemCategory]
    ) async throws {
        await replaceMappedCategories(prefix: prefix, categories: categories)
    }

    nonisolated func add(_ request: LocalNotificationSystemRequest) async throws {
        try await addMappedRequest(request)
    }

    nonisolated func pending() async -> [LocalNotificationSystemRequest] {
        await mappedPendingRequests()
    }

    nonisolated func delivered() async -> [LocalNotificationSystemDelivered] {
        await mappedDeliveredNotifications()
    }

    nonisolated func removePending(_ physicalIDs: Set<String>) async {
        await removeMappedPending(physicalIDs)
    }

    nonisolated func removeDelivered(_ physicalIDs: Set<String>) async {
        await removeMappedDelivered(physicalIDs)
    }

    nonisolated func setBadgeCount(_ count: Int) async throws {
        try await setMappedBadgeCount(count)
    }

    private func mappedSettings() async -> LocalNotificationSettings {
        let systemSettings: UNNotificationSettings
        if let api {
            systemSettings = await api.notificationSettings()
        } else {
            systemSettings = await center!.notificationSettings()
        }
        return LocalNotificationSystemMapper.settings(systemSettings)
    }

    private func requestMappedAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        let mapped = LocalNotificationSystemMapper.authorizationOptions(options)
        if let api {
            return try await api.requestAuthorization(options: mapped)
        }
        return try await center!.requestAuthorization(options: mapped)
    }

    private func replaceMappedCategories(
        prefix: String,
        categories: [LocalNotificationSystemCategory]
    ) async {
        let existing: Set<UNNotificationCategory>
        if let api {
            existing = await api.notificationCategories()
        } else {
            existing = await center!.notificationCategories()
        }
        let foreign = existing.filter { !$0.identifier.hasPrefix(prefix) }
        let managed = categories.map(LocalNotificationSystemMapper.notificationCategory)
        let replacement = Set(foreign).union(managed)
        if let api {
            await api.setNotificationCategories(replacement)
        } else {
            center!.setNotificationCategories(replacement)
        }
    }

    private func addMappedRequest(_ request: LocalNotificationSystemRequest) async throws {
        let mapped = try requestMapper(request)
        try Task.checkCancellation()
        if let api {
            try await api.add(mapped)
        } else {
            try await center!.add(mapped)
        }
    }

    private func mappedPendingRequests() async -> [LocalNotificationSystemRequest] {
        let requests: [UNNotificationRequest]
        if let api {
            requests = await api.pendingNotificationRequests()
        } else {
            requests = await center!.pendingNotificationRequests()
        }
        return requests.map(LocalNotificationSystemMapper.systemRequest)
    }

    private func mappedDeliveredNotifications() async -> [LocalNotificationSystemDelivered] {
        let notifications: [UNNotification]
        if let api {
            notifications = await api.deliveredNotifications()
        } else {
            notifications = await center!.deliveredNotifications()
        }
        return notifications.map(LocalNotificationSystemMapper.systemDelivered)
    }

    private func removeMappedPending(_ physicalIDs: Set<String>) async {
        let identifiers = physicalIDs.sorted()
        if let api {
            await api.removePendingNotificationRequests(withIdentifiers: identifiers)
        } else {
            center!.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private func removeMappedDelivered(_ physicalIDs: Set<String>) async {
        let identifiers = physicalIDs.sorted()
        if let api {
            await api.removeDeliveredNotifications(withIdentifiers: identifiers)
        } else {
            center!.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    private func setMappedBadgeCount(_ count: Int) async throws {
        if let api {
            try await api.setBadgeCount(count)
        } else {
            try await center!.setBadgeCount(count)
        }
    }
}

@MainActor
struct UserNotificationCenterRuntime {
    let client: UserNotificationCenterClient
    private let delegateInstaller: (any UNUserNotificationCenterDelegate) -> Void

    init(
        client: UserNotificationCenterClient,
        delegateInstaller: @escaping (
            any UNUserNotificationCenterDelegate
        ) -> Void
    ) {
        self.client = client
        self.delegateInstaller = delegateInstaller
    }

    func installDelegate(
        _ delegate: any UNUserNotificationCenterDelegate
    ) {
        delegateInstaller(delegate)
    }
}

@MainActor
enum UserNotificationCenterRuntimeFactory {
    static func live() -> UserNotificationCenterRuntime {
        let center = UNUserNotificationCenter.current()
        return UserNotificationCenterRuntime(
            client: UserNotificationCenterClient(center: center),
            delegateInstaller: { delegate in
                center.delegate = delegate
            }
        )
    }

    static func make(
        makeClient: () -> UserNotificationCenterClient,
        installDelegate: @escaping (
            any UNUserNotificationCenterDelegate
        ) -> Void
    ) -> UserNotificationCenterRuntime {
        UserNotificationCenterRuntime(
            client: makeClient(),
            delegateInstaller: installDelegate
        )
    }
}
