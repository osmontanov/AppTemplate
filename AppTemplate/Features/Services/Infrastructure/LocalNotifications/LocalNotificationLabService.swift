import Foundation

nonisolated
final class LocalNotificationLabService:
    ILocalNotificationLabService,
    ILocalNotificationAppWideCapabilities
{
    private let service: any ILocalNotificationService
    private let catalog: any IAppNotificationCategoryCatalog
    private let namespace: String

    init(
        service: any ILocalNotificationService,
        catalog: any IAppNotificationCategoryCatalog,
        namespace: String
    ) {
        precondition(namespace == "services.lab", "The Services lab namespace is fixed")
        self.service = service
        self.catalog = catalog
        self.namespace = namespace
    }

    func settings() async -> LocalNotificationSettings {
        await service.settings()
    }

    func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        guard !options.isEmpty,
              options.subtracting(.allowed).isEmpty else {
            throw LocalNotificationServiceError.invalidAuthorizationOptions
        }
        return try await service.requestAuthorization(options)
    }

    func replaceLabCategories(
        _ categories: [LocalNotificationCategory]
    ) async throws {
        guard categories.allSatisfy({ isLabID($0.id.value) }) else {
            throw LocalNotificationServiceError.invalidIdentifier(.category)
        }
        try await catalog.replaceLabCategories(categories)
    }

    func resetLabCategories() async throws {
        try await catalog.resetLabCategories()
    }

    func scheduleLab(_ request: LocalNotificationRequest) async throws {
        guard isLabID(request.id.value) else {
            throw LocalNotificationServiceError.invalidIdentifier(.request)
        }
        if let categoryID = request.content.categoryID,
           !isLabID(categoryID.value) {
            throw LocalNotificationServiceError.invalidIdentifier(.category)
        }
        try await service.schedule(request)
    }

    func pendingLab() async -> [LocalNotificationPendingSnapshot] {
        await service.pending().filter { isLabID($0.id.value) }
    }

    func deliveredLab() async -> [LocalNotificationDeliveredSnapshot] {
        await service.delivered().filter { isLabID($0.id.value) }
    }

    func removeLabPending(_ ids: Set<LocalNotificationID>) async {
        guard !ids.isEmpty,
              ids.allSatisfy({ isLabID($0.value) }) else { return }
        await service.removePending(ids)
    }

    func removeLabDelivered(_ ids: Set<LocalNotificationID>) async {
        guard !ids.isEmpty,
              ids.allSatisfy({ isLabID($0.value) }) else { return }
        await service.removeDelivered(ids)
    }

    func resetLabData() async throws {
        try await catalog.resetLabCategories()
        let pendingIDs = Set(await pendingLab().map(\.id))
        if !pendingIDs.isEmpty { await service.removePending(pendingIDs) }
        let deliveredIDs = Set(await deliveredLab().map(\.id))
        if !deliveredIDs.isEmpty { await service.removeDelivered(deliveredIDs) }
    }

    func pendingAppOwned() async -> [LocalNotificationPendingSnapshot] {
        await service.pending()
    }

    func deliveredAppOwned() async -> [LocalNotificationDeliveredSnapshot] {
        await service.delivered()
    }

    func removeAllPending() async {
        await service.removeAllPending()
    }

    func removeAllDelivered() async {
        await service.removeAllDelivered()
    }

    func setBadgeCount(_ count: Int) async throws {
        try await service.setBadgeCount(count)
    }

    func clearBadge() async throws {
        try await service.clearBadge()
    }

    private func isLabID(_ value: String) -> Bool {
        value == namespace || value.hasPrefix(namespace + ".")
    }
}
