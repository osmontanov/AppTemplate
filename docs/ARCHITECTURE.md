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
is injected into Settings. `ILocalDatabaseService`/`LocalDatabaseService` and
`IRemoteService`/`RemoteService` are intentionally empty protocol/actor
examples. They demonstrate concurrency-safe composition but provide no local
or remote behavior. Add real requirements and implementations before using
them, keep factories explicit, and avoid service locators or hidden global
fallbacks.
