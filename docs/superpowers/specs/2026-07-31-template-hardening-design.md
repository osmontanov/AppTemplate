# AppTemplate Hardening Design

**Status:** Draft for written-spec review. The architectural direction was
approved in conversation on 2026-07-31.

## Goal

Implement review roadmap items 2 through 13 as one coherent hardening pass while
preserving the existing navigation-first character of AppTemplate and its iOS
26, iPadOS 26, and macOS 26 deployment floors.

The result remains a reusable application template rather than a sample product.
It gains safer persistence and scene restoration, narrower navigation
capabilities, one complete dependency-injection path, portable project
configuration, Swift 6, adaptive/localizable SwiftUI examples, a native macOS
Settings scene, UI tests, and continuous integration.

## Explicit Scope

This design implements these selected review items:

2. Preserve unknown future app-state and navigation schemas.
3. Checkpoint applied root transitions in scene snapshots.
4. Make Authentication cancellation scene-local.
5. Remove raw `setFlow` from ViewModel-facing APIs.
6. Split stack, scene, and application-policy navigation capabilities.
7. Demonstrate one complete DI path from `AppDependencies` to a ViewModel.
8. Represent storage failures through throwing storage and typed results.
9. Give application state one coherent folder and synchronize tests/docs.
10. Remove personal project identity, add replaceable assets, improve repository
    hygiene, and document rename/release work.
11. Enable Swift 6 language mode.
12. Add deterministic previews, a String Catalog, Dynamic Type-safe layouts,
    and a native macOS Settings scene.
13. Add a cross-platform UI-test target and a macOS/iPhone/iPad CI matrix.

## Explicit Exclusions

- Do not add `PrivacyInfo.xcprivacy`; roadmap item 1 was explicitly excluded.
  The release checklist must state that App Store distribution remains blocked
  until the correct manifest is added.
- Do not relax or remove the existing per-screen scaffold convention; roadmap
  item 14 was explicitly excluded. New user-facing screens follow the existing
  View, ViewModel, Model, State, and Navigation folder structure.
- Do not implement real authentication, HTTP networking, database access, or
  project persistence.
- Do not introduce a service locator, runtime dependency registry, third-party
  dependency-injection framework, or global mutable dependency container.
- Do not extract features or navigation into Swift packages in this pass.

## Architectural Direction

The current app-versus-scene ownership remains intact:

```text
AppTemplateApp (application scope)
├── AppDependencies
├── AppStateStore
├── AppFlowCoordinator
└── AppFlowRouter
    └── WindowGroup
        └── AppSceneView (one per scene)
            ├── AppSceneNavigationLifecycle
            ├── AppRouter
            ├── per-flow FlowRouter values
            └── SceneStorage navigation snapshot
```

The hardening changes ownership boundaries, failure semantics, and injection
paths without replacing this structure.

## Application State Boundary

### Folder ownership

Move the complete application-state boundary from the misleading
`App/Services/AppStateStorageService` folder to:

```text
App/ApplicationState/
├── AppState.swift
├── AppStateStore.swift
├── Diagnostics/
│   └── AppStateLogger.swift
└── Persistence/
    ├── AppStateStorageLoadResult.swift
    ├── IAppStateStorage.swift
    ├── InMemoryAppStateStorage.swift
    └── UserDefaultsAppStateStorage.swift
```

`AppState` is application policy data, `AppStateStore` owns its mutation and
persistence rules, and `Persistence` contains only storage contracts/adapters.
Tests mirror this hierarchy under `AppTemplateTests/App/ApplicationState`.

### Storage contract

`IAppStateStorage` remains synchronous because the live implementation is a
small `UserDefaults` bootstrap record needed before the first root is selected.
Every operation becomes throwing:

```swift
nonisolated
protocol IAppStateStorage: Sendable {
    func load() throws -> AppStateStorageLoadResult
    func save(_ data: Data) throws
    func remove() throws
}
```

This boundary is not the future local database API. Database or remote work
remains asynchronous behind its own service.

### Persistence status and mutation result

`AppStateStore` exposes a typed status and never reports success before a
durable write succeeds:

```swift
nonisolated
enum AppStatePersistenceFailure: Equatable, Sendable {
    case loadFailed
    case saveFailed
    case encodingFailed
    case unsupportedFutureSchema(Int)
}

nonisolated
enum AppStatePersistenceStatus: Equatable, Sendable {
    case writable
    case readOnly(AppStatePersistenceFailure)
}

nonisolated
enum AppStateMutationResult: Equatable, Sendable {
    case unchanged
    case persisted
    case rejected(AppStatePersistenceFailure)
}
```

`setState(_:)` follows this order:

1. Return `.unchanged` for an identical value.
2. Reject immediately when persistence status is read-only.
3. Encode the proposed value.
4. Save it.
5. Mutate in-memory state only after save succeeds.
6. Return `.persisted`.

Encoding or save failure leaves both state and root flow unchanged. The store
becomes read-only for its lifetime and logs only the failure category, never
the payload. `persistenceStatus` is observable and read-only to consumers, so a
future product UI can disclose degraded persistence without gaining mutation
authority.

### Loading and recovery

- Missing data loads `.initial` in writable mode without writing.
- Invalid values and corrupt current-schema data recover to `.initial` and
  attempt one repair write.
- A schema lower than `AppState.currentSchemaVersion` also repairs to
  `.initial`; this pass defines no historical AppState migration because schema
  1 has no supported predecessor.
- A successful repair leaves the store writable. A failed repair keeps
  `.initial` in memory and makes the store read-only with the corresponding
  encoding or save failure.
- A failed load uses `.initial` in read-only `.loadFailed` mode.
- A schema version greater than `AppState.currentSchemaVersion` uses `.initial`
  in read-only `.unsupportedFutureSchema(version)` mode and does not write,
  remove, or alter the future payload.
- Semantic flow actions return a typed result and do not transition when the
  store rejects the mutation.

`IAppFlowCoordinator` semantic methods return this result, marked
`@discardableResult`, so current demo screens may ignore it while tests and
future product UI can react to persistence failure explicitly:

```swift
nonisolated
enum AppFlowActionResult: Equatable, Sendable {
    case unchanged
    case applied(flow: AppFlow, didTransition: Bool)
    case rejected(AppStatePersistenceFailure)
}
```

A rejected state mutation never creates a root transition. An unchanged state
may still produce `.applied(..., didTransition: true)` when infrastructure tests
have deliberately placed the concrete root router out of sync with policy;
production features cannot create that condition after raw flow replacement is
removed from their capabilities.

## Navigation Capabilities

### Capability protocols

Replace the broad ViewModel-facing `IRouter` contract with focused protocols:

```swift
@MainActor
protocol IFlowRouter: AnyObject {
    func push<Route: NavigationRoute>(_ route: Route)
    func pop()
    func popToRoot()
}

@MainActor
protocol IAuthenticationActions: AnyObject {
    @discardableResult func signIn() -> AppFlowActionResult
    @discardableResult func signOut() -> AppFlowActionResult
}

@MainActor
protocol IOnboardingActions: AnyObject {
    @discardableResult func completeOnboarding() -> AppFlowActionResult
    @discardableResult func restartOnboarding() -> AppFlowActionResult
}

@MainActor
protocol IMaintenanceActions: AnyObject {
    @discardableResult
    func setMaintenanceEnabled(_ isEnabled: Bool) -> AppFlowActionResult
}

@MainActor
protocol IAuthenticationCancellation: AnyObject {
    func cancelAuthentication()
}
```

`IAppFlowCoordinator` composes only the three semantic application-policy
protocols. `FlowRouter` conforms to local stack routing and the semantic action
protocols by delegating to the coordinator. Each ViewModel stores the narrowest
single protocol or protocol composition it requires.

The old `IRouter` and `IAppFlowRouter` protocols are removed.

### Raw flow replacement

`AppFlowRouter.setFlow(_:)` remains an infrastructure/test operation because
the transition model still needs explicit reset coverage. It is no longer:

- part of `IAppFlowCoordinator`;
- forwarded by `FlowRouter`;
- visible through any ViewModel initializer.

Production ViewModels can change root policy only through semantic actions.

### Scene-local Authentication cancellation

`AppRouter` conforms to `IAuthenticationCancellation`:

```swift
func cancelAuthentication() {
    authentication.popToRoot()
    pendingIntent = nil
}
```

`AuthenticationFlowView` receives the Authentication `FlowRouter` for its
`NavigationStack` and a narrow `IAuthenticationCancellation` collaborator.
`AuthenticationViewModel` receives `IFlowRouter`, `IAuthenticationActions`, and
`IAuthenticationCancellation`. Cancellation affects only the owning scene and
never emits an application-wide transition.

## Scene Snapshot Safety

### Schema 4

Increment `NavigationSnapshot.currentSchemaVersion` to 4 and add:

```swift
let lastAppliedTransitionID: UUID?
```

The snapshot continues to contain only scene-local navigation state; the UUID
is an event checkpoint, not persisted application policy.

### Restore behavior

- Schema 4 restores paths, selected section, and transition checkpoint.
- Schema 3 migrates all four current tab histories and starts without a
  checkpoint.
- Schema 2 migrates Home, Browse, and Settings with an empty Projects history.
- Corrupt current/known-old data resets and is replaced by a valid schema-4
  snapshot.
- A schema greater than 4 resets only in memory, returns a dedicated
  `preservedFutureSchema(version)` result, disables scene snapshot writes for
  that lifecycle, and leaves the stored future payload untouched.

`AppSceneNavigationLifecycle` exposes a snapshot containing its current
`lastAppliedTransitionID`. During restoration it loads the checkpoint before
applying the current transition. A matching transition is skipped, preventing a
previously applied reset from deleting navigation created afterward.

When future snapshot preservation disables persistence, subsequent pushes,
deep links, and root changes still work in memory for that scene but cannot
overwrite the future payload.

## Dependency Injection Vertical Slice

Add a small, deterministic `IAppInfoService` rather than inventing fake network
or database behavior:

```text
AppDependencies
└── SettingsDependencies
    └── IAppInfoService
        └── SettingsFlowView / macOS Settings scene
            └── SettingsViewModel / AppSettingsViewModel
```

The contract exposes immutable app display name and version information.
`AppInfoService` captures values from `Bundle` during initialization and then
stores only `Sendable` strings. Preview and test implementations provide fixed
values without reading the live bundle.

`AppDependencies` retains the empty `ILocalDatabaseService` and
`IRemoteService` examples. It adds `settings: SettingsDependencies` and passes
that feature scope explicitly through scene, root, shell, flow, view, and
ViewModel initializers. No ViewModel receives the complete app graph.

The Settings screen renders the injected app name/version, proving real
consumer-visible behavior rather than testing dependency identity alone.

## Project Portability and Resources

### Configurable identity

Create a checked-in template xcconfig defining:

```text
APP_BUNDLE_IDENTIFIER = com.example.AppTemplate
APP_URL_SCHEME = apptemplate
```

The application target uses `$(APP_BUNDLE_IDENTIFIER)` and the test targets use
derived `.tests` / `.uitests` identifiers. `Info.plist` expands bundle and URL
scheme values from these settings. Remove the original developer team from all
shared build configurations; adopters choose signing locally.

Configuration tests validate shape and registration behavior, not the original
developer's exact identity.

### Assets

Add a neutral, replaceable 1024×1024 AppTemplate icon and generate the required
macOS sizes from the same source artwork. The icon uses a simple geometric
navigation/architecture motif without text or product-specific branding.
Define a real system-adaptive accent color. Document both as replaceable
template resources.

### Repository hygiene

Expand `.gitignore` for Xcode user state, `.DS_Store`, local xcconfigs, build
artifacts, and common editor files. Remove tracked personal `xcuserdata` while
preserving the shared scheme.

Add current documentation:

- `docs/ARCHITECTURE.md`;
- `docs/CUSTOMIZATION.md`;
- `docs/RELEASE_CHECKLIST.md`;
- `docs/README.md` classifying old Superpowers specs/plans as historical.

README links only to current documentation for live architecture. Historical
plans remain available but are not presented as current instructions.

The release checklist explicitly records the intentionally unresolved privacy
manifest requirement.

## Swift 6

Set every application and test configuration to `SWIFT_VERSION = 6.0` while
retaining:

- approachable concurrency;
- default MainActor isolation;
- explicit `nonisolated` declarations for transferable value types;
- zero compiler warnings.

No deployment target changes are allowed.

## SwiftUI, Localization, and Previews

### String Catalog

Add `Resources/Localizable.xcstrings` with English source entries for all current
user-visible static strings. Replace concatenated runtime strings with complete
localizable resources. Reusable components that render static template copy
accept `LocalizedStringResource`. Truly dynamic values, including injected app
name and version, remain `String` and are rendered verbatim rather than treated
as localization keys.

Persisted routes carry stable identifiers, never localized display text. The
platform route changes from an arbitrary name string to a stable platform enum;
the destination derives its localized title at render time.

### Adaptive layouts

Fixed centered flows use a reusable `AdaptiveContentContainer` with vertical
scrolling and a maximum readable width. Authentication actions use
`ViewThatFits` to switch from horizontal to vertical layout. Onboarding,
Authentication, Authentication Help, Maintenance, Quick Start, Browse Options,
Guide Topic, and Platform Details remain usable at accessibility Dynamic Type
sizes and compact heights. Decorative SF Symbols are hidden from accessibility
when adjacent text already conveys their meaning.

### Deterministic previews

Add reusable preview fixtures backed by `InMemoryAppStateStorage` and fixed
`IAppInfoService` values. The production scene composition and every independent
flow root receive at least one deterministic preview. Existing UI component
previews remain isolated. No preview reads or writes `UserDefaults`, opens a
database, or performs network work.

### macOS Settings scene

Add a native `Settings` scene under `#if os(macOS)`. Its user-facing screen
follows the existing per-screen scaffold convention and displays injected app
metadata. The main Settings tab includes a native `SettingsLink` on macOS while
remaining unchanged in purpose on iOS/iPadOS. The Settings window owns no tab
navigation snapshot and does not create a second application coordinator.

## UI Tests and Continuous Integration

### Deterministic UI-test bootstrap

Add a small launch-configuration parser that recognizes UI-test-only launch
arguments and selects an in-memory initial `AppState`. Normal launches always
use `AppDependencies.live()` and `UserDefaultsAppStateStorage`.

Supported test roots are Onboarding, Authentication, Main, and Maintenance.
The parser is pure and unit tested. It never provides a production fallback to
test fixtures without the explicit UI-test argument.

### UI-test target

Add `AppTemplateUITests` for iOS/iPadOS and macOS. Tests exercise real app UI:

1. deterministic Onboarding launch;
2. deterministic Main launch and tab selection;
3. a pushed destination;
4. one sheet presentation and dismissal;
5. the macOS Settings scene by selecting the main Settings tab, activating the
   identified `SettingsLink`, and asserting the identified Settings window.

Views expose accessibility identifiers only at stable screen or interaction
boundaries. UI tests do not depend on localized display strings when a stable
identifier is available.

### CI matrix

Add one GitHub Actions workflow using the official `macos-26` Apple Silicon
runner and select `/Applications/Xcode_26.4.1.app`. The matrix runs the shared
scheme against these destinations, all present on that runner image:

- `platform=macOS`;
- `platform=iOS Simulator,OS=26.4,name=iPhone 17`;
- `platform=iOS Simulator,OS=26.4,name=iPad (A16)`.

The workflow fails on build warnings and test failures, uses fresh DerivedData
per matrix entry, and uploads xcresult bundles on failure. It prints the active
Xcode version and available destinations before testing, and passes
`SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` and `GCC_TREAT_WARNINGS_AS_ERRORS=YES` to
`xcodebuild`.

This pinned baseline follows GitHub's official
[`macos-26` image manifest](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)
and [GitHub-hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

## Testing Strategy

Every behavior change follows red-green-refactor.

Required regression coverage:

- future AppState data remains byte-for-byte unchanged;
- AppState save failure leaves state and flow unchanged;
- current/older corrupt state still repairs once;
- a scene recreated after transition `T` does not reapply `T`;
- future navigation snapshot remains byte-for-byte unchanged after in-memory
  navigation;
- schema 2 and 3 snapshots migrate to schema 4;
- Authentication cancellation affects only one scene;
- no ViewModel-facing protocol exposes raw `setFlow`;
- each ViewModel receives only required routing capabilities;
- app info travels from composition root to rendered Settings behavior;
- UI-test launch configuration cannot activate accidentally;
- localization resources compile on every platform;
- app and unit/UI tests compile in Swift 6;
- all macOS, iPhone, and iPad suites pass.

Configuration-only work is verified through builds, asset/catalog compilation,
archive inspection, and the CI workflow's actual commands rather than brittle
source-text assertions.

## Completion Criteria

The hardening pass is complete only when:

1. Every selected roadmap item 2–13 is implemented.
2. Excluded items 1 and 14 remain unimplemented.
3. No future-schema path overwrites unknown data.
4. No feature ViewModel can request raw root replacement.
5. Authentication cancellation is scene-local.
6. One consumer-visible service value reaches Settings through explicit DI.
7. The source and mirrored test folder ownership agree.
8. Swift 6 builds without warnings.
9. Unit and UI suites pass on macOS, iPhone, and iPad.
10. The repository has current customization and release instructions.
11. The final diff receives independent spec and code-quality review.
