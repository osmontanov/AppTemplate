# Persisted App State and Flow Coordination Design

Date: 2026-07-30
Status: Approved design; awaiting written-spec review

> Supersession note: This design supersedes the dependency-graph, initial-root,
> authentication-demonstration, persistence prohibition, and `signIn` /
> `signOut` structural-guard sections of the
> [Navigation-Only App Shell Design](2026-07-30-navigation-only-app-shell-design.md).
> The application remains navigation-first, but now includes one deliberately
> small persisted-state example for root-flow policy. It does not introduce
> real authentication, credentials, tokens, networking, or database behavior.

## Context

The app currently owns one shared `AppFlowRouter` and one scene-local
`AppRouter` per window. This correctly gives every macOS and iPadOS window the
same root flow while preserving independent tab selections, navigation paths,
snapshots, and pending deep links.

Root-flow changes are currently navigation-only:

- Authentication `Continue` calls `setFlow(.main)`;
- Settings `Sign Out` calls `setFlow(.authentication)`;
- Home opens Onboarding and Maintenance with direct root transitions;
- Onboarding and Maintenance return directly to Main.

No durable fact explains those flows, so relaunching always starts in
Authentication. Persisting the last `AppFlow` value directly would make
transient navigation the source of truth and would not model authentication,
onboarding, or maintenance policy independently.

## Goals

- Persist whether the user is authenticated.
- Persist whether onboarding has been completed.
- Persist whether maintenance mode is enabled.
- Derive the root `AppFlow` deterministically from those facts.
- Keep `AppFlowRouter` a pure navigation mechanism.
- Coordinate persistent facts and root transitions through a separate
  app-scoped `AppFlowCoordinator`.
- Let screen ViewModels invoke semantic commands through their existing
  initializer-injected router.
- Keep raw `setFlow(_:)` available for temporary navigation without changing
  persistent state.
- Share application state and root transitions across every window.
- Preserve independent scene navigation histories and snapshots.
- Add a versioned `UserDefaults` adapter that stores no secrets.
- Keep the API synchronous and comfortable for screen ViewModels.

## Non-goals

- Implement real authentication or authorization.
- Store access tokens, refresh tokens, passwords, credentials, or personal
  data in `UserDefaults`.
- Connect `LocalDatabaseService` or `RemoteService` to application state.
- Persist `AppFlow`, `AppFlowTransition`, pending deep links, or scene paths in
  the app-state record.
- Merge per-window navigation histories.
- Observe arbitrary external `UserDefaults` mutations while the app is
  running.
- Add a production in-memory storage implementation.
- Replace the existing route, sheet, alert, deep-link, or snapshot design.

## Considered Approaches

### 1. Persist the last `AppFlow`

This is small but conflates durable facts with presentation. It cannot explain
whether Main was selected because onboarding was completed, authentication
was valid, or maintenance was disabled. It also makes temporary
`setFlow(_:)` calls unexpectedly durable.

### 2. Let `AppFlowRouter` own persistence

This keeps composition small, but makes a navigation primitive responsible
for policy and storage. Direct `setFlow(_:)` would become ambiguous: it might
mean either a temporary transition or a persistent state mutation.

### 3. Separate state store and flow coordinator — selected

`AppStateStore` owns versioned persistent facts. `AppFlowRouter` owns root
navigation. `AppFlowCoordinator` exposes semantic commands, mutates the store,
derives the target flow, and asks the router to transition only when needed.

This preserves clear ownership, explicit dependency injection, deterministic
tests, and a raw non-persistent navigation escape hatch.

## State Model

The persisted model is a value type under `App/Models/State`:

```swift
nonisolated
struct AppState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var isAuthenticated: Bool
    var hasCompletedOnboarding: Bool
    var isMaintenanceEnabled: Bool
}
```

The initial state is:

```swift
AppState(
    schemaVersion: AppState.currentSchemaVersion,
    isAuthenticated: false,
    hasCompletedOnboarding: false,
    isMaintenanceEnabled: false
)
```

`AppState` is the source of truth for facts. It remains independent of the
Navigation layer and neither stores nor returns an `AppFlow`.

## Root-Flow Resolution

`AppFlowPolicy` is a pure, navigation-owned resolver that consumes an
`AppState` and returns an `AppFlow`. `AppFlowCoordinator` invokes this policy;
the persisted model does not depend on navigation types.

The selected precedence is:

1. Onboarding;
2. Authentication;
3. Maintenance;
4. Main.

The resolver is equivalent to:

```swift
if !hasCompletedOnboarding {
    return .onboarding
}
if !isAuthenticated {
    return .authentication
}
if isMaintenanceEnabled {
    return .maintenance
}
return .main
```

This produces the following complete truth table:

| Onboarding complete | Authenticated | Maintenance enabled | Root flow |
| --- | --- | --- | --- |
| false | false | false | Onboarding |
| false | false | true | Onboarding |
| false | true | false | Onboarding |
| false | true | true | Onboarding |
| true | false | false | Authentication |
| true | false | true | Authentication |
| true | true | false | Main |
| true | true | true | Maintenance |

Persisting independent facts lets a lower-priority condition remain active.
For example, maintenance may be enabled while signed out: Authentication is
shown first, and Maintenance appears after the next successful sign-in.

## Storage Boundary

The storage contract is narrow and does not know navigation:

```swift
nonisolated
enum AppStateStorageLoadResult: Equatable, Sendable {
    case missing
    case data(Data)
    case invalidValue
}

nonisolated
protocol IAppStateStorage: Sendable {
    func load() -> AppStateStorageLoadResult
    func save(_ data: Data)
    func remove()
}
```

`UserDefaultsAppStateStorage` implements the contract with one stable,
namespaced key and an injected `UserDefaults` instance. The stored value is
JSON `Data`, and `schemaVersion` lives inside that data so future versions can
be decoded and migrated intentionally.

The typed load result deliberately distinguishes an absent key from an
existing value that is not `Data`. The adapter checks `object(forKey:)` before
returning `.missing`; an existing wrong-typed value returns `.invalidValue` and
is repaired like corrupt JSON.

The live dependency uses `UserDefaults.standard`. Tests inject an isolated
suite or a test-target spy. Production code does not include an
`InMemoryAppStateStorage`.

Only the three Boolean policy flags and schema version are stored. Real
credentials must use a separate Keychain-backed abstraction in a future
project.

## Store Responsibilities

`AppStateStore` is app-scoped and main-actor isolated. It:

- loads the record exactly once during composition;
- exposes a read-only current `AppState`;
- applies state mutations;
- skips encoding and saving when a mutation produces the same state;
- encodes and saves a changed state;
- never switches navigation flows.

Loading behavior is deterministic:

| Stored value | Result |
| --- | --- |
| Missing | Initial state |
| Valid current schema | Decoded state |
| Corrupt JSON | Log and reset to initial state |
| Existing non-Data value | Log and reset to initial state |
| Unsupported schema | Log and reset to initial state |

Invalid persisted data is replaced with a valid current-schema initial record
so repeated launches do not repeat the same recovery failure. Logs describe
the recovery category but never print stored payloads.

Schema handling must be centralized. Version 1 is the only supported schema
initially; future versions add explicit legacy DTOs and migrations rather than
loosening decoding.

Because JSON encoding of this fixed Boolean model is expected to succeed,
encoding failure is treated as an infrastructure fault: the app logs it and
continues with its in-memory state. Navigation remains usable, while the next
launch may return to the last successfully persisted state.

## Coordinator Responsibilities

`AppFlowCoordinator` is created once at application scope. It owns references
to:

- one `AppStateStore`;
- one pure `AppFlowRouter`.

It exposes the raw navigation operation plus semantic state operations:

```swift
@MainActor
protocol IAppFlowCoordinator: IAppFlowRouter {
    func completeOnboarding()
    func restartOnboarding()
    func signIn()
    func signOut()
    func setMaintenanceEnabled(_ isEnabled: Bool)
}
```

`setFlow(_:)` delegates directly to `AppFlowRouter` and never changes
`AppState`.

Each semantic command follows this algorithm:

1. Produce the requested next `AppState`.
2. Persist only if the state changed.
3. Resolve the target flow through `AppFlowPolicy`.
4. Compare the target with the router's current flow.
5. Request a policy transition when the flows differ.

An effective `signOut()` is the single exception to the last step. When it
changes `isAuthenticated` from true to false, it publishes a discard
transition even if a temporary raw transition already shows Authentication.
This makes the identity boundary clear and removes every scene's pending
intent. Repeating `signOut()` while already signed out and consistent remains
a no-op.

The state comparison and flow comparison are intentionally independent. If a
raw temporary transition moved the app away from the flow implied by
`AppState`, a semantic command must reconcile navigation even when its
requested flag already has the same value.

For example:

```text
Persisted facts: onboarding complete, authenticated, no maintenance
Resolved flow: Main
Temporary raw flow: Onboarding
Command: completeOnboarding()
Persistent write: none
Navigation result: Main
```

Repeated semantic commands in an already consistent state produce neither a
write nor a navigation reset.

## Semantic Command Contract

| Command | Persistent mutation | Resolved behavior |
| --- | --- | --- |
| `completeOnboarding()` | `hasCompletedOnboarding = true` | Authentication, Maintenance, or Main |
| `restartOnboarding()` | `hasCompletedOnboarding = false` | Onboarding |
| `signIn()` | `isAuthenticated = true` | Onboarding, Maintenance, or Main |
| `signOut()` | `isAuthenticated = false` | Onboarding or Authentication |
| `setMaintenanceEnabled(true)` | `isMaintenanceEnabled = true` | Onboarding, Authentication, or Maintenance |
| `setMaintenanceEnabled(false)` | `isMaintenanceEnabled = false` | Onboarding, Authentication, or Main |

`signOut()` changes only `isAuthenticated`. It preserves onboarding completion
and maintenance state.

## Router Composition

Local navigation remains protocol-based:

```swift
@MainActor
protocol IFlowRouter: AnyObject {
    func push<Route: NavigationRoute>(_ route: Route)
    func pop()
    func popToRoot()
}
```

The screen-facing composite contract becomes:

```swift
@MainActor
protocol IRouter: IFlowRouter, IAppFlowCoordinator {}
```

`FlowRouter` continues to own only its local `NavigationPath`. It receives an
`any IAppFlowCoordinator` and delegates `setFlow(_:)` and every semantic
command to it. A ViewModel therefore keeps one comfortable injected
dependency:

```swift
private let router: any IRouter
```

No ViewModel receives `AppStateStore`, `UserDefaults`, `AppDependencies`, or
the concrete coordinator.

`AppFlowRouter` continues conforming only to `IAppFlowRouter`; it does not gain
storage or semantic state responsibilities.

Live `FlowRouter` construction always receives the shared coordinator
explicitly. It must not create a hidden coordinator or storage fallback. Tests
use a test-target coordinator spy, and previews create an explicit preview
composition.

## Application and Window Ownership

The ownership graph is:

```text
AppTemplateApp
├── AppDependencies
│   ├── LocalDatabaseService
│   ├── RemoteService
│   └── UserDefaultsAppStateStorage
├── AppStateStore
└── AppFlowCoordinator
    └── AppFlowRouter
        ├── Window A
        │   └── AppRouter A
        │       └── scene-local FlowRouters and paths
        └── Window B
            └── AppRouter B
                └── scene-local FlowRouters and paths
```

`AppDependencies` gains `appStateStorage: any IAppStateStorage`. Its live,
preview, and test factories remain explicitly injectable. LocalDatabase and
Remote remain empty examples and are not connected to this feature.

The app constructs the store, coordinator, and router once. Every
`AppSceneView` receives the same concrete coordinator. The scene reads the
coordinator's concrete `AppFlowRouter` for observable root state and constructs
its own `AppSceneNavigationLifecycle` and `AppRouter`.

`AppRouter` receives both capabilities explicitly:

- the concrete shared `AppFlowRouter` for current-flow checks, transitions,
  and lifecycle observation;
- an `any IAppFlowCoordinator` delegate passed to every local `FlowRouter`.

This avoids widening the screen-facing protocol with observable root state and
prevents local routers from receiving only the raw router without semantic
commands.

Two windows therefore represent one user and one application policy state,
but retain independent selected sections, stack histories, snapshots, and
pending deep links.

## Cold Launch and Scene Restoration

Startup order is:

1. Construct dependencies.
2. Load `AppStateStore`.
3. Resolve the initial flow.
4. Construct `AppFlowRouter` directly with that flow.
5. Construct the shared coordinator.
6. Let each scene create its local routers and restore its snapshot.

The initial `AppFlowTransition` retains its existing `.preserve` history and
pending-intent actions. Hydration must not call public `setFlow(_:)`, because
that would publish an unnecessary reset and erase restorable scene paths.

On a non-Main cold launch, an old Main snapshot may be restored but remains
hidden. The next real semantic root transition resets it through the existing
history policy. Startup does not proactively erase a valid scene snapshot.

Persistent state is never hydrated from each scene's `.task`. Doing so would
repeat shared initialization and make every new window reset existing windows.

`NavigationSnapshot` remains scene-local and unchanged. It continues storing
the selected section and Main-flow paths only; it does not store application
state or root flow.

## ViewModel Integration

Existing screen actions change as follows:

```text
Authentication Continue
    router.signIn()

Authentication Cancel
    router.setFlow(.authentication)

Settings Sign Out
    router.signOut()

Onboarding Finish
    router.completeOnboarding()

Home Open Onboarding
    router.restartOnboarding()

Home Open Maintenance
    router.setMaintenanceEnabled(true)

Maintenance Return to App
    router.setMaintenanceEnabled(false)
```

This keeps screens declarative and ViewModels easy to test. The ViewModels
request user intent; they do not choose a root flow or mutate persistence.

Authentication Cancel deliberately remains a raw same-flow reset. It is not a
sign-out action and must not mutate an authenticated state when Authentication
was presented temporarily.

Raw `setFlow(_:)` remains available for demonstrations, previews, diagnostics,
and truly temporary root presentation. A raw transition is deliberately not
restored after relaunch.

## Transition, Deep-Link, and Multi-Window Semantics

Raw `AppFlowRouter.setFlow(_:)` preserves its current public contract:

- every real root change publishes a fresh transition identifier;
- all scene histories reset;
- entering Main replays the receiving scene's pending intent;
- entering a non-Main flow discards that scene's older pending intent.

Semantic policy transitions need one additional internal router operation so
a deferred deep link survives sequential gates. The operation still resets
history, but lets the coordinator choose the pending-intent action:

- a semantic transition to Main uses `.replay`;
- `completeOnboarding()`, `signIn()` into Maintenance, and other intermediate
  policy gates use `.preserve`;
- `signOut()` uses `.discard` because it is an explicit identity boundary;
- raw `setFlow(_:)` keeps using Main = `.replay`, non-Main = `.discard`.

This supports both important sequences:

```text
Deep link → Onboarding → Authentication → Main → replay
Deep link → Authentication → Maintenance → Main → replay
```

The internal transition operation is not added to `IAppFlowRouter` and is not
available to screen ViewModels. `AppFlowCoordinator` can use it because it owns
the concrete `AppFlowRouter`.

All windows observe the same transition identifier exactly once through their
own `AppSceneNavigationLifecycle`.

A command whose resolved target already equals the visible root normally does
not publish a transition. The effective sign-out boundary described above is
the only exception. This avoids needless recreation of every window and
distinguishes idempotent state commands from the intentionally reset-producing
raw `setFlow(_:)` API.

## Folder Placement

Production files are organized by purpose:

```text
App/
├── Models/
│   └── State/
│       └── AppState.swift
├── State/
│   ├── AppStateStore.swift
│   └── Storage/
│       ├── AppStateStorageLoadResult.swift
│       ├── IAppStateStorage.swift
│       └── UserDefaultsAppStateStorage.swift
└── Navigation/
    └── Routing/
        ├── AppFlowCoordinator.swift
        ├── AppFlowPolicy.swift
        └── IAppFlowCoordinator.swift
```

Exact grouping may follow the synchronized Xcode folder layout, but state
models, persistence infrastructure, and navigation coordination must remain
separate responsibilities.

## Testing

### AppState and AppFlowPolicy

- Verify current-schema round trips.
- Verify initial values and schema version.
- Verify `AppState` has no dependency on navigation types.
- Verify the policy's complete eight-row resolution truth table.

### AppStateStore and storage

- Missing data loads the initial state.
- Valid current data restores every flag.
- Corrupt data resets safely and saves exactly one current-schema initial
  record.
- An existing non-Data value resets safely and saves exactly one
  current-schema initial record.
- Unsupported schema resets safely and saves exactly one current-schema
  initial record.
- A second load after recovery reads the repaired record without repeating
  recovery.
- A changed state is encoded and saved once.
- An identical state does not save again.
- Recovery never logs or exposes payload contents.
- Storage adapter tests use an isolated `UserDefaults` suite and clean it up.
- Test doubles live only in the test target.

### AppFlowCoordinator

- Verify every semantic command changes only its specified flag.
- Verify every command resolves all relevant priority combinations.
- Verify `signOut()` preserves onboarding and maintenance.
- Verify a changed state with the same resolved flow persists without a root
  transition.
- Verify unchanged state with an inconsistent temporary flow reconciles
  navigation without writing.
- Verify unchanged and already-consistent state does nothing.
- Verify raw `setFlow(_:)` transitions without writing.
- Verify a deferred intent survives Onboarding → Authentication → Main.
- Verify a deferred intent survives Authentication → Maintenance → Main.
- Verify semantic entry to Main replays the pending intent.
- Verify `signOut()` and raw non-Main `setFlow(_:)` discard pending intents.
- Verify an effective sign-out discards pending intents even when a temporary
  raw transition already displays Authentication.

### ViewModels and scenes

- Verify each affected ViewModel calls its semantic command.
- Verify two scene routers share root transitions but not local paths.
- Verify scene restoration happens after root hydration without a startup
  reset.
- Keep existing sheet, alert, dialog, snapshot, route, and deep-link tests.

### Platform verification

- Run the complete macOS test suite.
- Run the complete iPhone simulator test suite.
- Run the complete iPad simulator test suite.
- Smoke-test cold launch and relaunch for Onboarding, Authentication, Main,
  and Maintenance.
- Confirm the Xcode project file changes only if synchronized groups require
  no manual membership updates; otherwise review any project-file change
  explicitly.

## Documentation Impact

The README and current architecture documentation must stop claiming that the
app always starts in Authentication or has no persistence at all. They should
describe this feature as persisted demo application policy:

- authentication is only a Boolean navigation example;
- no credentials or tokens are stored;
- real identity state requires an authentication client and Keychain;
- root flow is derived from facts rather than persisted directly.

The former structural guard forbidding the words `signIn` and `signOut` in
feature ViewModels is replaced with a responsibility-based guard. A feature
ViewModel may invoke router semantic commands, but may not:

- receive `AppStateStore`, storage, credentials, or authentication services;
- read or write `UserDefaults`;
- implement token, network, validation, retry, or session business logic;
- decide root-flow precedence itself.

## Acceptance Criteria

1. First launch starts in Onboarding.
2. Completing onboarding persists and opens Authentication while signed out.
3. Signing in persists `isAuthenticated == true` and opens Main unless
   Maintenance is enabled.
4. Signing out persists `isAuthenticated == false` without clearing the other
   flags.
5. Restarting Onboarding and enabling or disabling Maintenance persist their
   corresponding facts.
6. Relaunch derives the correct flow for every supported state combination.
7. Raw `setFlow(_:)` never changes persistent state.
8. Repeated semantic commands do not cause duplicate writes or root resets.
9. All windows share application state and root flow while retaining
   independent scene navigation.
10. Deferred deep links survive intermediate policy gates, replay on Main, and
    are discarded by sign-out or an explicit raw non-Main transition.
11. Scene snapshots, sheets, alerts, and dialogs retain their behavior.
12. No secrets are stored in `UserDefaults`.
13. LocalDatabase and Remote remain empty, unrelated examples.
14. macOS, iPhone, and iPad tests pass.
