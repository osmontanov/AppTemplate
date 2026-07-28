# AppTemplate

SwiftUI boilerplate for iOS 26, iPadOS 26, and macOS 26.

## Navigation

- `TabView(.sidebarAdaptable)` provides the platform shell.
- Home, Browse, and Settings own independent typed route arrays.
- `AppRouter` is created per window scene.
- `NavigationSnapshot` restores stable identifiers through `SceneStorage`.
- `DeepLinkParser` accepts:
  - `apptemplate://home`
  - `apptemplate://browse`
  - `apptemplate://browse/item/<id>`
  - `apptemplate://settings`

Example features are removable. A replacement feature owns its route enum,
observable router, navigation container, and destination mappings.

See the [navigation design](docs/superpowers/specs/2026-07-24-multiplatform-navigation-design.md)
and [implementation plan](docs/superpowers/plans/2026-07-24-multiplatform-navigation.md)
for the architectural decisions and implementation details.

## Dependency Injection

`AppDependencies` is the composition root.
`dependencies.browse.repository` and `dependencies.session.service` are
app-wide `Sendable` services. `SessionStore` is shared app-wide through typed
SwiftUI Environment. `AppRouter` is scene-scoped; `BrowseListViewModel` and
`BrowseDetailViewModel` are screen-owned. Feature dependencies are required
initializer arguments.

To replace a template service:

1. Add a `Sendable` implementation of the existing protocol.
2. Replace only its construction expression in `AppDependencies.live()`.
3. Keep preview and test factories explicit.
4. Do not add global registration, `resolve()`, mutable overrides, or production
   fallback to fixtures.

Structurally valid restored and deep-linked Browse IDs remain routed.
`BrowseDetailViewModel` displays `notFound` when the repository returns `nil`.

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

Routers remain scene-scoped and own typed navigation state. ViewModels own
presentation state and async screen behavior. Repositories and services own
domain and infrastructure work.

Example:

```swift
BrowseNavigationView(
    router: router.browse,
    dependencies: dependencies.browse
)
```
