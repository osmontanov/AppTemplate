import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct ServicesNotificationLabTests {
    @Test
    func labFacadePreservesStoreCategoryAndFiltersAllListsToItsNamespace() async throws {
        let service = NotificationLabServiceSpy(
            pending: [pending("store.reminder"), pending("services.lab"), pending("services.lab.interval")],
            delivered: [delivered("foreign"), delivered("services.lab.delivered")]
        )
        let catalog = NotificationLabCatalogSpy(categories: [category("store.product-reminder")])
        let lab = LocalNotificationLabService(service: service, catalog: catalog, namespace: "services.lab")

        try await lab.replaceLabCategories([category("services.lab")])
        #expect(await catalog.categories().map(\.id.value) == ["store.product-reminder", "services.lab"])
        #expect(await lab.pendingLab().map(\.id.value) == ["services.lab", "services.lab.interval"])
        #expect(await lab.deliveredLab().map(\.id.value) == ["services.lab.delivered"])
    }

    @Test
    func facadeRejectsForeignCategoryRequestAndRemovalIDsBeforeAnyDependencyCall() async throws {
        let service = NotificationLabServiceSpy()
        let catalog = NotificationLabCatalogSpy()
        let lab = LocalNotificationLabService(service: service, catalog: catalog, namespace: "services.lab")

        await #expect(throws: LocalNotificationServiceError.invalidIdentifier(.category)) {
            try await lab.replaceLabCategories([category("store.product-reminder")])
        }
        await #expect(throws: LocalNotificationServiceError.invalidIdentifier(.request)) {
            try await lab.scheduleLab(request("store.request"))
        }
        await lab.removeLabPending([try LocalNotificationID("store.request")])
        await lab.removeLabDelivered([try LocalNotificationID("foreign")])

        #expect(await catalog.calls.isEmpty)
        #expect(await service.calls.isEmpty)
    }

    @Test
    func authorizationForwardsEveryKnownNonemptyBitPatternUnchanged() async throws {
        for raw in UInt(1)...15 {
            let service = NotificationLabServiceSpy()
            let lab = LocalNotificationLabService(
                service: service,
                catalog: NotificationLabCatalogSpy(),
                namespace: "services.lab"
            )
            _ = try await lab.requestAuthorization(.init(rawValue: raw))
            #expect(await service.calls == [.authorization(raw)])
        }
    }

    @Test
    func authorizationRejectsEmptyUnknownAndMixedBitsBeforeTheRawService() async {
        for raw in [UInt(0), 16, 17, UInt.max] {
            let service = NotificationLabServiceSpy()
            let lab = LocalNotificationLabService(
                service: service,
                catalog: NotificationLabCatalogSpy(),
                namespace: "services.lab"
            )
            await #expect(throws: LocalNotificationServiceError.invalidAuthorizationOptions) {
                try await lab.requestAuthorization(.init(rawValue: raw))
            }
            #expect(await service.calls.isEmpty)
        }
    }

    @Test
    func resetFailureLeavesRequestsAndSuccessRemovesOnlyLabIDsAfterCategoryReset() async throws {
        let service = NotificationLabServiceSpy(
            pending: [pending("store.pending"), pending("services.lab.pending")],
            delivered: [delivered("store.delivered"), delivered("services.lab.delivered")]
        )
        let catalog = NotificationLabCatalogSpy(shouldFailReset: true)
        let lab = LocalNotificationLabService(service: service, catalog: catalog, namespace: "services.lab")

        await #expect(throws: NotificationLabFixtureError.injected) {
            try await lab.resetLabData()
        }
        #expect(await service.calls.isEmpty)

        await catalog.setShouldFailReset(false)
        try await lab.resetLabData()
        #expect(await catalog.calls == [.reset, .reset])
        #expect(await service.calls == [
            .pending,
            .removePending([try LocalNotificationID("services.lab.pending")]),
            .delivered,
            .removeDelivered([try LocalNotificationID("services.lab.delivered")])
        ])
    }

    @Test
    func appWideCapabilitiesListsStoreAndLabButExposesOnlyWholeRemovalAndBadge() async throws {
        let service = NotificationLabServiceSpy(
            pending: [pending("store.pending"), pending("services.lab.pending")],
            delivered: [delivered("store.delivered"), delivered("services.lab.delivered")]
        )
        let concrete = LocalNotificationLabService(
            service: service,
            catalog: NotificationLabCatalogSpy(),
            namespace: "services.lab"
        )
        let appWide: any ILocalNotificationAppWideCapabilities = concrete

        #expect(await appWide.pendingAppOwned().map(\.id.value) == ["store.pending", "services.lab.pending"])
        #expect(await appWide.deliveredAppOwned().map(\.id.value) == ["store.delivered", "services.lab.delivered"])
        await appWide.removeAllPending()
        await appWide.removeAllDelivered()
        try await appWide.setBadgeCount(7)
        try await appWide.clearBadge()

        #expect(await service.calls == [
            .pending, .delivered, .removeAllPending, .removeAllDelivered, .setBadge(7), .clearBadge
        ])
    }

    @Test
    func viewModelRoutesTheFullOperationMatrixToSeparateFacades() async throws {
        let lab = NotificationLabFacadeSpy()
        let appWide = NotificationAppWideSpy()
        let history = LocalNotificationEventHistory(clock: fixedClock)
        let model = LocalNotificationLabViewModel(
            lab: lab,
            appWide: appWide,
            history: history,
            assets: injectedAssetProvider
        )
        let labCategory = category("services.lab")
        let labRequest = request("services.lab.immediate")
        let selectedPending: Set = [try LocalNotificationID("services.lab.pending")]
        let selectedDelivered: Set = [try LocalNotificationID("services.lab.delivered")]

        await model.refreshSettings()
        await model.refreshLabLists()
        await model.refreshAppOwnedLists()
        model.setAuthorizationOption(.alert, enabled: true)
        model.setAuthorizationOption(.sound, enabled: true)
        await model.requestSelectedAuthorization()
        await model.replaceLabCategories([labCategory])
        await model.resetLabCategories()
        await model.scheduleLab(labRequest)
        await model.removeSelectedPending(selectedPending)
        await model.removeSelectedDelivered(selectedDelivered)
        await model.resetLabData()
        await model.removeAllAppOwnedPendingConfirmed()
        await model.removeAllAppOwnedDeliveredConfirmed()
        await model.setBadgeCount(3)
        await model.clearBadge()

        let labCalls = await lab.calls
        let hydrationLabCalls = Array(labCalls.prefix(3))
        #expect(hydrationLabCalls.count == 3)
        #expect(hydrationLabCalls.filter { $0 == .settings }.count == 1)
        #expect(hydrationLabCalls.filter { $0 == .pending }.count == 1)
        #expect(hydrationLabCalls.filter { $0 == .delivered }.count == 1)
        #expect(Array(labCalls.dropFirst(3)) == [
            .authorization(3),
            .replaceCategories([labCategory]), .resetCategories, .schedule(labRequest),
            .removePending(selectedPending), .removeDelivered(selectedDelivered), .resetData
        ])
        let appWideCalls = await appWide.calls
        let hydrationAppWideCalls = Array(appWideCalls.prefix(2))
        #expect(hydrationAppWideCalls.count == 2)
        #expect(hydrationAppWideCalls.filter { $0 == .pending }.count == 1)
        #expect(hydrationAppWideCalls.filter { $0 == .delivered }.count == 1)
        #expect(Array(appWideCalls.dropFirst(2)) == [
            .removeAllPending, .removeAllDelivered, .setBadge(3), .clearBadge
        ])
        #expect(model.authorizationOptions.rawValue == 3)
        #expect(try model.attachmentURL(.image).lastPathComponent == "image.png")
        #expect(try model.notificationSoundName() == "notification-demo.aiff")
    }

    @Test
    func initialStateLoadPopulatesSnapshotsWithoutPublishingAUserActionResult() async {
        let lab = NotificationLabFacadeSpy()
        let appWide = NotificationAppWideSpy()
        let model = LocalNotificationLabViewModel(
            lab: lab,
            appWide: appWide,
            history: LocalNotificationEventHistory(clock: fixedClock),
            assets: injectedAssetProvider
        )

        await model.loadInitialState()

        #expect(model.settings == .inMemoryDefault)
        #expect(model.pendingLab.isEmpty)
        #expect(model.deliveredLab.isEmpty)
        #expect(model.pendingAppOwned.isEmpty)
        #expect(model.deliveredAppOwned.isEmpty)
        #expect(model.actualResult == .idle)
        let labCalls = await lab.calls
        #expect(labCalls.count == 3)
        #expect(labCalls.filter { $0 == .settings }.count == 1)
        #expect(labCalls.filter { $0 == .pending }.count == 1)
        #expect(labCalls.filter { $0 == .delivered }.count == 1)
        let appWideCalls = await appWide.calls
        #expect(appWideCalls.count == 2)
        #expect(appWideCalls.filter { $0 == .pending }.count == 1)
        #expect(appWideCalls.filter { $0 == .delivered }.count == 1)

        await model.refreshSettings()
        #expect(model.actualResult == .success("Refreshed notification settings."))
    }

    @Test
    func initialHydrationWaitsForAnInFlightResetBeforeRetryingACompleteSnapshot() async {
        let stalePending = pending("services.lab.stale")
        let staleDelivered = delivered("services.lab.stale")
        let freshAppPending = pending("store.pending.fresh")
        let freshAppDelivered = delivered("store.delivered.fresh")
        let lab = DeferredInitialNotificationLabSpy(
            stalePending: stalePending,
            staleDelivered: staleDelivered
        )
        let appWide = RetryingInitialNotificationAppWideSpy(
            freshPending: freshAppPending,
            freshDelivered: freshAppDelivered
        )
        let model = LocalNotificationLabViewModel(
            lab: lab,
            appWide: appWide,
            history: LocalNotificationEventHistory(clock: fixedClock),
            assets: injectedAssetProvider
        )
        let hydration = Task { await model.loadInitialState() }
        await lab.waitForPendingRequest()

        let reset = Task { await model.resetLabData() }
        await lab.waitForResetRequest()
        await lab.resumePendingRequest()
        for _ in 0..<1_000 {
            if await lab.snapshotRequestCounts[1] > 1 { break }
            await Task.yield()
        }
        let pendingRequestsBeforeResetCompleted = await lab.snapshotRequestCounts[1]
        for _ in 0..<1_000 {
            if model.pendingLab == [stalePending] { break }
            await Task.yield()
        }
        let staleSnapshotCommittedBeforeResetCompleted = model.pendingLab == [stalePending]
        await lab.resumeResetRequest()
        await reset.value
        await hydration.value

        #expect(pendingRequestsBeforeResetCompleted == 1)
        #expect(!staleSnapshotCommittedBeforeResetCompleted)
        #expect(model.settings == .inMemoryDefault)
        #expect(model.pendingLab.isEmpty)
        #expect(model.deliveredLab.isEmpty)
        #expect(model.pendingAppOwned.map(\.id) == [freshAppPending.id])
        #expect(model.deliveredAppOwned.map(\.id) == [freshAppDelivered.id])
        #expect(model.actualResult == .success("Reset only Services lab categories and notifications."))
        #expect(await lab.snapshotRequestCounts == [2, 2, 2])
        #expect(await appWide.snapshotRequestCounts == [2, 2])
    }

    @Test
    func viewModelFourIndependentTogglesNeverAutoAddAndEmptyRequestFailsWithoutCall() async {
        let lab = NotificationLabFacadeSpy()
        let model = LocalNotificationLabViewModel(
            lab: lab,
            appWide: NotificationAppWideSpy(),
            history: LocalNotificationEventHistory(clock: fixedClock),
            assets: injectedAssetProvider
        )

        await model.requestSelectedAuthorization()
        #expect(await lab.calls.isEmpty)
        #expect(model.actualResult == .failure("Select at least one valid authorization option."))

        for option in [
            LocalNotificationAuthorizationOptions.alert,
            .sound, .badge, .provisional
        ] {
            model.setAuthorizationOption(option, enabled: true)
        }
        #expect(model.authorizationOptions.rawValue == 15)
        model.setAuthorizationOption(.sound, enabled: false)
        #expect(model.authorizationOptions.rawValue == 13)
    }

    @Test
    func lateSubscriberReplaysStartsOnceStopsAndClearUsesTheSoleHistory() async {
        let history = LocalNotificationEventHistory(clock: fixedClock)
        await history.append(fixtureEvent)
        let model = LocalNotificationLabViewModel(
            lab: NotificationLabFacadeSpy(),
            appWide: NotificationAppWideSpy(),
            history: history,
            assets: injectedAssetProvider
        )

        await model.startEventUpdates()
        #expect(model.eventRecords.count == 1)
        #expect(await history.activeSubscriptionCount == 1)
        await model.startEventUpdates()
        #expect(await history.activeSubscriptionCount == 1)

        await history.append(fixtureEvent)
        for _ in 0..<1_000 {
            if model.eventRecords.count == 2 { break }
            await Task.yield()
        }
        await model.stopEventUpdates()
        await history.waitUntilSubscriptionCountForTesting(0)
        await history.append(fixtureEvent)
        #expect(model.eventRecords.count == 2)

        await model.clearEventHistory()
        #expect(model.eventRecords.isEmpty)
        #expect(await history.records().isEmpty)
    }

    @Test
    func servicesBasicScriptExhaustsOnlyAfterItsExactOrderedMutations() async throws {
        let lab = NotificationLabFacadeSpy()
        let appWide = NotificationAppWideSpy()
        let tracker = UITestScriptConsumptionTracker(
            networkSteps: 0,
            imageSteps: 0,
            notificationSteps: 2
        )
        let scripted = ScriptedLocalNotificationLabService(
            lab: lab,
            appWide: appWide,
            steps: [.schedule("services.lab.immediate"), .resetLabData],
            tracker: tracker
        )
        var updates = await tracker.updates().makeAsyncIterator()
        #expect(await updates.next() == .pending)

        try await scripted.scheduleLab(request("services.lab.immediate"))
        #expect(await updates.next() == .pending)
        try await scripted.resetLabData()
        #expect(await updates.next() == .exhausted)

        await #expect(throws: LocalNotificationServiceError.self) {
            try await scripted.scheduleLab(request("services.lab.unexpected"))
        }
        #expect(await updates.next() == .failed)
    }

    private var fixedClock: AppClock {
        AppClock(
            now: { Date(timeIntervalSince1970: 1) },
            monotonicNow: { ContinuousClock().now },
            sleep: { _ in try Task.checkCancellation() }
        )
    }

    private var fixtureEvent: LocalNotificationEvent {
        .diagnostic(.init(id: nil, reason: .unrecognizedAction))
    }

    private var injectedAssetProvider: LocalNotificationLabAssetProvider {
        LocalNotificationLabAssetProvider(
            resolve: { resource in
                switch resource {
                case .attachment(.image): URL(fileURLWithPath: "/fixture/image.png")
                case .attachment(.audio), .sound: URL(fileURLWithPath: "/fixture/notification-demo.aiff")
                case .attachment(.video): URL(fileURLWithPath: "/fixture/video.mov")
                }
            },
            validate: { _ in .valid }
        )
    }
}

private nonisolated func category(_ id: String) -> LocalNotificationCategory {
    LocalNotificationCategory(id: try! LocalNotificationCategoryID(id))
}

private nonisolated func request(_ id: String) -> LocalNotificationRequest {
    LocalNotificationRequest(
        id: try! LocalNotificationID(id),
        content: LocalNotificationContent(title: "Lab", body: "Safe"),
        trigger: .immediate
    )
}

private nonisolated func pending(_ id: String) -> LocalNotificationPendingSnapshot {
    let value = request(id)
    return LocalNotificationPendingSnapshot(
        id: value.id,
        payload: .decoded(LocalNotificationStoredRequest(
            id: value.id,
            content: LocalNotificationStoredContent(title: "Fixture"),
            trigger: .immediate
        )),
        nextTriggerDate: nil
    )
}

private nonisolated func delivered(_ id: String) -> LocalNotificationDeliveredSnapshot {
    let value = request(id)
    return LocalNotificationDeliveredSnapshot(
        id: value.id,
        payload: .decoded(LocalNotificationStoredRequest(
            id: value.id,
            content: LocalNotificationStoredContent(title: "Fixture"),
            trigger: .immediate
        )),
        deliveredAt: Date(timeIntervalSince1970: 1)
    )
}

private nonisolated enum NotificationLabFixtureError: Error { case injected }

private nonisolated enum NotificationRawCall: Equatable, Sendable {
    case settings
    case authorization(UInt)
    case pending
    case delivered
    case removePending(Set<LocalNotificationID>)
    case removeDelivered(Set<LocalNotificationID>)
    case removeAllPending
    case removeAllDelivered
    case setBadge(Int)
    case clearBadge
    case schedule(LocalNotificationRequest)
}

private actor NotificationLabServiceSpy: ILocalNotificationService {
    private(set) var calls: [NotificationRawCall] = []
    private let pendingValues: [LocalNotificationPendingSnapshot]
    private let deliveredValues: [LocalNotificationDeliveredSnapshot]

    init(
        pending: [LocalNotificationPendingSnapshot] = [],
        delivered: [LocalNotificationDeliveredSnapshot] = []
    ) {
        pendingValues = pending
        deliveredValues = delivered
    }

    func settings() -> LocalNotificationSettings {
        calls.append(.settings)
        return .inMemoryDefault
    }
    func requestAuthorization(_ options: LocalNotificationAuthorizationOptions) throws -> Bool {
        calls.append(.authorization(options.rawValue)); return true
    }
    func setCategories(_ categories: [LocalNotificationCategory]) throws { _ = categories }
    func schedule(_ request: LocalNotificationRequest) throws { calls.append(.schedule(request)) }
    func pending() -> [LocalNotificationPendingSnapshot] { calls.append(.pending); return pendingValues }
    func delivered() -> [LocalNotificationDeliveredSnapshot] { calls.append(.delivered); return deliveredValues }
    func removePending(_ identifiers: Set<LocalNotificationID>) { calls.append(.removePending(identifiers)) }
    func removeAllPending() { calls.append(.removeAllPending) }
    func removeDelivered(_ identifiers: Set<LocalNotificationID>) { calls.append(.removeDelivered(identifiers)) }
    func removeAllDelivered() { calls.append(.removeAllDelivered) }
    func setBadgeCount(_ count: Int) throws { calls.append(.setBadge(count)) }
    func clearBadge() throws { calls.append(.clearBadge) }
    func events() -> AsyncStream<LocalNotificationEvent> { AsyncStream { $0.finish() } }
}

private nonisolated enum NotificationCatalogCall: Equatable, Sendable {
    case replace([LocalNotificationCategory])
    case reset
}

private actor NotificationLabCatalogSpy: IAppNotificationCategoryCatalog {
    private(set) var calls: [NotificationCatalogCall] = []
    private var storedCategories: [LocalNotificationCategory]
    private var shouldFailReset: Bool

    init(categories: [LocalNotificationCategory] = [], shouldFailReset: Bool = false) {
        storedCategories = categories
        self.shouldFailReset = shouldFailReset
    }
    func categories() -> [LocalNotificationCategory] { storedCategories }
    func bootstrapIfNeeded() throws {}
    func replaceLabCategories(_ categories: [LocalNotificationCategory]) throws {
        calls.append(.replace(categories))
        storedCategories = storedCategories.filter { $0.id.value.hasPrefix("store.") } + categories
    }
    func resetLabCategories() throws {
        calls.append(.reset)
        if shouldFailReset { throw NotificationLabFixtureError.injected }
        storedCategories.removeAll { !$0.id.value.hasPrefix("store.") }
    }
    func setShouldFailReset(_ value: Bool) { shouldFailReset = value }
}

private nonisolated enum NotificationLabFacadeCall: Equatable, Sendable {
    case settings
    case authorization(UInt)
    case replaceCategories([LocalNotificationCategory])
    case resetCategories
    case schedule(LocalNotificationRequest)
    case pending
    case delivered
    case removePending(Set<LocalNotificationID>)
    case removeDelivered(Set<LocalNotificationID>)
    case resetData
}

private actor NotificationLabFacadeSpy: ILocalNotificationLabService {
    private(set) var calls: [NotificationLabFacadeCall] = []
    func settings() -> LocalNotificationSettings { calls.append(.settings); return .inMemoryDefault }
    func requestAuthorization(_ options: LocalNotificationAuthorizationOptions) -> Bool { calls.append(.authorization(options.rawValue)); return true }
    func replaceLabCategories(_ categories: [LocalNotificationCategory]) { calls.append(.replaceCategories(categories)) }
    func resetLabCategories() { calls.append(.resetCategories) }
    func scheduleLab(_ request: LocalNotificationRequest) { calls.append(.schedule(request)) }
    func pendingLab() -> [LocalNotificationPendingSnapshot] { calls.append(.pending); return [] }
    func deliveredLab() -> [LocalNotificationDeliveredSnapshot] { calls.append(.delivered); return [] }
    func removeLabPending(_ ids: Set<LocalNotificationID>) { calls.append(.removePending(ids)) }
    func removeLabDelivered(_ ids: Set<LocalNotificationID>) { calls.append(.removeDelivered(ids)) }
    func resetLabData() { calls.append(.resetData) }
}

private actor DeferredInitialNotificationLabSpy: ILocalNotificationLabService {
    private let stalePending: LocalNotificationPendingSnapshot
    private let staleDelivered: LocalNotificationDeliveredSnapshot
    private var pendingContinuation: CheckedContinuation<[LocalNotificationPendingSnapshot], Never>?
    private var pendingWaiters: [CheckedContinuation<Void, Never>] = []
    private var resetContinuation: CheckedContinuation<Void, Never>?
    private var resetWaiters: [CheckedContinuation<Void, Never>] = []
    private var resetIsInFlight = false
    private var settingsRequestCount = 0
    private var pendingRequestCount = 0
    private var deliveredRequestCount = 0

    init(
        stalePending: LocalNotificationPendingSnapshot,
        staleDelivered: LocalNotificationDeliveredSnapshot
    ) {
        self.stalePending = stalePending
        self.staleDelivered = staleDelivered
    }

    func settings() -> LocalNotificationSettings {
        settingsRequestCount += 1
        return .inMemoryDefault
    }
    func requestAuthorization(_ options: LocalNotificationAuthorizationOptions) -> Bool { true }
    func replaceLabCategories(_ categories: [LocalNotificationCategory]) {}
    func resetLabCategories() {}
    func scheduleLab(_ request: LocalNotificationRequest) {}
    func pendingLab() async -> [LocalNotificationPendingSnapshot] {
        pendingRequestCount += 1
        guard pendingRequestCount == 1 else {
            return resetIsInFlight ? [stalePending] : []
        }
        pendingWaiters.forEach { $0.resume() }
        pendingWaiters.removeAll()
        return await withCheckedContinuation { pendingContinuation = $0 }
    }
    func deliveredLab() -> [LocalNotificationDeliveredSnapshot] {
        deliveredRequestCount += 1
        return deliveredRequestCount == 1 ? [staleDelivered] : []
    }
    func removeLabPending(_ ids: Set<LocalNotificationID>) {}
    func removeLabDelivered(_ ids: Set<LocalNotificationID>) {}
    func resetLabData() async {
        resetIsInFlight = true
        resetWaiters.forEach { $0.resume() }
        resetWaiters.removeAll()
        await withCheckedContinuation { resetContinuation = $0 }
        resetIsInFlight = false
    }

    func waitForPendingRequest() async {
        guard pendingContinuation == nil else { return }
        await withCheckedContinuation { pendingWaiters.append($0) }
    }

    func resumePendingRequest() {
        guard let pendingContinuation else { return }
        self.pendingContinuation = nil
        pendingContinuation.resume(returning: [stalePending])
    }

    func waitForResetRequest() async {
        guard !resetIsInFlight else { return }
        await withCheckedContinuation { resetWaiters.append($0) }
    }

    func resumeResetRequest() {
        guard let resetContinuation else { return }
        self.resetContinuation = nil
        resetContinuation.resume()
    }

    var snapshotRequestCounts: [Int] {
        [settingsRequestCount, pendingRequestCount, deliveredRequestCount]
    }
}

private actor RetryingInitialNotificationAppWideSpy: ILocalNotificationAppWideCapabilities {
    private let freshPending: LocalNotificationPendingSnapshot
    private let freshDelivered: LocalNotificationDeliveredSnapshot
    private var pendingRequestCount = 0
    private var deliveredRequestCount = 0

    init(
        freshPending: LocalNotificationPendingSnapshot,
        freshDelivered: LocalNotificationDeliveredSnapshot
    ) {
        self.freshPending = freshPending
        self.freshDelivered = freshDelivered
    }

    func pendingAppOwned() -> [LocalNotificationPendingSnapshot] {
        pendingRequestCount += 1
        return pendingRequestCount == 1 ? [pending("store.pending.stale")] : [freshPending]
    }

    func deliveredAppOwned() -> [LocalNotificationDeliveredSnapshot] {
        deliveredRequestCount += 1
        return deliveredRequestCount == 1 ? [delivered("store.delivered.stale")] : [freshDelivered]
    }

    func removeAllPending() {}
    func removeAllDelivered() {}
    func setBadgeCount(_ count: Int) {}
    func clearBadge() {}

    var snapshotRequestCounts: [Int] {
        [pendingRequestCount, deliveredRequestCount]
    }
}

private nonisolated enum NotificationAppWideCall: Equatable, Sendable {
    case pending, delivered, removeAllPending, removeAllDelivered, setBadge(Int), clearBadge
}

private actor NotificationAppWideSpy: ILocalNotificationAppWideCapabilities {
    private(set) var calls: [NotificationAppWideCall] = []
    func pendingAppOwned() -> [LocalNotificationPendingSnapshot] { calls.append(.pending); return [] }
    func deliveredAppOwned() -> [LocalNotificationDeliveredSnapshot] { calls.append(.delivered); return [] }
    func removeAllPending() { calls.append(.removeAllPending) }
    func removeAllDelivered() { calls.append(.removeAllDelivered) }
    func setBadgeCount(_ count: Int) { calls.append(.setBadge(count)) }
    func clearBadge() { calls.append(.clearBadge) }
}
