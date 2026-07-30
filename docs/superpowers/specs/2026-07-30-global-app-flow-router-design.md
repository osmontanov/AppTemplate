# Global App Flow Router Design

Date: 2026-07-30
Status: Approved concept; awaiting written-spec review

## Context

`AppRouter` currently owns two different kinds of navigation state:

- the application root flow (`launching`, `authentication`, or `main`);
- scene-local navigation state, including the selected section, independent
  stack histories, restoration, deep links, and a pending intent.

That ownership is correct for independent window histories but not for future
root flows that represent one shared user or one application state. Two macOS
or iPadOS windows use the same `SessionStore` and therefore the same user. A
root transition such as authentication, onboarding, or maintenance must update
all windows, while ordinary pushes and tab histories must remain independent.

The requested API is a universal:

```swift
router.setFlow(.onboarding)
```

A ViewModel must be able to invoke that method through initializer-injected
navigation, without a singleton, service locator, closure, or direct mutable
access to `flow`.

## Goals

- Add `onboarding` and `maintenance` as concrete root-flow examples.
- Make root-flow state app-scoped and shared by all windows.
- Keep selected sections, stack paths, restoration, and pending deep links
  scene-scoped.
- Allow a ViewModel to switch root flow through `setFlow(_:)`.
- Make every explicit `setFlow(_:)` call a real root transition, including a
  call whose target equals the current flow.
- Reset every scene's navigation histories on an explicit `setFlow(_:)`.
- Preserve restored scene histories when startup restores an authenticated
  session.
- Preserve the existing authentication-gated deep-link replay behavior.
- Keep ViewModels explicitly injectable and independently testable.
- Preserve current iOS 26, iPadOS 26, and macOS 26 behavior.

## Non-goals

- Share tab selection or stack history between windows.
- Introduce `AppRouter.shared` or any other process-global singleton.
- Put SwiftUI `@Environment` lookup inside ViewModels.
- Put navigation state inside `AppDependencies`, whose purpose remains
  immutable service composition.
- Replace screen-owned routes, destinations, sheets, alerts, or dialogs.
- Make `AppFlowRouter` construct Views or resolve services.
- Persist transient root flows such as launching or authentication in
  `NavigationSnapshot`.

## Considered Approaches

### 1. Shared root router plus scene routers — selected

Create one observable `AppFlowRouter` in `AppTemplateApp`. Every window reads
that shared root state but creates its own `AppRouter` and `FlowRouter`
instances. Local `FlowRouter` objects delegate `setFlow(_:)` to the shared root
router.

This preserves one user-facing root state, independent window histories,
explicit injection, and deterministic tests.

### 2. Keep `flow` in every scene's `AppRouter`

This is the smallest code change, but a ViewModel in one window would switch
only that window. Authentication, onboarding, and maintenance could therefore
disagree between windows belonging to the same user.

### 3. Share one complete `AppRouter` between all windows

This makes root changes global, but also shares selected tabs, stack paths,
pending intents, and restoration state. Navigation in one window would mutate
another window and scene restoration would no longer be independent.

## Selected Architecture

The ownership tree becomes:

```text
AppTemplateApp
├── SessionStore                         app-scoped, one user
├── AppFlowRouter                        app-scoped, one root flow
└── WindowGroup
    ├── Window A
    │   └── AppRouter A                  scene-scoped histories and intent
    └── Window B
        └── AppRouter B                  scene-scoped histories and intent
```

`AppFlowRouter` owns only root replacement. `AppRouter` owns only one scene's
navigation. `FlowRouter` owns only one independent stack path, plus a delegated
capability to request a global root transition.

## Root Flow Model

`AppFlow` contains:

```swift
nonisolated
enum AppFlow: Equatable, Sendable {
    case launching
    case authentication
    case onboarding
    case main
    case maintenance
}
```

The root mappings are:

| Flow | Root content |
| --- | --- |
| `launching` | launching progress content |
| `authentication` | `AuthenticationFlowView` |
| `onboarding` | `OnboardingFlowView` |
| `main` | `AppShellView` |
| `maintenance` | `MaintenanceFlowView` |

Onboarding and maintenance are example independent flows with their own
`FlowRouter` and `FlowView`. Their initial screens follow the existing
screen-capsule folders: `Model`, `Navigation`, `State`, `View`, and
`ViewModel`.

## Global Transition Model

An explicit flow request must be observable even when it repeats the current
flow. A plain observable `flow` property is insufficient because assigning the
same value may not produce the reset event required by the caller.

`AppFlowRouter` therefore publishes a transition value:

```swift
nonisolated
enum AppFlowHistoryAction: Equatable, Sendable {
    case preserve
    case reset
}

nonisolated
enum PendingIntentAction: Equatable, Sendable {
    case preserve
    case replay
    case discard
}

nonisolated
struct AppFlowTransition: Equatable, Sendable {
    let id: UUID
    let flow: AppFlow
    let historyAction: AppFlowHistoryAction
    let pendingIntentAction: PendingIntentAction
}
```

The concrete names may be adjusted during implementation, but the required
semantics are:

- every public `setFlow(_:)` creates a new transition identifier;
- every public `setFlow(_:)` uses `historyAction == .reset`;
- the concrete router exposes `flow` as `transition.flow` for root switching;
- `flow` remains read-only to consumers;
- all mutations pass through router methods;
- every window can observe the same transition exactly once.

The screen-facing contract is:

```swift
@MainActor
protocol IAppFlowRouter: AnyObject {
    func setFlow(_ flow: AppFlow)
}
```

The SwiftUI root receives the concrete observable `AppFlowRouter`. ViewModels
receive protocols.

## Local and Global Router Composition

The existing local contract remains focused:

```swift
@MainActor
protocol IFlowRouter: AnyObject {
    func push<Route: NavigationRoute>(_ route: Route)
    func pop()
    func popToRoot()
}
```

A composite contract exposes both capabilities through one injected value:

```swift
@MainActor
protocol IRouter: IFlowRouter, IAppFlowRouter {}
```

`FlowRouter` conforms to `IRouter`. It still owns only its `NavigationPath`;
its `setFlow(_:)` implementation delegates to the app-scoped
`IAppFlowRouter`.

```swift
func setFlow(_ flow: AppFlow) {
    appFlowRouter.setFlow(flow)
}
```

This lets an existing screen ViewModel use one dependency:

```swift
private let router: any IRouter

func openDetails() {
    router.push(HomeRoute.details)
}

func startOnboarding() {
    router.setFlow(.onboarding)
}
```

Screens that do not need navigation do not have to retain a router
preemptively. Any ViewModel can gain both local and global navigation by
declaring `any IRouter` in its initializer. No ViewModel reads SwiftUI
environment values.

## Composition and View Wiring

`AppTemplateApp` creates exactly one `AppFlowRouter`, alongside the shared
`SessionStore`, and passes it into each `AppSceneView`.

Each `AppSceneView` creates one `AppSceneNavigationLifecycle` and one
scene-local `AppRouter`. That `AppRouter` constructs Authentication,
Onboarding, Home, Browse, Projects, Settings, and Maintenance `FlowRouter`
instances with the same shared `IAppFlowRouter` delegate.

`AppRootView` receives:

- the concrete shared `AppFlowRouter` for its root switch;
- the scene-local `AppRouter` for the selected tab and flow histories;
- immutable application service dependencies.

It switches on the shared root flow:

```swift
Group {
    switch appFlowRouter.flow {
    case .launching:
        LaunchingView()
    case .authentication:
        AuthenticationFlowView(router: router.authentication)
    case .onboarding:
        OnboardingFlowView(router: router.onboarding)
    case .main:
        AppShellView(router: router, dependencies: dependencies)
    case .maintenance:
        MaintenanceFlowView(router: router.maintenance)
    }
}
.id(appFlowRouter.transition.id)
```

The transition identifier is part of the root View identity. This guarantees
that `setFlow(_:)` targeting the already-visible flow recreates its local
presentation state in addition to resetting its navigation path.

`AppRootView` no longer needs `@Bindable` for the scene router. `AppShellView`
keeps its bindable scene router because `TabView` requires a binding to
`selectedSection`.

## Transition Behavior in Every Scene

Every scene observes the shared `AppFlowTransition`. For each new transition,
the scene lifecycle:

1. applies the transition's history action;
2. when the action is `reset`, clears Authentication, Onboarding, Home,
   Browse, Projects, Settings, and Maintenance paths and selects Home;
3. when the action is `preserve`, keeps restored scene paths and the selected
   section;
4. applies the transition's pending-intent action;
5. lets SwiftUI replace the root content from the shared flow.

An explicit call to the same flow is still a transition:

```swift
router.setFlow(.authentication)
```

When Authentication is already visible, this resets its stack and recreates
the root presentation state instead of doing nothing.

The scene lifecycle remains responsible for restoration, URL handling, and
scene snapshot persistence. It no longer owns the root `flow` value.

## Session Coordination

`SessionStore` remains the only source of truth for authentication. Signing in
or out continues to call `SessionStore`; ViewModels must not claim a session
transition merely by changing root UI.

The shared `AppFlowRouter` receives idempotent synchronization from
`SessionPhase`:

| Session phase | Root result |
| --- | --- |
| `idle` or `loading` | `launching` |
| `unauthenticated` | `authentication` |
| `authenticated` | `main` |

Multiple windows may report the same shared phase. Session synchronization
must suppress equivalent duplicate transitions so opening two windows does not
reset both scenes repeatedly. This does not change the public `setFlow(_:)`
rule: an explicit ViewModel call always creates a transition.

Session synchronization uses a different internal policy from the public
setter:

- initial authenticated restoration enters Main with `historyAction ==
  .preserve`, retaining the restored tab and paths;
- initial unauthenticated restoration enters Authentication with
  `historyAction == .reset`;
- a newly authenticated session enters Main with `historyAction == .reset`;
- logout enters Authentication with `historyAction == .reset`;
- a failed or cancelled session command returns to its previous stable flow
  without erasing that flow's history.

The flow router tracks the previous stable `SessionPhase` to distinguish cold
restoration, new authentication, logout, and a failed command. Transient
`loading` may show Launching but does not itself erase scene histories.

## Pending Deep-Link Policy

Pending intents remain scene-scoped because a URL belongs to the scene that
received it. They are not moved into the global flow router.

The global transition event carries an internal pending-intent action:

- `preserve` while startup or authentication is still in progress;
- `replay` when an authenticated session enters `main`;
- `discard` for an explicit root replacement that invalidates the previous
  navigation context, including authentication cancellation or logout.

Therefore the existing behavior remains valid:

```text
deep link received while signed out
→ scene stores pending intent
→ shared root becomes Authentication
→ successful sign-in changes root to Main
→ only the receiving scene replays its pending intent
```

Other windows enter Main but do not navigate to a URL they never received.

`AppRouter.handle(_:)` consults the shared current root flow. It applies an
intent immediately only in `main`; otherwise it stores the intent for that
scene.

## Code Removed or Simplified

After behavior has moved to the new owners:

- remove `AppRouter.flow`;
- remove the `flow` argument from `AppRouter` initializers;
- remove direct `router.flow = ...` writes;
- replace `finishLaunching`, `completeAuthentication`, and
  `requireAuthentication` with shared flow transitions plus one scene
  transition handler;
- remove the full `AppRouter` dependency from `AuthenticationViewModel`;
- remove `appRouter` propagation through Authentication Views;
- move existing `router.flow` tests to `AppFlowRouter` and lifecycle tests;
- remove `@Bindable` from the scene router in `AppRootView`.

The reset, pending-intent, deep-link, and restoration behavior inside those
old methods must be migrated before the methods are deleted. This is a
behavior-preserving move, not a textual deletion.

`AppRouter`, `FlowRouter`, `IFlowRouter`, `AppSceneNavigationLifecycle`,
`SessionStore`, `pendingIntent`, snapshot support, and screen-owned routes all
remain necessary.

## Error and Safety Behavior

- An unknown future flow is a compile-time exhaustiveness error in root
  switches.
- Root transitions execute on `MainActor`.
- ViewModels cannot directly mutate `flow`.
- A failed sign-in returns to Authentication through `SessionStore` phase.
- A failed sign-out restores Main through the existing stable session phase.
- Root transitions do not perform network or persistence work.
- Snapshot encoding failures continue to log and recover without terminating
  the application.
- No root transition uses `fatalError`, force casts, or fallback Views.

## Testing Strategy

### AppFlowRouter

- starts in the configured flow;
- `setFlow(_:)` publishes the requested flow;
- two calls with the same flow produce two distinct transitions;
- public `setFlow(_:)` always requests a history reset;
- session synchronization is idempotent across duplicate reports;
- authenticated cold restoration requests history preservation;
- new authentication and logout request history reset;
- public flow state is read-only.

### FlowRouter and ViewModels

- `FlowRouter.setFlow(_:)` delegates to the injected app flow router;
- a ViewModel can push a local route and request a root flow through one
  `IRouter`;
- tests inject spies without global overrides.

### Multiple scenes

- two scenes share one root flow router;
- the scenes keep different selected tabs and stack paths;
- one ViewModel's `setFlow(_:)` updates both roots;
- both scenes reset their own histories;
- navigation in one scene still does not mutate the other scene's paths.

### Authentication and deep links

- startup maps loading to Launching and the final phase to Authentication or
  Main;
- authenticated cold startup preserves restored tab histories;
- a newly authenticated session resets old histories before replaying its
  pending intent;
- a signed-out deep link survives Authentication and replays only in its
  receiving scene after sign-in;
- cancellation discards the receiving scene's pending intent;
- logout changes every window to Authentication and prevents history leakage;
- failed sign-out returns every window to Main consistently.

### Root construction and platforms

- every `AppFlow` case constructs its expected root;
- Onboarding and Maintenance flow roots and initial screens construct with
  injected routers;
- navigation snapshot tests remain scene-scoped and exclude global transient
  flow;
- full tests pass on macOS 26, iPhone iOS 26, and iPadOS 26.

## Acceptance Criteria

- `AppRouter` no longer stores `flow`.
- Exactly one app-scoped `AppFlowRouter` is created by `AppTemplateApp`.
- Every window observes that same global flow router.
- Every window still owns an independent `AppRouter` and independent paths.
- `AppFlow` contains Launching, Authentication, Onboarding, Main, and
  Maintenance.
- A ViewModel with `any IRouter` can call both local navigation operations and
  `setFlow(_:)`.
- Repeating `setFlow` for the current flow resets the root again.
- Every explicit `setFlow(_:)` resets each scene's flow histories.
- Authenticated cold restoration preserves each scene's restored histories.
- Session transitions remain driven by `SessionStore`.
- Authentication-gated deep links replay only in the receiving scene.
- Authentication no longer receives the full `AppRouter`.
- No singleton, service locator, navigation closure, `AnyView`, or
  `fatalError` is introduced.
- Existing user changes outside the implementation scope are preserved.
- All supported-platform tests pass.
