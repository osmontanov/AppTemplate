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
