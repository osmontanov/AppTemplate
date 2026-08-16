# Graph Report - /Users/aurora/Documents/AppTemplate  (2026-08-12)

## Corpus Check
- 410 files · ~317,748 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2888 nodes · 6990 edges · 207 communities (137 shown, 70 thin omitted)
- Extraction: 79% EXTRACTED · 21% INFERRED · 0% AMBIGUOUS · INFERRED: 1463 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Typed UserDefaults Service
- Navigation Snapshot Restoration
- Screen Models and States
- Typed UserDefaults Keys
- Application Dependency Composition
- Network Request Building
- Create Project Flow
- Feature Dependency Scaffolds
- Test Suite Inventory
- Home Navigation Flow
- App State Persistence
- Browse Related Navigation
- Scene Router Behavior
- Scene Navigation Lifecycle
- Local Model Registry
- Network Response Handling
- Network Provider Lifecycle
- Network Stub Execution
- App State Store
- App Flow Transitions
- Database Store Configuration
- Generic SwiftData Operations
- Core Application Infrastructure
- App Flow Coordinator
- Database Service Validation
- SwiftData Store Mutations
- Screen Route Definitions
- Persisted Flow Policy
- Navigation Guide Flow
- UserDefaults Encoded Values
- Generic Database Test Models
- Navigation and DI Designs
- SwiftData Query Operations
- Example Remote Service
- Architecture and Release Docs
- Keychain Codable Conveniences
- Security Executor Query Tests
- Adaptive App Shell
- App Sections and Intents
- Projects and About Screens
- Network Monitoring Context
- Database Adapter Validation
- Database Service Persistence
- Keychain Service Tests
- Security Keychain Executor
- Authentication Flow
- Settings Flow
- Keychain Keys and Memory
- UI Navigation Tests
- Project Task Domain
- Help and Quick Start
- Navigation Snapshot Schema
- Network Request Adapters
- Keychain Executor Test Doubles
- Test Fixture Errors
- Reentrant Codable Fixtures
- Service and UI Hardening
- Launch Routes and Fixtures
- Deep Link Parsing
- HTTP Header Handling
- Keychain Key Validation
- Security Executor Verification
- Database Operation Hooks
- Keychain Codec Test Models
- UserDefaults Recording Support
- Model Ownership Architecture
- Maintenance Flow
- Keychain Service Actor
- Keychain Service Errors
- Example Record Adapter
- Browse Flow Navigation
- Home Details Navigation
- Keychain Copy Result Normalization
- Scene Navigation Persistence
- Tab Accessibility Identifiers
- Onboarding Completion Flow
- Concurrent Keychain Operations
- Navigation Router Test Spies
- Application Flow Routing
- Flow Router Commands
- Preview Composition Fixtures
- Typed Keychain Keys
- Platform Details Screen
- Generic Database Contract
- Network Layer Hardening
- App State Persistence Results
- Browse Options Scaffold
- In-Memory App State Storage
- Database Failure Diagnostics
- SwiftData Schema Migration
- Project Details Navigation
- Codable About Routes
- App State Recovery
- Launch Configuration Modes
- HTTP Method Modeling
- App Settings Screen
- Keychain Retry Cancellation
- App Shell Hardening Plans
- Generic SwiftData Architecture
- App State Load Results
- Network Request Bodies
- Local Database Test Suite
- Database Concurrency Test Control
- UserDefaults Physical Kind Fixtures
- HTTP Status Validation
- Local Entity Adapters
- Project Info Sheet
- UserDefaults Native Type Tests
- UserDefaults Invalid Representation Tests
- Controlled Network Request Tests
- About Route Compatibility
- Keychain Executor Cancellation Tests
- Database Registry Identity Tests
- Precancelled Database Operation Tests
- HTTP Header Mapping Tests
- App Root Scene Persistence
- Loadable UI State
- URLSession Transport
- Project Basics Routing
- Project Options Routing
- Recorded Network Outcomes
- App-Private Storage Designs
- Settings Routes and Sheets
- Main Actor Network Liveness
- Application Flow Architecture
- Network Layer Design
- Network Stub Behavior
- Network Response Decoding
- Generic SwiftData Design
- UserDefaults Service Errors
- Injected Database Service Tests
- App Section Metadata Tests
- Keychain Security Call Kinds
- Neutral Model Examples
- Deep Link Errors
- In-Memory Keychain Invocations
- Hierarchical Navigation Plans
- App Shell Hardening Designs
- Tab Accessibility Metadata
- Network Data Requests
- Browse Screen State
- Browse Detail State
- Related Item Detail State
- Related Items State
- Home Dependencies
- App State Model Tests
- Loadable State Lifecycle
- Hierarchical Flow Navigation
- Project Configuration Tests
- Authentication State
- Authentication Help Model
- Authentication Help Route
- Browse Options Route
- Related Item Detail Route
- Related Items Model
- Guide Topic Model
- Guide Topic Route
- Home Details State
- Navigation Guide Model
- Quick Start Route
- Maintenance Route
- Onboarding Model
- Onboarding Route
- Project Basics State
- Project Info Route
- Project Review Route
- Projects State
- Task Details Route
- About Screen Model
- App Settings Route
- App Settings State
- Platform Details Model
- Platform Details Route
- Session Info Route
- Session Info State
- App State Storage Fixture
- Throwing Payload Encoding
- Keychain Sendability Check
- Type-Safe Dependency Injection
- Screen-Owned ViewModels
- Local Remote Model Examples
- Purpose-Driven Feature Structure
- Screen Capsule Architecture
- Loadable State Model
- Domain Model Ownership
- Screen Routes and Sheets
- Reusable SwiftUI State Views
- Layered Screen State Ownership
- Global App Flow Router
- Navigation-Only App Shell
- Reusable SwiftUI State Views
- Screen State Ownership Design
- macOS UI Window Isolation
- Light iOS App Icon
- Dark iOS App Icon
- Tinted iOS App Icon
- macOS 128pt Retina Icon
- macOS 128px App Icon
- macOS 16pt Retina Icon
- macOS 16px App Icon
- macOS 256pt Retina Icon
- macOS 256px App Icon
- macOS 32pt Retina Icon
- macOS 32px App Icon
- macOS 512pt Retina Icon
- macOS 512px App Icon

## God Nodes (most connected - your core abstractions)
1. `AppTemplate` - 88 edges
2. `Testing` - 76 edges
3. `RecordingUserDefaults` - 67 edges
4. `FlowRouter` - 62 edges
5. `AppState` - 61 edges
6. `UserDefaultsService` - 59 edges
7. `ExampleRecord` - 57 edges
8. `AppFlowRouter` - 51 edges
9. `AppRouter` - 49 edges
10. `IFlowRouter` - 46 edges

## Surprising Connections (you probably didn't know these)
- `makeTestAppFlowCoordinator()` --calls--> `AppStateStore`  [INFERRED]
  AppTemplateTests/TestSupport/AppFlowCoordinatorSpy.swift → AppTemplate/App/ApplicationState/AppStateStore.swift
- `makeTestAppFlowCoordinator()` --calls--> `AppFlowRouter`  [INFERRED]
  AppTemplateTests/TestSupport/AppFlowCoordinatorSpy.swift → AppTemplate/App/Navigation/Routing/AppFlowRouter.swift
- `SettingsViewModelTests` --calls--> `AppInfoService`  [INFERRED]
  AppTemplateTests/Features/Settings/Screens/Settings/SettingsViewModelTests.swift → AppTemplate/App/Services/AppInfo/AppInfoService.swift
- `makeGenericDatabase()` --calls--> `LocalDatabaseService`  [INFERRED]
  AppTemplateTests/TestSupport/LocalDatabase/GenericLocalDatabaseTestSupport.swift → AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift
- `.body` --calls--> `CreateProjectFlowView`  [INFERRED]
  AppTemplateTests/Project/ProjectConfigurationTests.swift → AppTemplate/Features/Projects/Flow/CreateProjectFlowView.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Scoped Ownership Architecture** — docs_superpowers_specs_2026_07_25_type_safe_dependency_injection_design_dependency_lifetimes, docs_superpowers_specs_2026_07_28_feature_scoped_view_model_architecture_design_feature_dependency_values, docs_superpowers_specs_2026_07_28_screen_capsule_service_architecture_design_screen_capsule, docs_superpowers_specs_2026_07_29_expanded_navigation_and_sheets_design_screen_owned_navigation [INFERRED 0.85]
- **App-Private Persistence Boundaries** — docs_superpowers_plans_2026_08_10_swiftdata_local_service_i_local_database_service, docs_superpowers_plans_2026_08_12_keychain_service_i_keychain_service, docs_superpowers_plans_2026_08_12_userdefaults_service_user_defaults_service [INFERRED 0.75]
- **Deterministic Cross-Platform UI Testing** — docs_superpowers_plans_2026_07_31_template_hardening_deterministic_ui_test_composition, docs_superpowers_plans_2026_08_04_platform_shell_scene_navigation_persistence_policy, docs_superpowers_plans_2026_08_09_macos_ui_test_window_isolation_appkit_persistence_isolation, docs_superpowers_plans_2026_08_12_ipad_ui_gate_stabilization_postcondition_bounded_retry [INFERRED 0.75]

## Communities (207 total, 70 thin omitted)

### Community 0 - "Typed UserDefaults Service"
Cohesion: 0.16
Nodes (14): UserDefaultsService, captureUserDefaultsServiceError(), expectUserDefaultsServiceError(), String, Void, UserDefaultsServiceTests, makeRecordingUserDefaults(), RecordingUserDefaults (+6 more)

### Community 1 - "Navigation Snapshot Restoration"
Cohesion: 0.11
Nodes (19): Data, FlowPathSnapshot, .restoredPath, .semanticComponents, Data, NavigationPath, String, NavigationSnapshotCodec (+11 more)

### Community 2 - "Screen Models and States"
Cohesion: 0.04
Nodes (28): LocalDatabaseStoreLocationError, missingBundleIdentifier, LocalDatabasePersistenceInvariantError, duplicatePersistedID, AuthenticationModel, AuthenticationHelpState, BrowseDetailModel, BrowseOptionsModel (+20 more)

### Community 3 - "Typed UserDefaults Keys"
Cohesion: 0.08
Nodes (19): Bool, Self, String, throws, Value, UserDefaultsComponent, UserDefaultsKey, String (+11 more)

### Community 4 - "Application Dependency Composition"
Cohesion: 0.10
Nodes (16): AppDependencies, AppInfoService, String, IKeychainService, ILocalDatabaseService, IRemoteService, SettingsDependencies, AppDependenciesTests (+8 more)

### Community 5 - "Network Request Building"
Cohesion: 0.09
Nodes (25): NetworkTask, NetworkRequestBuilder, .task, CamelCasePayload, ComputedSnapshotTarget, .baseURL, .path, .task (+17 more)

### Community 6 - "Create Project Flow"
Cohesion: 0.07
Nodes (23): CreateProjectFlowView, .body, .localRouter, ProjectBasicsView, .body, ProjectBasicsViewModel, ProjectOptionsView, .body (+15 more)

### Community 7 - "Feature Dependency Scaffolds"
Cohesion: 0.05
Nodes (20): NetworkEventMonitor, NetworkTransport, AuthenticationDependencies, BrowseDependencies, BrowseModel, RelatedItemDetailModel, GuideTopicState, QuickStartState (+12 more)

### Community 8 - "Test Suite Inventory"
Cohesion: 0.12
Nodes (3): AppTemplate, SwiftUI, Testing

### Community 9 - "Home Navigation Flow"
Cohesion: 0.10
Nodes (12): Route, HomeFlowView, .body, HomeView, .body, HomeViewModel, .isResetAlertPresented, Bool (+4 more)

### Community 10 - "App State Persistence"
Cohesion: 0.12
Nodes (16): Data, UserDefaultsAppStateStorage, IUserDefaultsService, Data, String, UserDefaultsAppStateStorageTests, KeyRecord, State (+8 more)

### Community 11 - "Browse Related Navigation"
Cohesion: 0.08
Nodes (17): BrowseItem, String, BrowseDetailRoute, relatedItems, BrowseDetailView, .body, BrowseDetailViewModel, RelatedItemDetailView (+9 more)

### Community 12 - "Scene Router Behavior"
Cohesion: 0.14
Nodes (10): NavigationRoute, NavigationOutcome, applied, deferred, AppRouter, ProjectDetailsRoute, task, ProjectsRoute (+2 more)

### Community 13 - "Scene Navigation Lifecycle"
Cohesion: 0.18
Nodes (10): AppSceneNavigationLifecycle, .snapshotForPersistence, Data, URL, UUID, AppSceneNavigationLifecycleTests, Data, Int (+2 more)

### Community 14 - "Local Model Registry"
Cohesion: 0.09
Nodes (24): Adapter, LocalDatabaseModelRegistry, LocalDatabaseModelRegistryError, duplicateAdapter, duplicateDiagnosticName, duplicateEntity, duplicateValue, LocalDatabaseRegistrationIdentity (+16 more)

### Community 15 - "Network Response Handling"
Cohesion: 0.10
Nodes (24): NetworkProvider, Error, Result, Target, URLRequest, Void, Result, NetworkError (+16 more)

### Community 16 - "Network Provider Lifecycle"
Cohesion: 0.19
Nodes (12): NetworkProviderTests, ProviderTarget, InMemoryNetworkTransport, Data, URLRequest, URLResponse, NetworkEventRecorder, RecordedNetworkContextEvent (+4 more)

### Community 17 - "Network Stub Execution"
Cohesion: 0.13
Nodes (16): StubResponse, Data, Int, .sampleResponse, NetworkProviderStubTests, SampleResponseRecorder, .readCount, SleepCallRecorder (+8 more)

### Community 18 - "App State Store"
Cohesion: 0.13
Nodes (12): AppStateStore, Sendable, throws, IAppStateStorage, AppStateStoreTests, AppStateStorageSpy, .currentData, .loadCallCount (+4 more)

### Community 19 - "App Flow Transitions"
Cohesion: 0.10
Nodes (20): AppFlow, authentication, main, maintenance, onboarding, AppFlowRouter, .flow, AppFlowHistoryAction (+12 more)

### Community 20 - "Database Store Configuration"
Cohesion: 0.10
Nodes (15): LocalDatabaseContainerFactories, LocalDatabaseStoreConfiguration, LocalDatabaseStoreLocationResolver, LocalDatabaseContainerFactory, URL, DirectoryCreationRecorder, .urls, LocalDatabaseStoreConfigurationTests (+7 more)

### Community 21 - "Generic SwiftData Operations"
Cohesion: 0.17
Nodes (13): SwiftDataLocalStoreBatchTests, Int, Range, String, SwiftDataLocalStoreGenericModelTests, testRecord(), testRecords(), makeGenericDatabase() (+5 more)

### Community 22 - "Core Application Infrastructure"
Cohesion: 0.07
Nodes (4): Logger, Logger, Foundation, OSLog

### Community 23 - "App Flow Coordinator"
Cohesion: 0.12
Nodes (16): ContentView, AppFlowActionResult, applied, rejected, unchanged, Bool, AppFlowCoordinator, Bool (+8 more)

### Community 24 - "Database Service Validation"
Cohesion: 0.19
Nodes (14): expectCancellation(), expectInitializationFailure(), expectValidation(), LocalDatabaseServiceTests, Int, String, Void, LocalDatabaseContainerFactoryRecorder (+6 more)

### Community 25 - "SwiftData Store Mutations"
Cohesion: 0.18
Nodes (13): LocalDatabaseStoreHooks, throws, Void, Bool, Error, Int, Model, ModelContainer (+5 more)

### Community 26 - "Screen Route Definitions"
Cohesion: 0.08
Nodes (26): BrowseSheetRoute, .id, options, Self, HomeAlertRoute, resetNavigation, HomeRoute, details (+18 more)

### Community 27 - "Persisted Flow Policy"
Cohesion: 0.14
Nodes (11): AppState, Bool, Int, AppFlowPolicy, AppFlowCoordinatorTests, CoordinatorSUT, makeSUT(), StorageError (+3 more)

### Community 28 - "Navigation Guide Flow"
Cohesion: 0.10
Nodes (12): NavigationGuideItem, String, GuideTopicView, .body, GuideTopicViewModel, NavigationGuideRoute, topic, NavigationGuideView (+4 more)

### Community 29 - "UserDefaults Encoded Values"
Cohesion: 0.08
Nodes (25): Bool, Data, Int, String, UserDefaultsEncodedValue, bool, data, date (+17 more)

### Community 30 - "Generic Database Test Models"
Cohesion: 0.15
Nodes (14): makeGenericInMemoryLocalDatabaseContainer(), makeGenericTestConfiguration(), makeGenericTestRegistry(), StoredTestLocalRecord, Bool, Int, ModelContainer, ModelContext (+6 more)

### Community 31 - "Navigation and DI Designs"
Cohesion: 0.08
Nodes (29): AppFlow, AppRouter, Apple NavigationSplitView Documentation, Apple NavigationStack Documentation, Apple: Enhancing Your App Content with Tab Navigation, Multiplatform Navigation Design, Native Adaptive SwiftUI Navigation, NavigationIntent (+21 more)

### Community 32 - "SwiftData Query Operations"
Cohesion: 0.17
Nodes (9): ExampleQuery, Int, String, ExampleRecord, String, ExampleLocalModelTests, SwiftDataLocalStoreQueryTests, makeInMemoryLocalStore() (+1 more)

### Community 33 - "Example Remote Service"
Cohesion: 0.10
Nodes (17): ExampleRequest, Int, String, ExampleResponse, String, ExampleTarget, .baseURL, fetch (+9 more)

### Community 34 - "Architecture and Release Docs"
Cohesion: 0.11
Nodes (28): App-Private Keychain Storage Path, AppFlowPolicy Root Selection, Architecture, AppTemplateApp Composition Root, Foundation Network Pipeline, Scene Navigation and Restoration, Typed SwiftData Local Store, Customization (+20 more)

### Community 35 - "Keychain Codable Conveniences"
Cohesion: 0.15
Nodes (9): KeychainConvenienceTests, KeychainServiceSpy, Bool, Data, Int, Sendable, Void, FirstSecret (+1 more)

### Community 36 - "Security Executor Query Tests"
Cohesion: 0.16
Nodes (20): BooleanEvidence, normalizeIdentity(), normalizeMutationAttributes(), QuerySnapshot, RawDictionary, SecurityCall, .booleanEvidence, .kind (+12 more)

### Community 37 - "Adaptive App Shell"
Cohesion: 0.09
Nodes (19): .body, AppSectionContentView, .body, AppShellView, .body, AdaptiveTabAppShellView, .body, MacSidebarAppShellView (+11 more)

### Community 38 - "App Sections and Intents"
Cohesion: 0.08
Nodes (24): .accessibilityIdentifier, .localizedTitle, .presentationIdentifier, .systemImage, LocalizedStringResource, String, NavigationSnapshotV2, NavigationSnapshotV3 (+16 more)

### Community 39 - "Projects and About Screens"
Cohesion: 0.13
Nodes (9): IFlowRouter, ProjectsView, .body, ProjectsViewModel, AboutView, .body, AboutViewModel, ProjectsViewModelTests (+1 more)

### Community 40 - "Network Monitoring Context"
Cohesion: 0.10
Nodes (18): NetworkTarget, .headers, .sampleResponse, .task, .validation, NetworkRequestContext, URLRequest, UUID (+10 more)

### Community 41 - "Database Adapter Validation"
Cohesion: 0.12
Nodes (15): LocalDatabaseValidationError, batchTooLarge, duplicateID, emptyID, invalidLimit, unregisteredModel, Int, LocalDatabaseValidator (+7 more)

### Community 42 - "Database Service Persistence"
Cohesion: 0.18
Nodes (13): LocalDatabaseError, initialization, read, validation, write, String, LocalDatabaseService, Bool (+5 more)

### Community 43 - "Keychain Service Tests"
Cohesion: 0.26
Nodes (5): expectedSetOperations(), KeychainServiceTests, service(), assertRedacted(), ScriptedKeychainSecItemExecutor

### Community 44 - "Security Keychain Executor"
Cohesion: 0.14
Nodes (15): Add, KeychainSecurityAPI, requiredCFBoolean(), SecurityKeychainSecItemExecutor, Any, Bool, CFString, Data (+7 more)

### Community 45 - "Authentication Flow"
Cohesion: 0.16
Nodes (10): AnyObject, IAuthenticationActions, IAuthenticationCancellation, AuthenticationFlowView, .body, AuthenticationView, .body, AuthenticationViewModel (+2 more)

### Community 46 - "Settings Flow"
Cohesion: 0.14
Nodes (8): IAppInfoService, SettingsModel, String, SettingsView, .body, SettingsViewModel, SettingsViewModelTests, .settingsDependencies

### Community 47 - "Keychain Keys and Memory"
Cohesion: 0.17
Nodes (6): InMemoryKeychainService, Data, remove, InMemoryKeychainServiceTests, constructKeychainKeysFromNonisolatedContext(), KeychainKeyTests

### Community 48 - "UI Navigation Tests"
Cohesion: 0.23
Nodes (10): AppTemplateUITests, String, UInt, StaticString, TimeInterval, XCTest, XCTestCase, XCUIApplication (+2 more)

### Community 49 - "Project Task Domain"
Cohesion: 0.13
Nodes (12): ProjectItem, ID, String, ProjectTaskItem, Bool, ID, String, TaskDetailsView (+4 more)

### Community 50 - "Help and Quick Start"
Cohesion: 0.10
Nodes (13): content, AuthenticationHelpView, .body, AuthenticationHelpViewModel, QuickStartView, .body, QuickStartViewModel, .body (+5 more)

### Community 51 - "Navigation Snapshot Schema"
Cohesion: 0.12
Nodes (19): .snapshot, .snapshot, UUID, NavigationRestoration, NavigationRestorationFailure, corruptData, unsupportedSchema, NavigationRestorationResult (+11 more)

### Community 52 - "Network Request Adapters"
Cohesion: 0.15
Nodes (13): RequestAdapter, AppendingHeaderAdapter, CancellationCheckingAdapter, ExecutorPayload, makeHTTPTransport(), MismatchedNetworkErrorAdapter, Data, Int (+5 more)

### Community 53 - "Keychain Executor Test Doubles"
Cohesion: 0.15
Nodes (16): KeychainSecItemCopyResult, data, invalid, status, Data, OSStatus, ScriptedKeychainResponse, cancelCurrentTaskThenStatus (+8 more)

### Community 54 - "Test Fixture Errors"
Cohesion: 0.10
Nodes (21): EncodingErrorStub, failed, StorageError, failed, StubFixtureError, mismatchedPhase, unexpectedTransport, ProviderFixtureError (+13 more)

### Community 55 - "Reentrant Codable Fixtures"
Cohesion: 0.18
Nodes (10): CodableFixture, ReentrantDecodingFixture, ReentrantDecodingFixtureCallback, ReentrantEncodingFixture, Decoder, Encoder, Int, Void (+2 more)

### Community 56 - "Service and UI Hardening"
Cohesion: 0.13
Nodes (21): Canonical AppKit Persistence Isolation, Bounded Initial-Window Recovery, macOS UI-Test Window Isolation Implementation Plan, Throwing UI-Test Prerequisites, Browse-Tab Activation Helper, iPad UI Gate Stabilization Implementation Plan, Keychain Task 7 Evidence Matrix, Postcondition-Gated Bounded Retry (+13 more)

### Community 57 - "Launch Routes and Fixtures"
Cohesion: 0.11
Nodes (17): UITestRoot, authentication, .initialState, main, maintenance, onboarding, AuthenticationRoute, help (+9 more)

### Community 58 - "Deep Link Parsing"
Cohesion: 0.18
Nodes (8): Bundle, .firstRegisteredURLScheme, DeepLinkParser, Result, String, URL, DeepLinkParserTests, String

### Community 59 - "HTTP Header Handling"
Cohesion: 0.17
Nodes (9): Field, HTTPHeaders, .fields, Bool, String, HTTPURLResponse, HTTPHeadersTests, .headers (+1 more)

### Community 60 - "Keychain Key Validation"
Cohesion: 0.18
Nodes (11): KeychainComponent, KeychainValidationFailure, blankKey, blankService, nonpositiveSchemaVersion, nulKey, nulService, reservedSchemaMarker (+3 more)

### Community 61 - "Security Executor Verification"
Cohesion: 0.34
Nodes (7): makeExecutor(), add, copy, delete, update, SecurityCallRecorder, SecurityKeychainSecItemExecutorTests

### Community 62 - "Database Operation Hooks"
Cohesion: 0.12
Nodes (15): LocalDatabaseReadOperation, fetchMany, fetchOne, LocalDatabaseWriteOperation, deleteAll, deleteOne, upsertBatch, upsertOne (+7 more)

### Community 63 - "Keychain Codec Test Models"
Cohesion: 0.14
Nodes (12): CancellingCodecSecret, FailingDecodeSecret, FailingEncodeSecret, SecondSecret, SentinelCodecError, .errorDescription, Bool, Decoder (+4 more)

### Community 64 - "UserDefaults Recording Support"
Cohesion: 0.16
Nodes (10): RawOperation, object, remove, set, Any, Bool, Set, String (+2 more)

### Community 65 - "Model Ownership Architecture"
Cohesion: 0.12
Nodes (18): Purpose-Driven Folder Architecture Design, Purpose-Driven Feature-First Hierarchy, Compile-Safe Reserved Extension Points, Tests Mirror Production Ownership, Uniform Feature Scaffold, Central Role-Based Model Ownership, Screen Capsule and Service-Only Architecture Design, Screen Capsule (+10 more)

### Community 66 - "Maintenance Flow"
Cohesion: 0.17
Nodes (7): IMaintenanceActions, MaintenanceFlowView, .body, MaintenanceView, .body, MaintenanceViewModel, MaintenanceViewModelTests

### Community 67 - "Keychain Service Actor"
Cohesion: 0.23
Nodes (7): KeychainSecItemExecuting, KeychainService, Bool, Data, OSStatus, String, Security

### Community 68 - "Keychain Service Errors"
Cohesion: 0.12
Nodes (17): KeychainServiceError, authenticationFailed, concurrentMutation, dataTooLarge, decodingFailed, encodingFailed, interactionCancelled, interactionNotAllowed (+9 more)

### Community 69 - "Example Record Adapter"
Cohesion: 0.21
Nodes (7): ExampleRecordAdapter, Bool, Entity, Int, ModelContext, String, Void

### Community 70 - "Browse Flow Navigation"
Cohesion: 0.19
Nodes (6): BrowseFlowView, .body, BrowseView, .body, BrowseListViewModel, BrowseListViewModelTests

### Community 71 - "Home Details Navigation"
Cohesion: 0.16
Nodes (8): HomeDetailsView, .body, HomeDetailsViewModel, EmptyStateView, .body, LocalizedStringResource, String, HomeDetailsViewModelTests

### Community 72 - "Keychain Copy Result Normalization"
Cohesion: 0.15
Nodes (11): FakeCopyResult, data, mutableData, none, string, MutableCFDataSource, Data, OSStatus (+3 more)

### Community 73 - "Scene Navigation Persistence"
Cohesion: 0.13
Nodes (11): App, AppTemplateApp, .body, AppSceneNavigationPersistencePolicy, .allowsSnapshotPersistence, ephemeral, restored, Bool (+3 more)

### Community 74 - "Tab Accessibility Identifiers"
Cohesion: 0.22
Nodes (9): InstallerViewController, Bool, Set, TabAccessibilityIdentifierInstaller, TabAccessibilityIdentifierInstallerTests, Context, UITabBarController, UIViewController (+1 more)

### Community 75 - "Onboarding Completion Flow"
Cohesion: 0.18
Nodes (7): IOnboardingActions, OnboardingFlowView, .body, OnboardingView, .body, OnboardingViewModel, OnboardingViewModelTests

### Community 76 - "Concurrent Keychain Operations"
Cohesion: 0.23
Nodes (9): ConcurrentKeychainSecItemExecutor, Data, OSStatus, String, ScriptedKeychainOperation, add, copy, delete (+1 more)

### Community 77 - "Navigation Router Test Spies"
Cohesion: 0.12
Nodes (7): ProjectDetailsRouterSpy, Route, ProjectsRouterSpy, Route, AboutRouterSpy, Route, LocalOnlyRouterSpy

### Community 78 - "Application Flow Routing"
Cohesion: 0.14
Nodes (5): SessionInfoView, .body, SessionInfoViewModel, SessionInfoViewModelTests, Observation

### Community 79 - "Flow Router Commands"
Cohesion: 0.21
Nodes (5): FlowRouter, Bool, NavigationPath, ProjectsFlowView, .body

### Community 81 - "Typed Keychain Keys"
Cohesion: 0.20
Nodes (8): Bool, String, Value, Bool, KeychainCodableKey, .rawKey, KeychainKey, keychainCodableTypeMismatch()

### Community 82 - "Platform Details Screen"
Cohesion: 0.18
Nodes (9): AppPlatform, iOS, iPadOS, macOS, .localizedTitle, PlatformDetailsView, LocalizedStringResource, PlatformDetailsViewModel (+1 more)

### Community 83 - "Generic Database Contract"
Cohesion: 0.20
Nodes (6): GenericNoOpDatabase, LocalDatabaseContractTests, requireModelAssociation(), Bool, Int, Model

### Community 84 - "Network Layer Hardening"
Cohesion: 0.16
Nodes (15): URLSession Network Layer Implementation Plan, NetworkProvider, Typed Network Request Pipeline, NetworkTarget, RemoteService and IRemoteService, StubBehavior, URLSessionTransport, Network Cancellation Boundaries (+7 more)

### Community 85 - "App State Persistence Results"
Cohesion: 0.16
Nodes (13): AppStateMutationResult, persisted, rejected, unchanged, AppStatePersistenceFailure, encodingFailed, loadFailed, saveFailed (+5 more)

### Community 86 - "Browse Options Scaffold"
Cohesion: 0.16
Nodes (9): State, failed, ready, uninitialized, LocalDatabaseContainerFactory, BrowseOptionsView, .body, BrowseOptionsViewModel (+1 more)

### Community 87 - "In-Memory App State Storage"
Cohesion: 0.33
Nodes (3): InMemoryAppStateStorage, Data, InMemoryAppStateStorageTests

### Community 88 - "Database Failure Diagnostics"
Cohesion: 0.28
Nodes (9): LocalDatabaseDiagnosticOperation, initialization, read, write, LocalDatabaseDiagnostics, LocalDatabaseFailureMetadata, Error, Int (+1 more)

### Community 89 - "SwiftData Schema Migration"
Cohesion: 0.18
Nodes (11): LocalDatabaseMigrationPlan, .schemas, .stages, LocalDatabaseSchemaV1, .models, StoredExampleRecord, String, MigrationStage (+3 more)

### Community 90 - "Project Details Navigation"
Cohesion: 0.26
Nodes (4): ProjectDetailsView, .body, ProjectDetailsViewModel, ProjectDetailsViewModelTests

### Community 91 - "Codable About Routes"
Cohesion: 0.18
Nodes (10): AboutRoute, CodingKeys, platform, PlatformCodingKeys, legacyName, platform, synthesizedPlatform, Decoder (+2 more)

### Community 92 - "App State Recovery"
Cohesion: 0.21
Nodes (10): AppStateLoadResolution, futureSchema, loaded, repair, AppStateRecoveryReason, corruptData, invalidValue, unsupportedSchema (+2 more)

### Community 93 - "Launch Configuration Modes"
Cohesion: 0.27
Nodes (6): AppLaunchConfiguration, live, .sceneNavigationPersistencePolicy, uiTesting, AppLaunchConfigurationTests, String

### Community 94 - "HTTP Method Modeling"
Cohesion: 0.17
Nodes (9): HTTPMethod, delete, get, head, patch, post, put, URL (+1 more)

### Community 95 - "App Settings Screen"
Cohesion: 0.21
Nodes (6): AppSettingsModel, String, AppSettingsView, .body, AppSettingsViewModel, AppSettingsViewModelTests

### Community 96 - "Keychain Retry Cancellation"
Cohesion: 0.20
Nodes (6): Int, ScriptedKeychainCallBarrier, CheckedContinuation, Int, Never, Void

### Community 97 - "App Shell Hardening Plans"
Cohesion: 0.21
Nodes (12): Application Graph and Scene-Local Navigation Scope, Deterministic UI-Test Composition, AppTemplate Hardening Implementation Plan, NavigationSnapshot Schema 4, Portable Build and Replaceable Resources, Safe AppState Persistence, AdaptiveTabAppShellView, AppSection Presentation Metadata (+4 more)

### Community 98 - "Generic SwiftData Architecture"
Cohesion: 0.23
Nodes (12): SwiftData Local Service Implementation Plan, ILocalDatabaseService, LocalDatabaseService Actor, Operation-Scoped SwiftData Persistence, SwiftDataLocalStore ModelActor, VersionedSchema V1, Generic Local Database Implementation Plan, Generic ILocalDatabaseService (+4 more)

### Community 99 - "App State Load Results"
Cohesion: 0.18
Nodes (7): Data, AppStateStorageLoadResult, data, invalidValue, missing, Data, Error

### Community 100 - "Network Request Bodies"
Cohesion: 0.20
Nodes (8): NetworkBody, data, json, Data, Encodable, String, Target, URLRequest

### Community 102 - "Database Concurrency Test Control"
Cohesion: 0.25
Nodes (8): ControlledLocalDatabaseOperationStart, resultOfChildTask(), resultOfPreCancelledChildTask(), CheckedContinuation, Never, Result, Value, Void

### Community 103 - "UserDefaults Physical Kind Fixtures"
Cohesion: 0.18
Nodes (11): UserDefaultsTestPhysicalKind, array, bool, data, date, dictionary, float32, float64 (+3 more)

### Community 104 - "HTTP Status Validation"
Cohesion: 0.22
Nodes (8): StatusCodeValidation, none, range, successful, successfulAndRedirects, Bool, Int, Range

### Community 105 - "Local Entity Adapters"
Cohesion: 0.29
Nodes (8): LocalEntityAdapter, .adapterIdentifier, .entityIdentifier, .valueIdentifier, Entity, ObjectIdentifier, Value, SendableMetatype

### Community 106 - "Project Info Sheet"
Cohesion: 0.24
Nodes (4): ProjectInfoView, .body, ProjectInfoViewModel, ProjectInfoViewModelTests

### Community 107 - "UserDefaults Native Type Tests"
Cohesion: 0.20
Nodes (9): NativeExpectation, bool, data, date, double, float, int, string (+1 more)

### Community 108 - "UserDefaults Invalid Representation Tests"
Cohesion: 0.20
Nodes (10): WrongRepresentationSeed, array, bool, data, date, dictionary, double, float (+2 more)

### Community 109 - "Controlled Network Request Tests"
Cohesion: 0.27
Nodes (8): controlledRequest(), ControlledRequestStart, CheckedContinuation, Error, Never, Result, Target, Void

### Community 110 - "About Route Compatibility"
Cohesion: 0.33
Nodes (3): platform, AboutRouteTests, String

### Community 111 - "Keychain Executor Cancellation Tests"
Cohesion: 0.33
Nodes (3): QueuedExecutorCallStart, SecurityClosureGate, .didTimeOut

### Community 112 - "Database Registry Identity Tests"
Cohesion: 0.22
Nodes (8): IdentityA, IdentityB, IdentityC, IdentityD, IdentityE, IdentityF, IdentityG, IdentityH

### Community 113 - "Precancelled Database Operation Tests"
Cohesion: 0.25
Nodes (8): LocalDatabasePreCancelledInvocation, deleteAll, deleteOne, fetchMany, fetchOne, .testDescription, upsertBatch, upsertOne

### Community 114 - "HTTP Header Mapping Tests"
Cohesion: 0.36
Nodes (6): AnyHashable, Any, SyntheticHTTPURLResponse, .allHeaderFields, HTTPURLResponse, NSCoder

### Community 115 - "App Root Scene Persistence"
Cohesion: 0.29
Nodes (6): .body, AppRootView, AppSceneView, .appFlowRouter, .body, Data

### Community 116 - "Loadable UI State"
Cohesion: 0.25
Nodes (7): LoadableState, empty, failed, idle, loading, Content, Failure

### Community 117 - "URLSession Transport"
Cohesion: 0.29
Nodes (5): Data, URLRequest, URLResponse, URLSessionTransport, URLSession

### Community 118 - "Project Basics Routing"
Cohesion: 0.25
Nodes (4): ProjectBasicsRoute, options, ProjectBasicsRouterSpy, Route

### Community 119 - "Project Options Routing"
Cohesion: 0.25
Nodes (4): ProjectOptionsRoute, review, ProjectOptionsRouterSpy, Route

### Community 120 - "Recorded Network Outcomes"
Cohesion: 0.25
Nodes (8): RecordedNetworkOutcome, cancelled, nonHTTPResponse, otherFailure, success, transportFailure, unacceptableStatus, Int

### Community 121 - "App-Private Storage Designs"
Cohesion: 0.32
Nodes (8): activateTab Bounded Postcondition Retry, iPad UI Gate Stabilization Design, App-Private Keychain Service Design, IKeychainService, KeychainService, and SecItem Executor, Versioned Keys, Bounded Set, and App-Private Data Protection Policy, IUserDefaultsService, UserDefaultsKey, and UserDefaultsService, Typed UserDefaults Service Design, UserDefaultsAppStateStorage Byte Compatibility

### Community 122 - "Settings Routes and Sheets"
Cohesion: 0.29
Nodes (6): SettingsRoute, about, SettingsSheetRoute, .id, sessionInfo, Self

### Community 123 - "Main Actor Network Liveness"
Cohesion: 0.48
Nodes (3): MainActorLivenessGate, .wasReleasedBeforeDeadline, Bool

### Community 124 - "Application Flow Architecture"
Cohesion: 0.33
Nodes (7): AppFlowRouter, AppRouter, and FlowRouter Composition, Global App Flow Router Design, Navigation-First App Shell and ViewModel Contract, Navigation-Only App Shell Design, AppState, AppFlowPolicy, and AppFlowCoordinator, AppStateStore and UserDefaultsAppStateStorage, Persisted App State and Flow Coordination Design

### Community 125 - "Network Layer Design"
Cohesion: 0.33
Nodes (7): NetworkTarget, NetworkProvider, and NetworkTransport Pipeline, RequestAdapter, NetworkEventMonitor, and NetworkResponse, URLSession Network Layer Design, HTTPHeaders, Provider Cancellation, and NetworkRequestContext, Network Layer Hardening Design Addendum, Local-Only Verification Model, Remove Hosted CI Automation Design

### Community 126 - "Network Stub Behavior"
Cohesion: 0.33
Nodes (5): StubBehavior, delayed, immediate, never, Duration

### Community 127 - "Network Response Decoding"
Cohesion: 0.47
Nodes (3): makeResponse(), NetworkResponseTests, Data

### Community 128 - "Generic SwiftData Design"
Cohesion: 0.47
Nodes (6): ExampleRecord, LocalDatabaseSchemaV1, and Versioned Persistence, LocalDatabaseService and SwiftDataLocalStore, SwiftData Local Service Design, Generic ILocalDatabaseService and LocalDatabaseModel, Generic SwiftData Local Database Design, LocalEntityAdapter, Model Registry, and Versioned SwiftData Engine

### Community 129 - "UserDefaults Service Errors"
Cohesion: 0.40
Nodes (4): UserDefaultsServiceError, decodingFailed, encodingFailed, invalidStoredValue

### Community 130 - "Injected Database Service Tests"
Cohesion: 0.40
Nodes (3): Bool, Int, Model

### Community 132 - "Keychain Security Call Kinds"
Cohesion: 0.40
Nodes (5): SecurityCallKind, add, copy, delete, update

### Community 133 - "Neutral Model Examples"
Cohesion: 0.40
Nodes (5): Neutral Local and Remote Model Examples Design, ExampleQuery, ExampleRecord, ExampleRequest and ExampleResponse, Neutral Model Independence

### Community 134 - "Deep Link Errors"
Cohesion: 0.50
Nodes (3): DeepLinkError, unknownDestination, unsupportedScheme

### Community 135 - "In-Memory Keychain Invocations"
Cohesion: 0.50
Nodes (4): InMemoryInvocation, read, set, CaseIterable

### Community 136 - "Hierarchical Navigation Plans"
Cohesion: 0.50
Nodes (4): Multiplatform Navigation Implementation Plan, Scene-Scoped Typed Navigation, Hierarchical Flow Navigation Implementation Plan, Reusable FlowRouter

### Community 137 - "App Shell Hardening Designs"
Cohesion: 0.50
Nodes (4): AppTemplate Hardening Design, Failure-Safe Persistence, Focused Navigation Capabilities, and Snapshot Schema 4, AppShellView Platform Adapters and Shared Section Content, Cross-Platform App Shell Design Addendum

### Community 147 - "Hierarchical Flow Navigation"
Cohesion: 1.00
Nodes (3): FlowRouter and Independent Navigation Flows, Hierarchical Flow Navigation Design, Screen-Owned Route and Destination Ownership

## Knowledge Gaps
- **439 isolated node(s):** `loaded`, `repair`, `futureSchema`, `invalidValue`, `corruptData` (+434 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **70 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Core Application Infrastructure` to `Typed UserDefaults Keys`, `Application Dependency Composition`, `Network Request Building`, `Feature Dependency Scaffolds`, `Test Suite Inventory`, `App State Persistence`, `Scene Router Behavior`, `Network Response Handling`, `Network Provider Lifecycle`, `Network Stub Execution`, `App Flow Transitions`, `Project Configuration Tests`, `Generic SwiftData Operations`, `Persisted Flow Policy`, `UserDefaults Encoded Values`, `Generic Database Test Models`, `Example Remote Service`, `Security Executor Query Tests`, `App Sections and Intents`, `Network Monitoring Context`, `Keychain Service Tests`, `Security Keychain Executor`, `Keychain Keys and Memory`, `Navigation Snapshot Schema`, `Network Request Adapters`, `Reentrant Codable Fixtures`, `Deep Link Parsing`, `Keychain Service Actor`, `Scene Navigation Persistence`, `Application Flow Routing`, `Typed Keychain Keys`, `App State Persistence Results`, `In-Memory App State Storage`, `Database Failure Diagnostics`, `App State Recovery`, `App State Load Results`, `Network Request Bodies`, `Local Database Test Suite`, `Controlled Network Request Tests`, `URLSession Transport`, `Network Stub Behavior`, `Network Response Decoding`?**
  _High betweenness centrality (0.058) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `Test Suite Inventory` to `Create Project Flow`, `Home Navigation Flow`, `Tab Accessibility Metadata`, `Browse Related Navigation`, `Project Configuration Tests`, `Core Application Infrastructure`, `App Flow Coordinator`, `Navigation Guide Flow`, `Adaptive App Shell`, `Projects and About Screens`, `Authentication Flow`, `Settings Flow`, `Project Task Domain`, `Help and Quick Start`, `Navigation Snapshot Schema`, `Maintenance Flow`, `Browse Flow Navigation`, `Home Details Navigation`, `Onboarding Completion Flow`, `Application Flow Routing`, `Flow Router Commands`, `Preview Composition Fixtures`, `Platform Details Screen`, `Browse Options Scaffold`, `Project Details Navigation`, `App Settings Screen`, `Project Info Sheet`, `App Root Scene Persistence`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Why does `RecordingUserDefaults` connect `Typed UserDefaults Service` to `UserDefaults Recording Support`, `App State Persistence`, `Feature Dependency Scaffolds`, `Reentrant Codable Fixtures`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **What connects `loaded`, `repair`, `futureSchema` to the rest of the system?**
  _439 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Navigation Snapshot Restoration` be split into smaller, more focused modules?**
  _Cohesion score 0.11170212765957446 - nodes in this community are weakly interconnected._
- **Should `Screen Models and States` be split into smaller, more focused modules?**
  _Cohesion score 0.041666666666666664 - nodes in this community are weakly interconnected._
- **Should `Typed UserDefaults Keys` be split into smaller, more focused modules?**
  _Cohesion score 0.07770582793709528 - nodes in this community are weakly interconnected._