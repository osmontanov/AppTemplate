# AppTemplate

SwiftUI boilerplate for iOS 26, iPadOS 26, and macOS 26.

## Template Scope

AppTemplate is a navigation-only shell. It does not implement real
authentication, networking, database access, Browse loading, or Projects
creation and persistence. Authentication, Browse, and Projects render static
examples so their navigation and presentation scaffolds can be reused without
bringing sample business logic into a new app.

The working examples are navigation infrastructure: root-flow replacement,
scene-local paths, typed routes, sheets, alert/dialog presentation, deep links,
snapshots, and independent multi-window navigation state.

## Project Structure

- `App/Entry` owns application startup.
- `App/Composition` owns the explicit dependency graph.
- `App/Navigation` owns app-wide navigation infrastructure.
- `App/Models/Domain` owns shared business entities.
- `App/Models/State` owns shared application state and generic reusable state
  containers.
- `App/Models/Local` owns local queries and persisted records.
- `App/Models/Remote` owns transport requests and responses.
- `App/Services` owns `I<ServiceName>` contracts and concrete
  `<ServiceName>` implementations.
- `Features/<Feature>/Screens/<Screen>` owns each screen's View, ViewModel,
  reserved State scaffold, and reserved Model scaffold.
- `Features/<Feature>/State` owns feature-scoped state shared by multiple
  screens in one feature.
- `Features/<Feature>/Screens/<Screen>/State` owns render state used only by
  that screen's ViewModel.
- `Features/<Feature>/Screens/<Screen>/Model` owns the screen's `<Screen>Model`
  scaffold and presentation models such as rows, cards, or `Item` types.
  Existing `Item` types stay where their ownership belongs; the `Item` suffix
  does not decide placement.
- `Features/<Feature>/Flow` owns independent flow containers. Outgoing Routes
  live with their originating screen under
  `Features/<Feature>/Screens/<Screen>/Navigation`.
- `Utilities/UIComponents` contains only reusable SwiftUI `View` types
  independent from screens.
- There is no Repository layer.
- `Resources` owns the asset catalog and Info.plist.

Tests mirror production ownership under `AppTemplateTests`.

## Navigation

- `TabView(.sidebarAdaptable)` provides the platform shell.
- `AppTemplateApp` owns one app-scoped `AppFlowRouter`, so the root flow is
  shared by every window. Authentication, Onboarding, Main, and Maintenance
  therefore change together across all open scenes.
- The app starts in Authentication. Authentication's `Continue` action
  replaces that root with Main; Settings' `Sign Out` action replaces Main with
  Authentication. These are navigation demonstrations, not identity or session
  behavior.
- Each window owns a separate scene-scoped `AppRouter`. Its selected tab,
  pending deep link, and the `NavigationPath` in each independent `FlowRouter`
  remain local to that scene.
- Authentication, Onboarding, Maintenance, and every tab own independent
  `FlowRouter` instances.
- Each `FlowView` owns one `NavigationStack` and passes the same Router through
  its screen hierarchy.
- Navigation-aware screen ViewModels receive `any IRouter`, which combines
  local stack navigation with app-wide root-flow changes. Each screen owns its
  outgoing Route and `.navigationDestination` mapping.
- Every public `setFlow(_:)` call is an explicit root replacement. It resets
  every scene's selected tab and flow histories, including when the requested
  flow is already visible.
- `NavigationSnapshot` restores schema-3 heterogeneous `NavigationPath`
  representations through `SceneStorage`, and migrates schema-2 snapshots by
  restoring their Home, Browse, and Settings histories with an empty Projects
  history.
- `DeepLinkParser` accepts:
  - `apptemplate://home`
  - `apptemplate://browse`
  - `apptemplate://browse/item/<id>`
  - `apptemplate://projects`
  - `apptemplate://projects/project/<project-id>`
  - `apptemplate://projects/project/<project-id>/task/<task-id>`
  - `apptemplate://settings`

The same injected router handles local navigation and root replacement:

```swift
router.push(HomeRoute.details)
router.setFlow(.onboarding)
router.setFlow(.maintenance)
router.setFlow(.main)
```

The `push` changes only the current scene's Home path. Each `setFlow` changes
the shared root observed by every window and clears each window's own histories.
Pending deep links are still scene-scoped and replay only in the scene that
received them after authentication succeeds.

Example features are removable. A new independent flow uses the shared
`FlowRouter`, owns one navigation container, and keeps destination mappings
inside the screens that initiate them. A leaf screen may reserve an empty,
nonconforming Route scaffold; it must not add a fake placeholder route.

The Projects tab is an example of this ownership. `ProjectsView` owns the
create-project sheet, while `ProjectDetailsView` owns its project-info sheet.
The create-project sheet presents `CreateProjectFlowView`, an independent
modal flow with its own router. Its static Basics → Options → Review sequence
does not join the tab's Projects navigation stack, and Finish dismisses the
sheet without creating or saving data.

See the
[hierarchical navigation design](docs/superpowers/specs/2026-07-29-hierarchical-flow-navigation-design.md)
and
[implementation plan](docs/superpowers/plans/2026-07-29-hierarchical-flow-navigation.md)
for the current architectural decisions and implementation details.
See also the
[global app flow router design](docs/superpowers/specs/2026-07-30-global-app-flow-router-design.md)
and
[implementation plan](docs/superpowers/plans/2026-07-30-global-app-flow-router.md).
The current reduced scope is described by the
[navigation-only app shell design](docs/superpowers/specs/2026-07-30-navigation-only-app-shell-design.md)
and
[implementation plan](docs/superpowers/plans/2026-07-30-navigation-only-app-shell.md).

## Dependency Injection

`AppDependencies` is the composition root. It contains exactly two empty,
currently unused DI examples:

- `ILocalDatabaseService` with `LocalDatabaseService`;
- `IRemoteService` with `RemoteService`.

Both protocols intentionally have no requirements, and both concrete actors
intentionally perform no work. `AppDependencies.live()` registers them only to
demonstrate explicit protocol-based construction. The template does not choose
a database, network client, authentication provider, or feature data service.
Empty feature dependency structs remain as folder scaffolds but carry no
runtime service or state.

To replace a template service:

1. Add requirements to the relevant protocol and implement them in a
   `Sendable` concrete type.
2. Replace only its construction expression in `AppDependencies.live()`.
3. Keep preview and test factories explicit.
4. Do not add global registration, `resolve()`, mutable overrides, or production
   fallback to fixtures.

Structurally valid restored and deep-linked Browse and Projects identifiers
remain routed as static navigation examples; no service resolves them.

See the
[DI design](docs/superpowers/specs/2026-07-25-type-safe-dependency-injection-design.md)
and
[implementation plan](docs/superpowers/plans/2026-07-25-type-safe-dependency-injection.md).

## Views and ViewModels

Every full user-facing screen owns one concrete `@MainActor @Observable`
ViewModel in private `@State`. Infrastructure containers and small stateless
subviews remain plain SwiftUI Views.

Screen ViewModels are navigation- and presentation-only. They may retain a
router or route identifier and own sheet, alert, or dialog state. They do not
receive services, stores, repositories, or `AppDependencies`; load, save,
authenticate, retry, sort, validate, or persist data; or read SwiftUI
Environment.

`AppRouter` remains scene-scoped and owns one `FlowRouter` instance for
Authentication, Onboarding, Maintenance, and each tab. Screen ViewModels
receive `any IRouter` only when they initiate navigation. Views render static
template content and bind transient presentation state.

Example:

```swift
BrowseFlowView(router: router.browse)
```
