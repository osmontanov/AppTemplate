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

`AppDependencies` is the composition root. `BrowseRepository` and
`SessionService` are app-wide `Sendable` services. `SessionStore` is shared
app-wide through typed SwiftUI Environment. `AppRouter` and Browse presentation
stores are scene- or feature-scoped. Feature dependencies are required
initializer arguments.

To replace a template service:

1. Add a `Sendable` implementation of the existing protocol.
2. Replace only its construction expression in `AppDependencies.live()`.
3. Keep preview and test factories explicit.
4. Do not add global registration, `resolve()`, mutable overrides, or production
   fallback to fixtures.

Structurally valid restored and deep-linked Browse IDs remain routed.
`BrowseDetailStore` displays `notFound` when the repository returns `nil`.

See the
[DI design](docs/superpowers/specs/2026-07-25-type-safe-dependency-injection-design.md)
and
[implementation plan](docs/superpowers/plans/2026-07-25-type-safe-dependency-injection.md).
