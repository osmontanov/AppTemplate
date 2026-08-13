# Connected Mini Store Phase 6: Product Reminders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add useful product reminders with settings-first permission, three trigger choices, bounded image fallback, immutable Store actions, safe observation history, and exactly-once typed response routing into phase-5 protection.

**Architecture:** `ProductReminderRepository` composes the low-level notification service and phase-1 image loader. One app-owned category composer serializes Store ∪ lab commits through phase-2 `AsyncOperationGate`. The delegate bridge awaits event history/publication, then a typed dispatcher, then completes the OS callback. A coordinator accepts only typed commands, selects restored+Main+ready+active scenes, and buffers newest 32; receipts and safe history retain 100.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation, UserNotifications confined to the existing Internal boundary, UniformTypeIdentifiers, Swift Testing, XCTest, iOS/iPadOS/macOS 26.0, Xcode 26.6

**Normative design:** `docs/superpowers/specs/2026-08-13-connected-mini-store-design.md` at commit `e372913a20bcebd09675fe3f7cf965d2cd40a11d`.

## Global Constraints

- Complete phases 1–5. Consume exact `AppClock`, `IImageLoader.load(_:policy:)`, product/protected repositories, scene actions, and phase-2 `AsyncOperationGate`.
- “Remind me” is the only permission trigger. Always read settings first: authorized/provisional/ephemeral continue; notDetermined requests once; denied/notSupported/unknown return denial without re-prompt or image work.
- Choices are Quick Test 10 seconds, interval `1...604_800` (repeating `60...604_800`), and an absolute future date no more than one year from `AppClock.now()`.
- Deterministic request ID replaces one product reminder. Reschedule uses the same ID, text only, 600 seconds, no network/image/stale attachment. Cancel removes only that ID.
- Exact fixed IDs are category `store.product-reminder`, actions `store.product.open`, `store.product.favorite`, `store.product.remind-later`, and request `store.product.<positive-id>.reminder`. Product identity comes only from typed metadata key `store.product.id`; custom action deep links are nil.
- Actions are Open Product, Favorite, Remind Later in that order. Favorite has `.foreground` and never OS `.authenticationRequired`. Add Note belongs to phase 7.
- Only the composer calls live `setCategories`; every candidate is Store-first plus deterministically sorted unique lab categories. Failure preserves the committed union.
- Delegate response order is safe history append + observation yield → direct awaited dispatch/queue → completion exactly once. History observes; it never drives navigation or reschedule.
- Scene eligibility requires restored, Main, registered ready, and platform active. Newest-32 FIFO drops oldest with content-free diagnostics and drains to the most recently eligible scene.
- Receipt dedupe and safe history each retain newest 100. No history/diagnostic stores title, body, URL, note text, metadata, attachment path, physical ID, raw framework object, or token.
- Follow RED → intended RED → minimal GREEN → focused regression → commit. Every task compiles all platforms.
- Do not modify `AppTemplate.xcodeproj/project.pbxproj`, `AppTemplate/Resources/Localizable.xcstrings`, or `graphify-out/`. Stage only listed paths.

---

### Task 1: Fixed Store Category, Typed Metadata, and Reminder Repository

**Create**

- `AppTemplate/App/Notifications/AppNotificationIdentifiers.swift`
- `AppTemplate/Features/Store/Reminders/ProductReminderMetadata.swift`
- `AppTemplate/Features/Store/Reminders/ProductReminderRescheduleSource.swift`
- `AppTemplate/Features/Store/Reminders/StoreProductNotificationCategory.swift`
- `AppTemplate/Features/Store/Reminders/IProductReminderRepository.swift`
- `AppTemplate/Features/Store/Reminders/ProductReminderRepository.swift`
- `AppTemplate/Features/Store/Reminders/ReminderAttachmentStager.swift`

**Test**

- `AppTemplateTests/Features/Store/Reminders/ProductReminderMetadataTests.swift`
- `AppTemplateTests/Features/Store/Reminders/StoreProductNotificationCategoryTests.swift`
- `AppTemplateTests/Features/Store/Reminders/ProductReminderRepositoryTests.swift`
- `AppTemplateTests/TestSupport/StoreReminders/ProductReminderFixtures.swift`

**Consumes**

```swift
nonisolated protocol IImageLoader: Sendable { func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage }
nonisolated protocol ILocalNotificationService: Sendable { func settings() async -> LocalNotificationSettings; func requestAuthorization(_ options: LocalNotificationAuthorizationOptions) async throws -> Bool; func schedule(_ request: LocalNotificationRequest) async throws; func pending() async -> [LocalNotificationPendingSnapshot]; func removePending(_ identifiers: Set<LocalNotificationID>) async }
```

**Produces**

```swift
nonisolated enum ProductReminderSelection: Equatable, Sendable { case quickTest; case interval(seconds: TimeInterval, repeats: Bool); case calendar(date: Date, timeZone: TimeZone) }
nonisolated enum ProductReminderStatus: Equatable, Sendable { case notScheduled; case scheduled(nextTriggerDate: Date?) }
nonisolated enum ProductReminderScheduleWarning: Equatable, Sendable { case textOnlyAttachmentFallback }
nonisolated enum ProductReminderScheduleResult: Equatable, Sendable { case scheduled; case scheduledWithWarning(ProductReminderScheduleWarning) }
nonisolated enum ProductReminderError: Error, Equatable, Sendable { case authorizationDenied, invalidProductID, intervalOutOfRange, repeatingIntervalBelowMinimum, calendarNotInFuture, calendarBeyondOneYear, invalidRescheduleSource }
nonisolated struct ProductReminderMetadata: Equatable, Sendable { let productID: Product.ID; static func decode(_ values: [String: LocalNotificationMetadataValue]) throws -> Self; var notificationValues: [String: LocalNotificationMetadataValue] { get } }
nonisolated struct ProductReminderRescheduleSource: Equatable, Sendable { let requestID: LocalNotificationID; let metadata: ProductReminderMetadata; let title: String; let subtitle: String; let body: String; let sound: LocalNotificationSound; static func decode(from event: LocalNotificationEvent) throws -> Self }
nonisolated protocol IProductReminderRepository: Sendable { func status(productID: Product.ID) async -> ProductReminderStatus; func schedule(product: Product, selection: ProductReminderSelection) async throws -> ProductReminderScheduleResult; func remindLater(from source: ProductReminderRescheduleSource, after delay: Duration) async throws; func cancel(productID: Product.ID) async }
nonisolated enum AppNotificationIdentifiers { static let storeCategory: LocalNotificationCategoryID; static let openProductAction: LocalNotificationActionID; static let favoriteAction: LocalNotificationActionID; static let remindLaterAction: LocalNotificationActionID; static func productRequest(_ productID: Product.ID) throws -> LocalNotificationID }
nonisolated enum StoreProductNotificationCategory { static func make() -> LocalNotificationCategory }
nonisolated struct StagedReminderAttachment: Sendable { let attachment: LocalNotificationAttachment; func cleanup() }
actor ReminderAttachmentStager { init(directory: URL); func stage(_ image: LoadedImage, productID: Product.ID) async throws -> StagedReminderAttachment }
actor ProductReminderRepository: IProductReminderRepository { init(service: any ILocalNotificationService, imageLoader: any IImageLoader, attachmentStager: ReminderAttachmentStager, clock: AppClock); func status(productID: Product.ID) async -> ProductReminderStatus; func schedule(product: Product, selection: ProductReminderSelection) async throws -> ProductReminderScheduleResult; func remindLater(from source: ProductReminderRescheduleSource, after delay: Duration) async throws; func cancel(productID: Product.ID) async }
```

- [ ] **RED:** prove fixed ordering/options, settings-first permission, bounded triggers, cancellation, and text-only reschedule.

```swift
@Test func storeCategoryHasFrozenProductAgnosticActions() throws {
    let category = StoreProductNotificationCategory.make()
    let buttons = category.actions.compactMap { action -> LocalNotificationButtonAction? in
        guard case let .button(button) = action else { return nil }
        return button
    }
    try #require(buttons.count == 3)
    #expect(category.id.value == "store.product-reminder")
    #expect(buttons.map(\.id.value) == ["store.product.open", "store.product.favorite", "store.product.remind-later"])
    #expect(buttons[1].options.contains(.foreground)); #expect(!buttons[1].options.contains(.authenticationRequired))
    #expect(buttons.allSatisfy { $0.deepLink == nil }); #expect(category.reportsDismissal)
}
@Test func deniedExistingSettingsNeverPromptOrLoadImage() async {
    let trace = OperationTrace()
    let repository = ProductReminderRepository.fixture(settings: .denied, trace: trace)
    await #expect(throws: ProductReminderError.authorizationDenied) { try await repository.schedule(product: .fixture(id: 7), selection: .quickTest) }
    #expect(await trace.values == [.settings])
}
@Test func notDeterminedOrdersPromptBeforeImageAndSchedule() async throws {
    let trace = OperationTrace()
    _ = try await ProductReminderRepository.fixture(settings: .notDetermined, authorization: true, trace: trace).schedule(product: .fixture(id: 7), selection: .quickTest)
    #expect(await trace.values == [.settings, .authorization, .imageLoad, .schedule])
}
```

Also assert action literals/order, Favorite `.foreground` and not `.authenticationRequired`, nil custom links, positive metadata/IDs, `.ephemeral` schedules without prompting, selected cancellation, request replacement, staging cleanup, safe calendar/interval limits, calendar trigger `repeats == false`, and `remindLater` rejecting non-Store/mismatched stored requests.

- [ ] **RED command:** expect nonzero because Store reminder types do not exist.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/ProductReminderMetadataTests -only-testing:AppTemplateTests/StoreProductNotificationCategoryTests -only-testing:AppTemplateTests/ProductReminderRepositoryTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

- [ ] **GREEN:** branch on `settings().authorizationStatus`; only `.notDetermined` calls authorization. After permission, load an optional thumbnail with `.product`; rethrow `CancellationError`, convert other load/stage failures to nil, and `defer` cleanup. Schedule text with warning when nil. `ProductReminderRescheduleSource.decode` requires a `.decoded(LocalNotificationStoredRequest)` in Store category whose metadata, deterministic ID, and product deep link agree; copy only title/subtitle/body/sound. `remindLater` requires `.seconds(600)`, schedules the same ID with no attachment, and performs no image/product/network lookup. This task implements and tests the repository in isolation; Task 3 adds it to the Store slice only when the complete dispatcher graph can be built. No temporary live reminder or delegate is permitted between commits.

```swift
switch (await service.settings()).authorizationStatus {
case .authorized, .provisional, .ephemeral: break
case .notDetermined:
    guard try await service.requestAuthorization([.alert, .sound]) else { throw ProductReminderError.authorizationDenied }
case .denied, .notSupported, .unknown:
    throw ProductReminderError.authorizationDenied
}
```

- [ ] **PASS:** run focused tests; expect exit 0, then commit.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/ProductReminderMetadataTests -only-testing:AppTemplateTests/StoreProductNotificationCategoryTests -only-testing:AppTemplateTests/ProductReminderRepositoryTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
git add AppTemplate/App/Notifications/AppNotificationIdentifiers.swift AppTemplate/Features/Store/Reminders AppTemplateTests/Features/Store/Reminders AppTemplateTests/TestSupport/StoreReminders
git commit -m "feat: add product reminder repository"
```

---

### Task 2: Atomic App-owned Category Catalog

**Create**

- `AppTemplate/App/Notifications/Categories/IAppNotificationCategoryCatalog.swift`
- `AppTemplate/App/Notifications/Categories/AppNotificationCategoryCatalog.swift`

**Modify**

- `AppTemplate/App/Services/LocalNotifications/LocalNotificationDependencies.swift`
- `AppTemplate/App/AppDependencies/AppDependencies.swift`

**Test**

- `AppTemplateTests/App/Notifications/Categories/AppNotificationCategoryCatalogTests.swift`
- `AppTemplateTests/App/Composition/AppDependenciesTests.swift`

**Consumes**

```swift
nonisolated protocol ILocalNotificationService: Sendable { func setCategories(_ categories: [LocalNotificationCategory]) async throws }
actor AsyncOperationGate { func withExclusiveAccess<Value: Sendable>(_ operation: @Sendable () async throws -> Value) async throws -> Value }
nonisolated enum StoreProductNotificationCategory { static func make() -> LocalNotificationCategory }
```

**Produces**

```swift
nonisolated protocol IAppNotificationCategoryCatalog: Sendable { func categories() async -> [LocalNotificationCategory]; func bootstrapIfNeeded() async throws; func replaceLabCategories(_ categories: [LocalNotificationCategory]) async throws; func resetLabCategories() async throws }
nonisolated final class AppNotificationCategoryCatalog: IAppNotificationCategoryCatalog { init(service: any ILocalNotificationService, storeCategory: LocalNotificationCategory, gate: AsyncOperationGate) }
nonisolated struct LocalNotificationDependencies: Sendable { let service: any ILocalNotificationService; let categoryCatalog: any IAppNotificationCategoryCatalog /* plus existing runtime collaborators */; func bootstrapCategoriesIfNeeded() async throws }
private struct CategoryCatalogCandidate: Sendable { let union: [LocalNotificationCategory]; let normalizedLabCategories: [LocalNotificationCategory] }
private actor CategoryCatalogState { init(storeCategory: LocalNotificationCategory); func candidate(replacingLabWith categories: [LocalNotificationCategory]) throws -> CategoryCatalogCandidate; func commit(_ candidate: CategoryCatalogCandidate); func categories() -> [LocalNotificationCategory] }
```

- [ ] **RED:** prove Store-first union, unique/sorted lab IDs, Store-ID rejection, rollback, idempotent bootstrap, FIFO replace/reset, and queued cancellation.

```swift
@Test func failedReplacementPreservesCommittedUnion() async throws {
    let service = ScriptedNotificationService(results: [.success, .failure(TestError.write)])
    let catalog = AppNotificationCategoryCatalog(service: service, storeCategory: .storeFixture, gate: AsyncOperationGate())
    try await catalog.bootstrapIfNeeded()
    await #expect(throws: TestError.write) { try await catalog.replaceLabCategories([.labFixture]) }
    #expect(await catalog.categories() == [.storeFixture])
}
```

- [ ] **RED command:** expect nonzero because the composer does not exist; the phase-2 gate already passes.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/AppNotificationCategoryCatalogTests -only-testing:AppTemplateTests/AppDependenciesTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

- [ ] **GREEN:** the final class stores only immutable Sendable `service`, `storeCategory`, `gate`, and private state actor. The state normalizes lab categories by ID and returns both the Store-first union and normalized labs in one candidate. Duplicate lab IDs or the Store ID throw before a service call. A gate closure captures immutable values, awaits candidate, service write, then commits that exact candidate; it never stores the raw argument or calls back into catalog actor state. Failed bootstrap remains retryable; replace-before-bootstrap commits Store+labs once. Failed/cancelled writes do not commit. Replace the old low-level startup-category closure: `LocalNotificationDependencies.bootstrapCategoriesIfNeeded()` delegates only to this catalog. The existing scene-registration task attempts it once on startup; concurrent windows converge through the same gate. Failure is safely surfaced and retryable, but never changes the normative scene eligibility (restored + Main + typed-navigation ready), so a cold-launch response from an earlier request is not stranded. The hard registration barrier applies only before every new Store schedule. Freeze public `LocalNotificationDependencies.categoryCatalog` and Task-3 `eventHistory` as the sole app instances; live/in-memory factories compose each once, and identity/call-routing tests prove Phase 7 can reuse them. Phase 7 receives only plural lab methods.

```swift
try await gate.withExclusiveAccess { [service, state] in
    let candidate = try await state.candidate(replacingLabWith: categories)
    try await service.setCategories(candidate.union)
    await state.commit(candidate)
}
```

- [ ] **PASS:** run focused tests; expect exit 0, then commit.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/AppNotificationCategoryCatalogTests -only-testing:AppTemplateTests/AppDependenciesTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
git add AppTemplate/App/Notifications/Categories AppTemplate/App/Services/LocalNotifications/LocalNotificationDependencies.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplateTests/App/Notifications/Categories AppTemplateTests/App/Composition/AppDependenciesTests.swift
git commit -m "feat: compose notification categories atomically"
```

---

### Task 3: Safe History, Direct Dispatcher, and Ready-scene FIFO 32

**Create**

- `AppTemplate/App/Services/LocalNotifications/LocalNotificationEventSummary.swift`
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationEventHistory.swift`
- `AppTemplate/App/Notifications/Actions/ManagedLocalNotificationResponse.swift`
- `AppTemplate/App/Notifications/Actions/NotificationResponseReceiptStore.swift`
- `AppTemplate/App/Notifications/Actions/StoreNotificationActionDispatcher.swift`
- `AppTemplate/App/AppDependencies/AppNotificationGraph.swift`
- `AppTemplate/App/Navigation/Notifications/AppSceneNotificationCommandReceiver.swift`

**Modify**

- `AppTemplate/Features/Store/Reminders/ProductReminderRepository.swift`
- `AppTemplate/Features/Store/Reminders/IProductReminderRepository.swift`
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationEventHub.swift`
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationEvent.swift`
- `AppTemplate/App/Services/LocalNotifications/Internal/NotificationCenterDelegateBridge.swift`
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationDependencies.swift`
- `AppTemplate/App/AppDependencies/AppDependencies.swift`
- `AppTemplate/App/Navigation/Notifications/LocalNotificationNavigationCoordinator.swift`
- `AppTemplate/App/Navigation/Notifications/LocalNotificationSceneReceiving.swift`
- `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`

**Test**

- `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationEventHistoryTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationEventHubTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationServiceTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/InMemoryLocalNotificationServiceTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/NotificationCenterDelegateBridgeTests.swift`
- `AppTemplateTests/App/Notifications/Actions/StoreNotificationActionDispatcherTests.swift`
- `AppTemplateTests/App/Notifications/Actions/NotificationResponseReceiptStoreTests.swift`
- `AppTemplateTests/App/Navigation/Notifications/LocalNotificationNavigationCoordinatorTests.swift`
- `AppTemplateTests/App/Navigation/Notifications/AppSceneNotificationCommandReceiverTests.swift`
- `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
- `AppTemplateTests/App/Composition/AppNotificationGraphTests.swift`
- `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Consumes**

```swift
nonisolated enum LocalNotificationEvent: Hashable, Codable, Sendable { case foreground(notification: LocalNotificationEventNotification, presentation: LocalNotificationForegroundPresentation), opened(notification: LocalNotificationEventNotification, deepLink: URL?), dismissed(notification: LocalNotificationEventNotification), action(notification: LocalNotificationEventNotification, id: LocalNotificationActionID, deepLink: URL?), textAction(notification: LocalNotificationEventNotification, id: LocalNotificationActionID, text: String, deepLink: URL?), diagnostic(LocalNotificationDiagnostic) }
nonisolated protocol IProductReminderRepository: Sendable { func status(productID: Product.ID) async -> ProductReminderStatus; func schedule(product: Product, selection: ProductReminderSelection) async throws -> ProductReminderScheduleResult; func remindLater(from source: ProductReminderRescheduleSource, after delay: Duration) async throws; func cancel(productID: Product.ID) async }
nonisolated enum ProtectedStoreAction: Hashable, Sendable { case favorite(Product.ID), openFavorites, openAccount }
nonisolated protocol IAppNotificationCategoryCatalog: Sendable { func categories() async -> [LocalNotificationCategory]; func bootstrapIfNeeded() async throws; func replaceLabCategories(_ categories: [LocalNotificationCategory]) async throws; func resetLabCategories() async throws }
```

**Produces**

```swift
nonisolated enum LocalNotificationDiagnosticReason: String, Codable, CaseIterable, Hashable, Sendable { case missingEnvelope, corruptEnvelope, unsupportedEnvelopeVersion, identifierMismatch, invalidDeepLink, unrecognizedAction, invalidStoreMetadata, notificationQueueOverflow, storeActionFailed }
nonisolated enum LocalNotificationEventKind: String, Codable, Equatable, Sendable { case foreground, opened, dismissed, action, textAction, diagnostic }
nonisolated enum LocalNotificationEventStatus: String, Codable, Equatable, Sendable { case observed, rejected }
nonisolated enum LocalNotificationEventActionKind: String, Codable, Equatable, Sendable { case openProduct, favorite, remindLater, labButton, labTextInput, unknown }
nonisolated struct LocalNotificationEventSummary: Equatable, Sendable { let kind: LocalNotificationEventKind; let actionKind: LocalNotificationEventActionKind?; let status: LocalNotificationEventStatus; let diagnosticReason: LocalNotificationDiagnosticReason?; let textInputCharacterCount: Int? }
nonisolated struct LocalNotificationEventRecord: Identifiable, Equatable, Sendable { let id: UInt64; let timestamp: Date; let summary: LocalNotificationEventSummary }
nonisolated protocol ILocalNotificationEventReading: Sendable { func records() async -> [LocalNotificationEventRecord]; func updates() async -> AsyncStream<[LocalNotificationEventRecord]>; func clear() async }
actor LocalNotificationEventHistory: ILocalNotificationEventReading { init(clock: AppClock, capacity: Int = 100); func records() -> [LocalNotificationEventRecord]; func updates() -> AsyncStream<[LocalNotificationEventRecord]>; func append(_ event: LocalNotificationEvent); func clear() }
actor LocalNotificationEventHub { init(history: LocalNotificationEventHistory, publicCapacity: Int = 100); func events() -> AsyncStream<LocalNotificationEvent>; func publish(_ event: LocalNotificationEvent) async }
// Task 3 extends LocalNotificationDependencies with this exact sole instance:
// let eventHistory: LocalNotificationEventHistory
nonisolated struct AppNotificationGraph: Sendable { let dependencies: LocalNotificationDependencies; let reminders: any IProductReminderRepository }
@MainActor struct StoreDependencies: Sendable { let products: any IProductRepository; let session: any ISessionActions; let favorites: any IFavoritesRepository; let cart: any ICartRepository; let preferences: any IStorePreferencesRepository; let reminders: any IProductReminderRepository; let appInfo: any IAppInfoService }
nonisolated enum NotificationResponseKind: Hashable, Sendable { case opened; case action(LocalNotificationActionID) }
nonisolated struct NotificationResponseReceipt: Hashable, Sendable { let requestID: LocalNotificationID; let kind: NotificationResponseKind; let deliveredAt: Date }
nonisolated struct ManagedLocalNotificationResponse: Sendable { let event: LocalNotificationEvent; let deliveredAt: Date }
actor NotificationResponseReceiptStore { init(capacity: Int = 100); func insertIfNew(_ receipt: NotificationResponseReceipt) -> Bool }
nonisolated enum NotificationNavigationCommand: Equatable, Sendable { case navigate(NavigationIntent), protected(ProtectedStoreAction) }
nonisolated enum NotificationQueueDiagnostic: Equatable, Sendable { case queueOverflow(droppedCount: Int) }
nonisolated struct NotificationSceneReadiness: Equatable, Sendable { let isRestored: Bool; let isMain: Bool; let isReady: Bool; let isPlatformEligible: Bool; var isEligible: Bool { get } }
nonisolated protocol IStoreNotificationActionDispatching: Sendable { func handle(_ response: ManagedLocalNotificationResponse) async }
actor StoreNotificationActionDispatcher: IStoreNotificationActionDispatching { init(coordinator: LocalNotificationNavigationCoordinator, reminders: any IProductReminderRepository, receipts: NotificationResponseReceiptStore, diagnosticSink: @escaping @Sendable (LocalNotificationDiagnostic) async -> Void) }
@MainActor protocol LocalNotificationSceneReceiving: AnyObject { func receiveNotificationCommand(_ command: NotificationNavigationCommand) async }
@MainActor final class AppSceneNotificationCommandReceiver: LocalNotificationSceneReceiving {
    init(navigation: AppSceneNavigationLifecycle, router: StoreRouter,
         executor: ProtectedStoreActionExecutor, session: any ISessionActions)
    func receiveNotificationCommand(_ command: NotificationNavigationCommand) async
}
@MainActor final class LocalNotificationNavigationCoordinator { init(queueCapacity: Int = 32, diagnosticSink: @escaping @MainActor @Sendable (NotificationQueueDiagnostic) async -> Void); func register(id: UUID, receiver: any LocalNotificationSceneReceiving); func setReadiness(_ readiness: NotificationSceneReadiness, id: UUID); func deliver(_ command: NotificationNavigationCommand) async }
// Task 3 tightens reminder composition before exposing it to Store:
// ProductReminderError gains `.categoryRegistrationFailed`.
// ProductReminderRepository.init(..., categoryCatalog: any IAppNotificationCategoryCatalog, ...)
```

Extend `LocalNotificationDiagnosticReason` with fixed safe cases `.invalidStoreMetadata`, `.notificationQueueOverflow`, and `.storeActionFailed`. The production bridge initializer is `NotificationCenterDelegateBridge(namespace: LocalNotificationNamespace, deepLinkPolicy: LocalNotificationDeepLinkPolicy, eventHub: LocalNotificationEventHub, responseDispatcher: any IStoreNotificationActionDispatching, unmanagedHandler: NotificationCenterUnmanagedHandler?)`. Live composition maps `NotificationQueueDiagnostic.queueOverflow` to `.diagnostic(.init(id: nil, reason: .notificationQueueOverflow))` through the same hub; dispatcher maps invalid metadata/action failure to the other two cases, also through the hub.

- [ ] **RED:** prove safe history, direct order, semantic dedupe, and bounded coordinator.

```swift
@MainActor @Test func overflowKeepsNewestThirtyTwoAndReportsSafely() async {
    let diagnostics = QueueDiagnosticSpy()
    let coordinator = LocalNotificationNavigationCoordinator(queueCapacity: 32) { diagnostics.record($0) }
    for id in 1...34 { await coordinator.deliver(.navigate(.openProduct(id))) }
    let receiver = SceneReceiverSpy(); coordinator.register(id: .fixture, receiver: receiver)
    coordinator.setReadiness(.init(isRestored: true, isMain: true, isReady: true, isPlatformEligible: true), id: .fixture)
    #expect(receiver.productIDs == Array(3...34))
    #expect(diagnostics.values == [.queueOverflow(droppedCount: 1), .queueOverflow(droppedCount: 2)])
}
@Test func bridgePublishesDispatchesThenCompletesOnce() async {
    let trace = DelegateTrace(); await NotificationCenterDelegateBridge.fixture(trace: trace).processResponse(.storeFixture) { trace.record(.completion) }
    #expect(trace.values == [.history, .published, .dispatched, .completion])
}
```

Also test four readiness gates, latest eligible scene, reentrant FIFO drain, receipt eviction 101→100, duplicate same receipt ignored but a different action for one request accepted, default/open convergence, Favorite protected command once, reschedule awaited, invalid metadata diagnostic/no command, Store action failure diagnostic, overflow arriving in the sole history, and dismissal observation-only/no receipt. Freeze the scene receiver matrix: `.navigate` calls the exact phase-4 scene navigation path; authenticated `.protected(.favorite)` invokes the phase-5 executor once with that user ID; Guest calls `requestProtected`, retains one pending action, and presents Authentication, then the normal session reconciliation consumes and executes it exactly once after login; unavailable presents `.sessionRecovery(reason)` and performs no favorite/navigation mutation. Cancellation, duplicate receipts, identity change, and two-scene delivery cannot double-run or bypass Authentication. Update the existing lifecycle tests to remove their old `AppSceneNavigationLifecycle as LocalNotificationSceneReceiving` existential assertions; they now prove lifecycle owns typed navigation while only `AppSceneNotificationCommandReceiver` conforms to the new async command boundary. Add a reminder/category ordering table: an eager scene bootstrap and a simultaneous first schedule cause one union write; scheduling awaits successful Store-category bootstrap immediately before `service.schedule`; bootstrap failure maps to `.categoryRegistrationFailed`, performs no schedule, and a later retry succeeds. Thus no Store request can be installed with an unregistered action category even when the user taps before scene startup finishes. History maps fixed Store identifiers to semantic action kinds and every Services-authored button/text ID only to `.labButton`/`.labTextInput`; it never stores the physical `LocalNotificationActionID`. Sentinel tests use `String(describing:)` to reject raw action ID, title/body/URL/metadata/path content. `updates()` atomically registers `.bufferingNewest(1)` and yields its snapshot in the same actor operation; it installs `continuation.onTermination` to remove that subscriber from actor state, and tests prove cancel+termination leaves zero continuations. Public `events()` uses `.bufferingNewest(100)`. Services later receives only `any ILocalNotificationEventReading`; `append` remains dispatcher/hub-only. Composition tests freeze order `namespace/runtime → history/hub/coordinator → service/catalog → reminder repository → dispatcher → delegate install`, verify the runtime sees no delegate before the dispatcher exists, and route calls through the same service/reminder/catalog/history actors exposed by `AppDependencies`.

- [ ] **RED command:** expect nonzero because navigation still consumes `navigationEvents` and lacks direct semantics.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/LocalNotificationEventHistoryTests -only-testing:AppTemplateTests/LocalNotificationEventHubTests -only-testing:AppTemplateTests/LocalNotificationServiceTests -only-testing:AppTemplateTests/InMemoryLocalNotificationServiceTests -only-testing:AppTemplateTests/StoreNotificationActionDispatcherTests -only-testing:AppTemplateTests/NotificationResponseReceiptStoreTests -only-testing:AppTemplateTests/LocalNotificationNavigationCoordinatorTests -only-testing:AppTemplateTests/AppSceneNotificationCommandReceiverTests -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests -only-testing:AppTemplateTests/NotificationCenterDelegateBridgeTests -only-testing:AppTemplateTests/AppNotificationGraphTests -only-testing:AppTemplateTests/AppDependenciesTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

- [ ] **GREEN:** remove `navigationEvents`, URL parsing, and coordinator subscription. `eventHub.publish` awaits `history.append` before yielding public continuations. The bridge awaits publish, then calls dispatcher exactly once for each managed response event, then completes once even on failure. Dispatcher no-ops foreground/dismissed/diagnostic/text actions; opened and fixed button actions validate Store decoded metadata. Normalize default tap and `store.product.open` to the same `.opened` receipt key; Favorite and Remind Later retain distinct action keys, so one different action for the same request remains valid. It inserts the receipt before Open/Favorite/Remind Later effects. Remind Later decodes the stored source and awaits `.seconds(600)`. Coordinator never interprets IDs/metadata; on overflow it drops first and emits cumulative count only. `AppSceneView` owns one `AppSceneNotificationCommandReceiver` beside its phase-5 executor, attempts the app-owned catalog bootstrap, and registers that receiver after restoration/root/session readiness regardless of bootstrap success. The receiver routes `.navigate` through `handleSampleIntent`; for `.protected` it calls `StoreRouter.requestProtected(action, session:)` and exhaustively maps `.execute` to `await executor.execute`, `.presentAuthentication` to the router-owned pending Authentication state, and `.blocked(reason)` to `.sessionRecovery(reason)`. It never mutates Favorites directly. Inject the same catalog into `ProductReminderRepository`; after permission but before image/schedule work, `schedule` awaits `bootstrapIfNeeded()`, maps non-cancellation failure to the typed category error, and never reports a reminder set before registration succeeds.

Replace the old self-contained `LocalNotificationDependencies.live/inMemory` construction with `AppNotificationGraph` factories that build topologically: resolve runtime/namespace/parser without installing a delegate; create the sole history, hub, coordinator, and receipt store; create the service and catalog; create the reminder repository; create dispatcher; create bridge; install that bridge exactly once; finally return dependencies plus the same reminder repository. Fail-closed/in-memory graphs follow the same object identity without a live runtime. `AppDependencies` stores that pair and its Store factory exposes `graph.reminders`. Update `ProjectConfigurationTests` to inject one isolated in-memory `AppNotificationGraph` and take its dependencies/Store reminder slice; it must not retain or recreate a direct `.inMemory()` dependencies factory. No mutable late-bound dispatcher, placeholder handler, second bridge, second history, or second reminder repository is permitted.

```swift
await eventHub.publish(event)
await responseDispatcher.handle(.init(event: event, deliveredAt: response.deliveredAt))
completion.complete(())
```

- [ ] **PASS:** run focused tests; expect exit 0, then commit.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/LocalNotificationEventHistoryTests -only-testing:AppTemplateTests/LocalNotificationEventHubTests -only-testing:AppTemplateTests/LocalNotificationServiceTests -only-testing:AppTemplateTests/InMemoryLocalNotificationServiceTests -only-testing:AppTemplateTests/StoreNotificationActionDispatcherTests -only-testing:AppTemplateTests/NotificationResponseReceiptStoreTests -only-testing:AppTemplateTests/LocalNotificationNavigationCoordinatorTests -only-testing:AppTemplateTests/AppSceneNotificationCommandReceiverTests -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests -only-testing:AppTemplateTests/NotificationCenterDelegateBridgeTests -only-testing:AppTemplateTests/AppNotificationGraphTests -only-testing:AppTemplateTests/AppDependenciesTests -only-testing:AppTemplateTests/ProjectConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
git add AppTemplate/App/Services/LocalNotifications/LocalNotificationEventSummary.swift AppTemplate/App/Services/LocalNotifications/LocalNotificationEventHistory.swift AppTemplate/App/Services/LocalNotifications/LocalNotificationEventHub.swift AppTemplate/App/Services/LocalNotifications/LocalNotificationEvent.swift AppTemplate/App/Services/LocalNotifications/Internal/NotificationCenterDelegateBridge.swift AppTemplate/App/Services/LocalNotifications/LocalNotificationDependencies.swift AppTemplate/App/AppDependencies/AppNotificationGraph.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplate/Features/Store/Dependencies/StoreDependencies.swift AppTemplate/Features/Store/Reminders/ProductReminderRepository.swift AppTemplate/Features/Store/Reminders/IProductReminderRepository.swift AppTemplate/App/Notifications/Actions AppTemplate/App/Navigation/Notifications AppTemplate/App/Navigation/Containers/AppSceneView.swift AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift AppTemplateTests/App/Services/LocalNotifications AppTemplateTests/App/Notifications/Actions AppTemplateTests/App/Navigation/Notifications AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift AppTemplateTests/App/Composition/AppNotificationGraphTests.swift AppTemplateTests/App/Composition/AppDependenciesTests.swift AppTemplateTests/Features/Store/Reminders/ProductReminderRepositoryTests.swift AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "feat: dispatch notification actions directly"
```

---

### Task 4: Reminder UI and Isolated Acceptance

**Create**

- `AppTemplate/Features/Store/Screens/ProductReminder/Model/ProductReminderModel.swift`
- `AppTemplate/Features/Store/Screens/ProductReminder/State/ProductReminderState.swift`
- `AppTemplate/Features/Store/Screens/ProductReminder/ViewModel/ProductReminderViewModel.swift`
- `AppTemplate/Features/Store/Screens/ProductReminder/View/ProductReminderView.swift`

**Modify**

- `AppTemplate/Features/Store/Screens/ProductDetail/View/ProductDetailView.swift`
- `AppTemplate/Features/Store/Flow/StoreFlowView.swift`
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationDependencies.swift`
- `AppTemplate/App/Entry/AppLaunchConfiguration.swift`
- `AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift`

**Test**

- `AppTemplateTests/Features/Store/Screens/ProductReminder/ProductReminderViewModelTests.swift`
- `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift`
- `AppTemplateUITests/Flows/ProductReminderUITests.swift`
- `AppTemplateUITests/TestSupport/StoreRobot.swift`

**Consumes**

```swift
nonisolated protocol IProductReminderRepository: Sendable { func status(productID: Product.ID) async -> ProductReminderStatus; func schedule(product: Product, selection: ProductReminderSelection) async throws -> ProductReminderScheduleResult; func remindLater(from source: ProductReminderRescheduleSource, after delay: Duration) async throws; func cancel(productID: Product.ID) async }
nonisolated protocol ILocalNotificationEventReading: Sendable { func records() async -> [LocalNotificationEventRecord]; func updates() async -> AsyncStream<[LocalNotificationEventRecord]>; func clear() async }
nonisolated enum StorePresentation: Identifiable, Hashable, Sendable { case filters, authentication, checkout, reminder(Product.ID), sessionRecovery(SessionUnavailableReason); var id: String { get } }
```

It also consumes the phase-1 fail-closed scenario named `product-reminder`.

**Produces**

```swift
nonisolated enum ProductReminderField: Hashable, Sendable { case interval, calendarDate }
nonisolated struct ProductReminderModel: Equatable, Sendable { var selection: ProductReminderSelection; var intervalText: String; var calendarDate: Date; var calendarTimeZone: TimeZone; func firstInvalidField(now: Date) -> ProductReminderField? }
nonisolated enum ProductReminderViewError: Equatable, Sendable { case invalid(ProductReminderField), authorizationDenied, schedule }
nonisolated enum ProductReminderState: Equatable, Sendable { case editing(model: ProductReminderModel, status: ProductReminderStatus), scheduling(ProductReminderModel), scheduled(ProductReminderScheduleResult), failed(model: ProductReminderModel, error: ProductReminderViewError) }
@MainActor @Observable final class ProductReminderViewModel { init(product: Product, reminders: any IProductReminderRepository, clock: AppClock); private(set) var state: ProductReminderState; var model: ProductReminderModel { get set }; var focusedField: ProductReminderField?; func refresh() async; func schedule() async; func cancel() async }
```

- [ ] **RED:** cover localized resolved date/time/time-zone, first invalid focus, interval limits, permission denial, attachment warning, false-success prevention, cancellation, status refresh, and selected cancellation.

```swift
@MainActor @Test func scheduleFailureNeverShowsSuccess() async {
    let viewModel = ProductReminderViewModel(product: .fixture(id: 7), reminders: .failing(TestError.schedule), clock: .fixed)
    await viewModel.schedule()
    guard case .failed(_, .schedule) = viewModel.state else { Issue.record("Expected schedule failure"); return }
}
```

- [ ] **RED command:** expect nonzero because the reminder capsule is absent.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/ProductReminderViewModelTests -only-testing:AppTemplateTests/AppLaunchConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

- [ ] **GREEN:** Product Detail presents `.reminder(productID)` with `.sheet(item:)`; the sheet owns schedule/cancel/dismiss, requests no permission on appearance, moves focus to the first invalid field, formats date/time/time zone/price with `FormatStyle`, and announces result changes. Live composition injects the same Task-3 history later consumed by phase 7. The `product-reminder` scenario uses in-memory settings/pending data, scripted images, and fail-closed networking, so UI tests never prompt/install a system request.

```swift
func schedule() async {
    if let field = model.firstInvalidField(now: clock.now()) {
        focusedField = field
        state = .failed(model: model, error: .invalid(field))
        return
    }
    state = .scheduling(model)
    do { state = .scheduled(try await reminders.schedule(product: product, selection: model.selection)) }
    catch is CancellationError { state = .editing(model: model, status: await reminders.status(productID: product.id)) }
    catch ProductReminderError.authorizationDenied { state = .failed(model: model, error: .authorizationDenied) }
    catch { state = .failed(model: model, error: .schedule) }
}
```

- [ ] **PASS:** run unit/UI tests; expect exit 0, then commit. The reminder robot's final assertion requires `ui-test.script-status.exhausted`; pending/failed/timeout is failure.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/ProductReminderViewModelTests -only-testing:AppTemplateTests/AppLaunchConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:AppTemplateUITests/ProductReminderUITests/testInMemoryQuickReminderAndCancel SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
git add AppTemplate/Features/Store/Screens/ProductReminder AppTemplate/Features/Store/Screens/ProductDetail/View/ProductDetailView.swift AppTemplate/Features/Store/Flow/StoreFlowView.swift AppTemplate/App/Services/LocalNotifications/LocalNotificationDependencies.swift AppTemplate/App/Entry/AppLaunchConfiguration.swift AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift AppTemplateTests/Features/Store/Screens/ProductReminder AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift AppTemplateUITests/Flows/ProductReminderUITests.swift AppTemplateUITests/TestSupport/StoreRobot.swift
git commit -m "feat: add product reminder experience"
```

## Phase 6 Exit Gate

Run roadmap boundary commands. Verify `! rg -n 'navigationEvents' AppTemplate/App/Navigation/Notifications AppTemplate/App/Services/LocalNotifications/LocalNotificationEventHub.swift` and `! rg -n 'setCategories' AppTemplate/Features`. Phase 7 consumes plural lab-category composition and the single 100-record safe history.
