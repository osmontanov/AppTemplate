import Foundation
import Testing
@testable import AppTemplate

struct AppNotificationCategoryCatalogTests {
    @Test
    func initialLogicalCatalogContainsOnlyTheImmutableStoreCategory() async throws {
        let store = try category(id: "store")
        let service = CategoryCatalogNotificationServiceSpy()
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: AsyncOperationGate()
        )

        #expect(await catalog.categories() == [store])
        #expect(await service.categoryWrites.isEmpty)
    }

    @Test
    func replacementKeepsStoreFirstAndSortsOnlyLabCategoriesByID() async throws {
        let store = try category(id: "store")
        let actionA = LocalNotificationAction.button(
            LocalNotificationButtonAction(
                id: try LocalNotificationActionID("action-a"),
                title: "A"
            )
        )
        let actionB = LocalNotificationAction.button(
            LocalNotificationButtonAction(
                id: try LocalNotificationActionID("action-b"),
                title: "B"
            )
        )
        let labZ = try category(id: "lab-z", actions: [actionB, actionA])
        let labA = try category(id: "lab-a")
        let service = CategoryCatalogNotificationServiceSpy()
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: AsyncOperationGate()
        )

        try await catalog.replaceLabCategories([labZ, labA])

        let expected = [store, labA, labZ]
        #expect(await catalog.categories() == expected)
        #expect(await service.categoryWrites == [expected])
        #expect(await service.physicalCategories == expected)
        #expect(await service.unexpectedOperations.isEmpty)
    }

    @Test
    func duplicateLabIDsAreRejectedBeforeTheServiceCall() async throws {
        let store = try category(id: "store")
        let duplicate = try category(id: "duplicate")
        let service = CategoryCatalogNotificationServiceSpy()
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: AsyncOperationGate()
        )

        await #expect(
            throws: LocalNotificationServiceError.invalidCategory(.duplicateCategoryID)
        ) {
            try await catalog.replaceLabCategories([duplicate, duplicate])
        }

        #expect(await catalog.categories() == [store])
        #expect(await service.categoryWrites.isEmpty)
    }

    @Test
    func storeIDIsReservedFromLabReplacementBeforeTheServiceCall() async throws {
        let store = try category(id: "store")
        let reserved = LocalNotificationCategory(
            id: store.id,
            actions: [],
            reportsDismissal: true
        )
        let service = CategoryCatalogNotificationServiceSpy()
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: AsyncOperationGate()
        )

        await #expect(
            throws: LocalNotificationServiceError.invalidCategory(.duplicateCategoryID)
        ) {
            try await catalog.replaceLabCategories([reserved])
        }

        #expect(await catalog.categories() == [store])
        #expect(await service.categoryWrites.isEmpty)
    }

    @Test
    func bootstrapIsIdempotentAfterItsFirstSuccessfulPhysicalWrite() async throws {
        let store = try category(id: "store")
        let service = CategoryCatalogNotificationServiceSpy()
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: AsyncOperationGate()
        )

        try await catalog.bootstrapIfNeeded()
        try await catalog.bootstrapIfNeeded()

        #expect(await service.categoryWrites == [[store]])
        #expect(await catalog.categories() == [store])
        #expect(await service.unexpectedOperations.isEmpty)
    }

    @Test
    func failedBootstrapRemainsRetryable() async throws {
        let store = try category(id: "store")
        let service = CategoryCatalogNotificationServiceSpy(
            steps: [.failure(.write), .success]
        )
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: AsyncOperationGate()
        )

        await #expect(throws: CategoryCatalogTestError.write) {
            try await catalog.bootstrapIfNeeded()
        }
        try await catalog.bootstrapIfNeeded()

        #expect(await service.categoryWrites == [[store], [store]])
        #expect(await service.physicalCategories == [store])
        #expect(await catalog.categories() == [store])
    }

    @Test
    func successfulReplacementBeforeBootstrapMakesLaterBootstrapANoOp() async throws {
        let store = try category(id: "store")
        let lab = try category(id: "lab")
        let service = CategoryCatalogNotificationServiceSpy()
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: AsyncOperationGate()
        )

        try await catalog.replaceLabCategories([lab])
        try await catalog.bootstrapIfNeeded()

        #expect(await service.categoryWrites == [[store, lab]])
        #expect(await catalog.categories() == [store, lab])
    }

    @Test
    func failedAndCancelledReplacementsPreserveTheCommittedUnion() async throws {
        let store = try category(id: "store")
        let first = try category(id: "lab-a")
        let failed = try category(id: "lab-b")
        let cancelled = try category(id: "lab-c")
        let service = CategoryCatalogNotificationServiceSpy(
            steps: [.success, .failure(.write), .cancellation]
        )
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: AsyncOperationGate()
        )
        try await catalog.replaceLabCategories([first])

        await #expect(throws: CategoryCatalogTestError.write) {
            try await catalog.replaceLabCategories([failed])
        }
        await #expect(throws: CancellationError.self) {
            try await catalog.replaceLabCategories([cancelled])
        }

        #expect(await catalog.categories() == [store, first])
        #expect(await service.physicalCategories == [store, first])
    }

    @Test
    func replacementSnapshotStaysCommittedUntilThePhysicalWriteSucceeds() async throws {
        let store = try category(id: "store")
        let lab = try category(id: "lab")
        let barrier = CategoryWriteBarrier()
        let service = CategoryCatalogNotificationServiceSpy(
            steps: [.success, .suspendedSuccess(barrier)]
        )
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: AsyncOperationGate()
        )
        try await catalog.bootstrapIfNeeded()

        let replacement = Task {
            try await catalog.replaceLabCategories([lab])
        }
        await barrier.waitUntilEntered()

        #expect(await catalog.categories() == [store])

        await barrier.release()
        try await replacement.value
        #expect(await catalog.categories() == [store, lab])
    }

    @Test
    func queuedReplaceAndResetRunInFIFOOrder() async throws {
        let store = try category(id: "store")
        let lab = try category(id: "lab")
        let barrier = CategoryWriteBarrier()
        let gate = AsyncOperationGate()
        let service = CategoryCatalogNotificationServiceSpy(
            steps: [.suspendedSuccess(barrier), .success]
        )
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: gate
        )

        let replacement = Task {
            try await catalog.replaceLabCategories([lab])
        }
        await barrier.waitUntilEntered()
        let reset = Task {
            try await catalog.resetLabCategories()
        }
        await gate.waitUntilWaiterCountForTesting(1)

        await barrier.release()
        try await replacement.value
        try await reset.value

        #expect(await service.categoryWrites == [[store, lab], [store]])
        #expect(await catalog.categories() == [store])
    }

    @Test
    func preCancelledAndCancelledQueuedReplacementsNeverReachTheService() async throws {
        let store = try category(id: "store")
        let lab = try category(id: "lab")
        let cancelledLab = try category(id: "cancelled")
        let barrier = CategoryWriteBarrier()
        let gate = AsyncOperationGate()
        let service = CategoryCatalogNotificationServiceSpy(
            steps: [.suspendedSuccess(barrier)]
        )
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: gate
        )

        let preCancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await catalog.replaceLabCategories([cancelledLab])
        }
        await #expect(throws: CancellationError.self) {
            try await preCancelled.value
        }

        let owner = Task {
            try await catalog.replaceLabCategories([lab])
        }
        await barrier.waitUntilEntered()
        let queued = Task {
            try await catalog.replaceLabCategories([cancelledLab])
        }
        await gate.waitUntilWaiterCountForTesting(1)
        queued.cancel()
        await gate.waitUntilWaiterCountForTesting(0)

        await #expect(throws: CancellationError.self) {
            try await queued.value
        }
        await barrier.release()
        try await owner.value

        #expect(await service.categoryWrites == [[store, lab]])
        #expect(await catalog.categories() == [store, lab])
    }

    @Test
    func cancellationAfterSuccessfulPhysicalMutationStillCommitsThatExactCandidate() async throws {
        let store = try category(id: "store")
        let lab = try category(id: "lab")
        let barrier = CategoryWriteBarrier()
        let service = CategoryCatalogNotificationServiceSpy(
            steps: [.suspendedSuccess(barrier)]
        )
        let catalog = AppNotificationCategoryCatalog(
            service: service,
            storeCategory: store,
            gate: AsyncOperationGate()
        )
        let replacement = Task {
            try await catalog.replaceLabCategories([lab])
        }
        await barrier.waitUntilEntered()

        replacement.cancel()
        await barrier.release()
        try await replacement.value

        #expect(await service.physicalCategories == [store, lab])
        #expect(await catalog.categories() == [store, lab])
    }

    private func category(
        id: String,
        actions: [LocalNotificationAction] = []
    ) throws -> LocalNotificationCategory {
        LocalNotificationCategory(
            id: try LocalNotificationCategoryID(id),
            actions: actions
        )
    }
}

private enum CategoryCatalogTestError: Error, Equatable, Sendable {
    case write
    case unexpected(String)
}

private enum CategoryWriteStep: Sendable {
    case success
    case failure(CategoryCatalogTestError)
    case cancellation
    case suspendedSuccess(CategoryWriteBarrier)
}

private actor CategoryCatalogNotificationServiceSpy: ILocalNotificationService {
    private var steps: [CategoryWriteStep]
    private(set) var categoryWrites: [[LocalNotificationCategory]] = []
    private(set) var physicalCategories: [LocalNotificationCategory] = []
    private(set) var unexpectedOperations: [String] = []

    init(steps: [CategoryWriteStep] = []) {
        self.steps = steps
    }

    func settings() async -> LocalNotificationSettings {
        unexpectedOperations.append("settings")
        return LocalNotificationSettings(
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

    func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        _ = options
        unexpectedOperations.append("requestAuthorization")
        throw CategoryCatalogTestError.unexpected("requestAuthorization")
    }

    func setCategories(_ categories: [LocalNotificationCategory]) async throws {
        categoryWrites.append(categories)
        let step = steps.isEmpty ? .success : steps.removeFirst()
        switch step {
        case .success:
            physicalCategories = categories
        case let .failure(error):
            throw error
        case .cancellation:
            throw CancellationError()
        case let .suspendedSuccess(barrier):
            physicalCategories = categories
            await barrier.markEnteredAndWait()
        }
    }

    func schedule(_ request: LocalNotificationRequest) async throws {
        _ = request
        unexpectedOperations.append("schedule")
        throw CategoryCatalogTestError.unexpected("schedule")
    }

    func pending() async -> [LocalNotificationPendingSnapshot] {
        unexpectedOperations.append("pending")
        return []
    }

    func delivered() async -> [LocalNotificationDeliveredSnapshot] {
        unexpectedOperations.append("delivered")
        return []
    }

    func removePending(_ identifiers: Set<LocalNotificationID>) async {
        _ = identifiers
        unexpectedOperations.append("removePending")
    }

    func removeAllPending() async {
        unexpectedOperations.append("removeAllPending")
    }

    func removeDelivered(_ identifiers: Set<LocalNotificationID>) async {
        _ = identifiers
        unexpectedOperations.append("removeDelivered")
    }

    func removeAllDelivered() async {
        unexpectedOperations.append("removeAllDelivered")
    }

    func setBadgeCount(_ count: Int) async throws {
        _ = count
        unexpectedOperations.append("setBadgeCount")
        throw CategoryCatalogTestError.unexpected("setBadgeCount")
    }

    func clearBadge() async throws {
        unexpectedOperations.append("clearBadge")
        throw CategoryCatalogTestError.unexpected("clearBadge")
    }

    func events() async -> AsyncStream<LocalNotificationEvent> {
        unexpectedOperations.append("events")
        return AsyncStream { $0.finish() }
    }
}

private actor CategoryWriteBarrier {
    private var entered = false
    private var released = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func markEnteredAndWait() async {
        entered = true
        let waiters = entryWaiters
        entryWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        guard !released else { return }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { continuation in
            entryWaiters.append(continuation)
        }
    }

    func release() {
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }
}
