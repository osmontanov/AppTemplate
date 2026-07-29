# AppTemplate

SwiftUI boilerplate for iOS 26, iPadOS 26, and macOS 26.

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
- Authentication and every tab own independent `FlowRouter` instances.
- Each `FlowView` owns one `NavigationStack` and passes the same Router through
  its screen hierarchy.
- Screen ViewModels receive `any IFlowRouter`; each screen owns its outgoing
  Route and `.navigationDestination` mapping.
- `AppRouter` is created per window scene.
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

Example features are removable. A new independent flow uses the shared
`FlowRouter`, owns one navigation container, and keeps destination mappings
inside the screens that initiate them. A leaf screen may reserve an empty,
nonconforming Route scaffold; it must not add a fake placeholder route.

The Projects tab is an example of this ownership. `ProjectsView` owns the
simple create-project sheet, while `ProjectDetailsView` owns its project-info
sheet. The create-project sheet presents `CreateProjectFlowView`, an
independent modal flow with its own router and draft state, so its multi-screen
creation sequence does not join the tab's Projects navigation stack.

See the
[hierarchical navigation design](docs/superpowers/specs/2026-07-29-hierarchical-flow-navigation-design.md)
and
[implementation plan](docs/superpowers/plans/2026-07-29-hierarchical-flow-navigation.md)
for the current architectural decisions and implementation details.

## Dependency Injection

`AppDependencies` is the composition root.
`dependencies.browse.service` is an `any IBrowseService`; Session consumers
receive an `any ISessionService`. `BrowseService` and `SessionService` are the
concrete app-wide `Sendable` services. `SessionStore` is shared app-wide
through typed SwiftUI Environment. `AppRouter` is scene-scoped;
`BrowseListViewModel` and `BrowseDetailViewModel` are screen-owned. Feature
dependencies are required initializer arguments.

`ILocalDatabaseService` and `LocalDatabaseService` are inert template examples
and are not registered in production dependency injection.

To replace a template service:

1. Add a `Sendable` implementation of the existing protocol.
2. Replace only its construction expression in `AppDependencies.live()`.
3. Keep preview and test factories explicit.
4. Do not add global registration, `resolve()`, mutable overrides, or production
   fallback to fixtures.

Structurally valid restored and deep-linked Browse IDs remain routed.
`BrowseDetailViewModel` displays `notFound` when the service returns `nil`.

See the
[DI design](docs/superpowers/specs/2026-07-25-type-safe-dependency-injection-design.md)
and
[implementation plan](docs/superpowers/plans/2026-07-25-type-safe-dependency-injection.md).

## Views and ViewModels

Every full user-facing screen owns one concrete `@MainActor @Observable`
ViewModel in private `@State`. Infrastructure containers and small stateless
subviews remain plain SwiftUI Views.

`AppDependencies` exposes immutable feature scopes such as
`BrowseDependencies`. A screen initializer receives its feature scope, shared
store, and router only when needed. No ViewModel receives the whole application
container or reads SwiftUI Environment.

`AppRouter` remains scene-scoped and owns one shared-type `FlowRouter` instance
for Authentication and each tab. Screen ViewModels receive `any IFlowRouter`
when they initiate stack navigation. ViewModels own transient presentation
state and async screen behavior. Services own domain and infrastructure work.

Example:

```swift
BrowseFlowView(
    router: router.browse,
    dependencies: dependencies.browse
)
```
