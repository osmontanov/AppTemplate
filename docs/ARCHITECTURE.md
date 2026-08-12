# Architecture

## Ownership

`AppTemplateApp` is the composition root. At launch it chooses live or UI-test
dependencies, constructs one app-scoped `AppStateStore`, derives the required
root with `AppFlowPolicy`, and creates the shared `AppFlowCoordinator` and
`AppFlowRouter`. Every `WindowGroup` scene receives that shared application
policy but creates its own `AppSceneNavigationLifecycle` and `AppRouter`.

The main source boundaries are:

- `AppTemplate/App/Entry` — launch configuration and app composition.
- `AppTemplate/App/AppDependencies` — the explicit app dependency graph.
- `AppTemplate/App/ApplicationState` — persisted app policy and storage.
- `AppTemplate/App/Navigation` — root flows, per-scene routing, deep links,
  lifecycle, and snapshots.
- `AppTemplate/App/Models` and `AppTemplate/App/Services` — shared models and
  service contracts.
- `AppTemplate/Features/<Feature>` — feature dependencies, flow containers,
  and screen-owned Model, Navigation, State, View, and ViewModel files.
- `AppTemplate/Utilities/UIComponents` — reusable screen-independent views.
- `AppTemplate/Resources` — the property list, string catalog, and assets.

`AppTemplateTests` mirrors production ownership. `AppTemplateUITests` tests
the launch roots and user-visible navigation.

## Application state and root policy

`AppState` is schema 1. It persists only three demo facts:
`isAuthenticated`, `hasCompletedOnboarding`, and `isMaintenanceEnabled`.
`UserDefaultsAppStateStorage` stores its JSON data under
`AppTemplate.AppState`; it does not store credentials, tokens, navigation
paths, pending intents, or the selected root.

`AppStateStore` loads, validates, repairs, and saves this state. Corrupt or old
unsupported data is reset to `AppState.initial`; a future schema makes the
store read-only so newer data is not overwritten. `AppFlowPolicy` derives the
Onboarding, Authentication, Maintenance, or Main root from the saved facts.

This launch-policy state remains owned by `AppStateStore` and
`IAppStateStorage` in UserDefaults. The local SwiftData reference store does not
participate in root selection or startup restoration.

The typed persistence path is:

```text
UserDefaultsKey
  -> UserDefaultsService
  -> UserDefaultsAppStateStorage
  -> AppStateStore
```

`UserDefaultsKey<Data>.data("AppState")` supplies the fixed logical name and
raw-Data codec. The live `UserDefaultsService` supplies the stable
`AppTemplate` namespace, so the physical record remains exactly
`AppTemplate.AppState`. Existing bytes pass through
`UserDefaultsAppStateStorage` unchanged; AppState JSON encoding, schema
inspection, repair, and future-schema protection stay in `AppStateStore`.

`UserDefaultsService` is the one lock-confined raw UserDefaults boundary. Raw
reads and mutations are serialized, while typed codecs execute outside the
lock. The API is synchronous because root policy is needed during startup, but
a successful set or removal means Foundation accepted/enqueued the mutation,
not that it was fsynced to persistent media. Application-level "persisted"
results mean the synchronous storage boundary accepted the mutation before
in-memory policy changed. Secrets remain outside this path and require a
separate Keychain boundary.

### App-private Keychain storage

The Keychain path is deliberately narrow:

```text
IKeychainService
  -> KeychainService
  -> KeychainSecItemExecuting
  -> SecurityKeychainSecItemExecutor
```

`IKeychainService` is Data-first: its raw async contract reads, sets, and
Bool-removes `Data`; protocol conveniences add exact UTF-8 `String` handling
and direct-JSON, versioned `Codable & Sendable` values with fresh codecs.
`KeychainService` is one actor that owns cancellation, public status mapping,
and the bounded `update -> add -> update -> add` convergence sequence. It
makes at most four calls and treats a duplicate from the second add as a
concurrent mutation rather than retrying again. The separate
`SecurityKeychainSecItemExecutor` actor owns the synchronous Security
dictionary construction and call, keeping Core Foundation state local to that
actor.

Every item is a generic password in the Data Protection Keychain with
`kSecAttrSynchronizable = false`,
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, and no explicit access-group
query field. This remains app-private only while the signed process has no
additional authorized Keychain group. The low-level boundary has no Feature or
ViewModel consumer: a product feature must receive a semantic repository
instead.

`AppDependencies.live()` owns the live boundary without reading or seeding a
secret. Preview and UI-test graphs each receive a fresh
`InMemoryKeychainService`; tests can inject a supplied service explicitly.
The in-memory actor is deterministic storage for graph isolation, not an
emulation of Security, signing, lock state, or persistence.

Screen actions do not choose roots directly. `IAuthenticationActions`,
`IOnboardingActions`, and `IMaintenanceActions` expose narrow semantic
commands. `AppFlowCoordinator` saves the proposed state, asks the policy for
the resulting root, and returns an `AppFlowActionResult`:

- `.unchanged` when neither state nor root changes;
- `.applied(flow:didTransition:)` when persisted state changed and/or the
  visible root was reconciled; `didTransition` reports whether a root
  transition was emitted; or
- `.rejected(...)` when persistence becomes read-only.

Callers can therefore react to persistence failure without confusing it with
a successful navigation event.

## Scene navigation and restoration

Each window owns an `AppSceneNavigationLifecycle`, which owns one `AppRouter`.
That router contains an independent selected section, pending deep link, and
`FlowRouter` for Authentication, Onboarding, Maintenance, Home, Browse,
Projects, and Settings. Each flow view owns one `NavigationStack`; iOS uses an
adaptive tab shell and macOS uses a sidebar split view.

`IFlowRouter` is deliberately narrow: `push`, `pop`, and `popToRoot` affect
only the receiving flow's path. Semantic application commands are separate
action protocols composed by `IAppFlowCoordinator`. Authentication
cancellation is also separate: `IAuthenticationCancellation` is implemented
by the scene's `AppRouter`, so cancellation clears only that scene's
authentication path and pending intent.

Each live scene stores `NavigationSnapshot` in `@SceneStorage` under
`AppTemplate.NavigationSnapshot`. The current snapshot schema is 4 and
contains the selected section, Home/Browse/Projects/Settings paths, and
`lastAppliedTransitionID`. That transition ID is the scene's checkpoint: it
prevents a shared root transition from being replayed after restoration.
Schema 2 and 3 snapshots are migrated; corrupt or unsupported old snapshots
are reset. Future-schema data is preserved and snapshot writes stop, avoiding
destructive downgrade. UI tests use the ephemeral persistence policy.

Deep links received before restoration are queued. A scene outside Main keeps
its pending intent locally; policy transitions can replay it when Main becomes
available. Signing out discards pending intent at the identity boundary.

## Dependency injection and services

`AppDependencies` is an immutable, explicit graph with `live`, `uiTesting`,
`preview`, and `test` factories. It owns application-level storage and example
services, then passes only the dependency slice required downstream.
`SettingsDependencies`, for example, contains `any IAppInfoService`; Settings
does not receive the whole app graph. Other feature dependency structs are
empty extension points until their features need a real dependency.

`AppInfoService` reads display name and short version from the app bundle and
is injected into Settings.

### Local SwiftData reference store

`ILocalDatabaseService` is a Sendable typed value API, implemented by one
explicitly registered local-persistence engine. Its first production model is
`ExampleRecord`; that model does not define a hard-coded service API.

The local persistence path is:

```text
detached LocalDatabaseModel
  -> associated typed Query and LocalEntityAdapter
  -> adapter-owned SwiftData entity/predicate/mapping
  -> operation-scoped ModelContext inside SwiftDataLocalStore
```

`LocalDatabaseService` is an actor facade that performs cancellation and pure
validation before lazily creating a `ModelContainer`. It caches successful
bootstrap and non-cancellation bootstrap failures without erasing the store or
falling back to memory. `LocalDatabaseModelRegistry` authorizes the adapter,
value, entity, and name identity for one service. `VersionedSchema` owns the
physical persisted entities and migrations. The production registry entity set
and cardinality must match the active schema; adding a model is a deliberate
compile-time schema-and-registry change, never runtime discovery of arbitrary
`Codable` values.

`SwiftDataLocalStore` is the internal ModelActor. SwiftData entities and
`ModelContext` instances never leave it. Each synchronous engine operation uses
a fresh private context with autosave disabled. A state-changing upsert or
delete-one saves exactly once; a successful nonempty delete-all performs one
type-level batch-delete call and zero explicit saves; documented no-ops perform
neither persistence call. Failed operation contexts are cleaned up and
discarded so stale registered models cannot leak into the next call. For
delete-all, rollback before the type-level call is no-op cleanup and is not
claimed to compensate a completed or partially completed batch delete.
Returned detached values, including `ExampleRecord`, remain usable
independently of the service and container.

The delete-all rule reflects a disk-backed Xcode 26.6 regression: the
type-level call is immediately durable, leaves `hasChanges == false`, and is not
restored by rollback before any explicit save. This differs from Apple's
current "next save" documentation, so it is a supported-toolchain behavior
guarded by tests, not a generic SwiftData guarantee. Cancellation and injected
failure are checked at a dedicated non-data-bearing checkpoint immediately
before the call; there is no fallible work or cancellation check after a
successful return.

The live store is resolved lazily at
`Application Support/<bundle identifier>/LocalDatabase.store`. Preview and UI
test graphs each create a fresh in-memory container. Schema V1 contains only
the adapter-owned entity for `ExampleRecord`, and the migration plan
intentionally has no stages because no earlier schema shipped. CloudKit is
explicitly disabled.

The failure contract distinguishes validation, initialization (including
migration/container load), read, and public write-operation failures.
Diagnostics expose only operation, fixed entity type, record count, NSError
domain, and NSError code. They never include IDs, payloads, search text, error
descriptions, userInfo, store contents, or user-specific paths.

This is a generic typed engine, not a product repository or product feature
storage. A real feature should define a semantic repository protocol over its
domain values, map those values to local records internally, and inject that
feature protocol into its ViewModel. Features must not import SwiftData,
`LocalDatabaseModel`, or `LocalEntityAdapter`.

`IRemoteService` is the app-facing remote boundary. Its neutral
`fetchExample(_:)` operation demonstrates a semantic service method without
exposing targets, URL requests, or response decoding to features.
`RemoteService` is an actor that owns `NetworkProvider<ExampleTarget>` and
decodes the provider's raw response into `ExampleResponse`.

The reusable implementation under `App/Networking` is Moya-inspired but uses
Foundation directly. `NetworkTarget` values describe typed endpoints, and
`NetworkRequestBuilder` snapshots `baseURL`, `path`, `method`, `task`, and
`headers` exactly once. An empty path preserves the base URL unchanged,
including its trailing-slash state. When a target adds query items, the builder
preserves the base URL's existing percent-encoded query and encodes only the
new items.

`HTTPHeaders` accepts non-empty ASCII HTTP-token field names and keeps one
value for each case-insensitive name. Ordered writes replace the previous
value, fields are applied to requests in canonical-name order, and equality
ignores retained presentation spelling. Live response mapping treats headers
as untrusted input: it skips non-string or invalid names, stringifies values,
and resolves case-variant collisions deterministically.

Asynchronous `RequestAdapter`s mutate requests in order, and a replaceable
`NetworkTransport` performs I/O. `NetworkProvider.request(_:)` is
`@concurrent`, so request construction and pipeline setup do not inherit a
caller actor such as MainActor. After adaptation, the provider creates one
immutable `NetworkRequestContext` containing a fresh correlation ID and the
final request. It passes that context through sequential, registration-ordered
`willSend` and `didComplete` monitor callbacks. Cancellation is checked after
`willSend`, before live or stub execution, and again after delayed-stub sleep;
an observed cancellation produces the paired terminal event.

`URLSessionTransport` is live, while provider-level immediate and delayed
sample responses support deterministic tests. Status codes default to
`200..<300`, and status or decoding errors retain the raw `NetworkResponse`.

The template's live graph deliberately uses `https://example.invalid` because
it has no production backend. No existing feature calls the example operation.
Replace the URL, target, and service contract before product use; inject
feature-specific service slices rather than providers or `AppDependencies`
into ViewModels.
