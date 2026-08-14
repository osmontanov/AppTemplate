import Foundation
import Observation

@MainActor
@Observable
final class LocalNotificationLabViewModel {
    private let lab: any ILocalNotificationLabService
    private let appWide: any ILocalNotificationAppWideCapabilities
    private let history: any ILocalNotificationEventReading
    private let assets: LocalNotificationLabAssetProvider
    private var eventTask: Task<Void, Never>?

    private(set) var settings: LocalNotificationSettings?
    private(set) var pendingLab: [LocalNotificationPendingSnapshot] = []
    private(set) var deliveredLab: [LocalNotificationDeliveredSnapshot] = []
    private(set) var pendingAppOwned: [LocalNotificationPendingSnapshot] = []
    private(set) var deliveredAppOwned: [LocalNotificationDeliveredSnapshot] = []
    private(set) var authorizationOptions: LocalNotificationAuthorizationOptions = []
    private(set) var eventRecords: [LocalNotificationEventRecord] = []
    private(set) var actualResult: ServiceLabResult = .idle

    init(
        lab: any ILocalNotificationLabService,
        appWide: any ILocalNotificationAppWideCapabilities,
        history: any ILocalNotificationEventReading,
        assets: LocalNotificationLabAssetProvider
    ) {
        self.lab = lab
        self.appWide = appWide
        self.history = history
        self.assets = assets
    }

    func setAuthorizationOption(
        _ option: LocalNotificationAuthorizationOptions,
        enabled: Bool
    ) {
        guard !option.isEmpty,
              option.subtracting(.allowed).isEmpty,
              option.rawValue.nonzeroBitCount == 1 else { return }
        if enabled {
            authorizationOptions.formUnion(option)
        } else {
            authorizationOptions.subtract(option)
        }
    }

    func refreshSettings() async {
        settings = await lab.settings()
        actualResult = .success(StoreServicesText.string("Refreshed notification settings."))
    }

    func refreshLabLists() async {
        async let pending = lab.pendingLab()
        async let delivered = lab.deliveredLab()
        pendingLab = await pending
        deliveredLab = await delivered
        actualResult = .success(StoreServicesText.string("Refreshed lab-only notifications."))
    }

    func refreshAppOwnedLists() async {
        async let pending = appWide.pendingAppOwned()
        async let delivered = appWide.deliveredAppOwned()
        pendingAppOwned = await pending
        deliveredAppOwned = await delivered
        actualResult = .success(StoreServicesText.string("Refreshed app-wide Store and lab notifications."))
    }

    func requestSelectedAuthorization() async {
        guard !authorizationOptions.isEmpty,
              authorizationOptions.subtracting(.allowed).isEmpty else {
            actualResult = .failure(StoreServicesText.string("Select at least one valid authorization option."))
            return
        }
        await perform(StoreServicesText.string("Requested exactly the selected authorization options.")) {
            _ = try await self.lab.requestAuthorization(self.authorizationOptions)
        }
    }

    func replaceLabCategories(_ categories: [LocalNotificationCategory]) async {
        await perform(StoreServicesText.string("Replaced the Services lab category set.")) {
            try await self.lab.replaceLabCategories(categories)
        }
    }

    func resetLabCategories() async {
        await perform(StoreServicesText.string("Reset only the Services lab categories.")) {
            try await self.lab.resetLabCategories()
        }
    }

    func scheduleLab(_ request: LocalNotificationRequest) async {
        await perform(StoreServicesText.string("Scheduled a Services lab notification.")) {
            try await self.lab.scheduleLab(request)
        }
    }

    func removeSelectedPending(_ ids: Set<LocalNotificationID>) async {
        await lab.removeLabPending(ids)
        pendingLab.removeAll { ids.contains($0.id) }
        actualResult = .success(StoreServicesText.string("Removed selected lab-only pending notifications."))
    }

    func removeSelectedDelivered(_ ids: Set<LocalNotificationID>) async {
        await lab.removeLabDelivered(ids)
        deliveredLab.removeAll { ids.contains($0.id) }
        actualResult = .success(StoreServicesText.string("Removed selected lab-only delivered notifications."))
    }

    func resetLabData() async {
        await perform(StoreServicesText.string("Reset only Services lab categories and notifications.")) {
            try await self.lab.resetLabData()
            self.pendingLab = []
            self.deliveredLab = []
        }
    }

    func removeAllAppOwnedPendingConfirmed() async {
        await appWide.removeAllPending()
        pendingAppOwned = []
        pendingLab = []
        actualResult = .success(StoreServicesText.string("Removed all app-owned pending notifications after confirmation."))
    }

    func removeAllAppOwnedDeliveredConfirmed() async {
        await appWide.removeAllDelivered()
        deliveredAppOwned = []
        deliveredLab = []
        actualResult = .success(StoreServicesText.string("Removed all app-owned delivered notifications after confirmation."))
    }

    func setBadgeCount(_ count: Int) async {
        await perform(StoreServicesText.string("Set the app badge count.")) {
            try await self.appWide.setBadgeCount(count)
        }
    }

    func clearBadge() async {
        await perform(StoreServicesText.string("Cleared the app badge.")) {
            try await self.appWide.clearBadge()
        }
    }

    func attachmentURL(_ asset: LocalNotificationLabAsset) throws -> URL {
        try assets.attachmentURL(asset)
    }

    func notificationSoundName() throws -> String {
        try assets.notificationSoundName()
    }

    func startEventUpdates() async {
        guard eventTask == nil else { return }
        let stream = await history.updates()
        let ready = AsyncOneShotSignal<Void>()
        eventTask = Task { @MainActor [weak self] in
            var didSignalReady = false
            for await records in stream {
                guard !Task.isCancelled else { break }
                self?.eventRecords = records
                if !didSignalReady {
                    didSignalReady = true
                    _ = await ready.resolve(())
                }
            }
            if !didSignalReady { _ = await ready.resolve(()) }
        }
        await ready.wait()
    }

    func stopEventUpdates() async {
        let task = eventTask
        eventTask = nil
        task?.cancel()
        await task?.value
    }

    func clearEventHistory() async {
        await history.clear()
        eventRecords = []
        actualResult = .success(StoreServicesText.string("Cleared the shared safe notification history."))
    }

    private func perform(
        _ successMessage: String,
        operation: () async throws -> Void
    ) async {
        actualResult = .running
        do {
            try await operation()
            actualResult = .success(successMessage)
        } catch is CancellationError {
            actualResult = .idle
        } catch {
            actualResult = .failure(Self.safeMessage(for: error))
        }
    }

    private static func safeMessage(for error: Error) -> String {
        switch error {
        case is LocalNotificationServiceError:
            StoreServicesText.string("The notification operation was rejected safely.")
        case is LocalNotificationLabAssetError:
            StoreServicesText.string("The bundled notification demo asset is unavailable.")
        default:
            StoreServicesText.string("The notification lab operation could not complete.")
        }
    }
}
