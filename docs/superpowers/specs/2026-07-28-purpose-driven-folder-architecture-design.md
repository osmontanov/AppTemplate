# Purpose-Driven Folder Architecture Design

## Goal

Reorganize the boilerplate into a predictable feature-first structure where
every folder has one explicit purpose, every feature exposes the same
extension points, and app-wide navigation and services remain easy to find.

This is an organizational refactor. It must not change navigation behavior,
dependency lifetimes, screen state, session behavior, deep links, snapshots,
or supported platforms.

## Constraints

- Keep the deployment targets at iOS 26.0, iPadOS 26.0, and macOS 26.0.
- Add no third-party dependencies.
- Preserve every public and internal Swift type name that already has runtime
  behavior.
- Preserve scene-scoped routers, app-wide `SessionStore`, screen-owned
  ViewModels, feature-scoped dependencies, and all concurrency safeguards.
- Move files with Git history preserved.
- Use the Xcode project's file-system-synchronized groups rather than adding
  individual file references manually.
- Empty feature extension points compile but are not registered in
  `AppDependencies`, injected into screens, or instantiated at runtime.

## Top-Level Ownership

```text
AppTemplate/
├── App/
│   ├── Entry/
│   ├── Composition/
│   ├── Navigation/
│   └── Services/
├── Features/
├── Shared/
└── Resources/
```

### `App`

`App` owns application startup, dependency composition, app-wide navigation
infrastructure, and app-wide services.

```text
App/
├── Entry/
│   ├── AppTemplateApp.swift
│   └── ContentView.swift
├── Composition/
│   └── AppDependencies.swift
├── Navigation/
│   ├── Containers/
│   ├── Core/
│   ├── DeepLinks/
│   ├── Diagnostics/
│   ├── Lifecycle/
│   ├── Routing/
│   └── Snapshots/
└── Services/
    └── Session/
        ├── Dependencies/
        ├── Implementations/
        ├── Models/
        ├── Protocols/
        └── Store/
```

The current navigation files map as follows:

| Destination | Files |
| --- | --- |
| `App/Navigation/Containers` | `AppSceneView`, `AppRootView`, `AppShellView` |
| `App/Navigation/Core` | `StackRouting` |
| `App/Navigation/DeepLinks` | `DeepLinkParser` |
| `App/Navigation/Diagnostics` | `NavigationLogger` |
| `App/Navigation/Lifecycle` | `AppSceneNavigationLifecycle` |
| `App/Navigation/Routing` | `AppFlow`, `AppSection`, `NavigationIntent`, `AppRouter` |
| `App/Navigation/Snapshots` | `NavigationSnapshot` |

The Session service maps as follows:

| Destination | Files |
| --- | --- |
| `App/Services/Session/Dependencies` | `SessionDependencies` |
| `App/Services/Session/Implementations` | `InMemorySessionService` |
| `App/Services/Session/Models` | `UserSession` |
| `App/Services/Session/Protocols` | `SessionService` |
| `App/Services/Session/Store` | `SessionStore` |

`SessionStore` remains the app-wide observable session state. Its placement
inside the Session service module does not turn it into a stateless service or
change its lifetime.

### `Features`

Every feature has the same folder scaffold:

```text
Features/<Feature>/
├── Screens/
├── ViewModels/
├── Navigation/
├── Dependencies/
├── Domain/
│   ├── Models/
│   └── Repositories/
├── Data/
│   └── Repositories/
├── Services/
└── UI/
    └── Components/
```

The initial feature set is:

- `Authentication`
- `Home`
- `Browse`
- `Settings`

Existing runtime types move into the matching folders:

| Purpose | Examples |
| --- | --- |
| Screens | `AuthenticationView`, `HomeView`, `BrowseDetailView`, `SettingsView` |
| ViewModels | `AuthenticationViewModel`, `HomeViewModel`, `BrowseListViewModel` |
| Navigation | feature `Route` and `Router` types |
| Dependencies | `BrowseDependencies` |
| Domain models | `BrowseItem` |
| Domain repositories | `BrowseRepository` |
| Data repositories | `InMemoryBrowseRepository` |

Feature navigation remains feature-owned. Moving `StackRouting` into
`App/Navigation/Core` does not move `HomeRouter`, `BrowseRouter`,
`SettingsRouter`, or their routes out of their features.

### Compile-Safe Empty Extension Points

When a feature does not yet have a real type for a scaffold role, add a small
compile-safe extension point in that folder. Existing real types replace the
corresponding placeholder; they are not duplicated.

Examples:

```swift
nonisolated struct HomeDependencies: Sendable {
    init() {}
}

nonisolated struct HomeModel: Sendable {
    init() {}
}

protocol HomeRepository: Sendable {}

nonisolated struct InMemoryHomeRepository: HomeRepository {
    init() {}
}

protocol HomeService: Sendable {}

nonisolated struct HomeComponents: Sendable {
    init() {}
}

nonisolated struct AuthenticationNavigation: Sendable {
    init() {}
}
```

These types are deliberate template extension points, not runtime
abstractions:

- they contain no business behavior;
- they do not resolve dependencies;
- they are not added to `AppDependencies`;
- they are not injected into a screen or ViewModel;
- they do not create a second router, store, or source of truth;
- they may be replaced or expanded when a real feature requirement appears.

No artificial empty ViewModel is created because every current full screen
already has a real ViewModel. No artificial feature router is created when
navigation is app-owned, as in Authentication; the inert
`AuthenticationNavigation` extension point preserves the folder scaffold
without competing with `AppRouter`.

### `Shared`

`Shared` contains only code that is independent of application navigation,
app-wide services, and individual features:

```text
Shared/
├── UI/
│   ├── Components/
│   ├── Modifiers/
│   ├── Styles/
│   └── Theme/
├── Extensions/
└── Utilities/
```

A UI component moves to `Shared/UI` only after it is genuinely reusable by
multiple features. Feature-specific components stay in
`Features/<Feature>/UI/Components`.

The refactor does not add dummy visual components merely to populate
`Shared/UI`. Its intended structure is documented and each directory is
created when its first real type exists.

There is no `Shared/Navigation` and no `Shared/Session`. Navigation belongs to
`App/Navigation`; Session belongs to `App/Services/Session`.

### `Resources`

```text
Resources/
├── Assets.xcassets
└── Info.plist
```

Moving `Info.plist` requires updating `INFOPLIST_FILE` for every build
configuration. The asset catalog remains the application asset catalog after
the move.

## Future Network and Local Database Placement

App-wide infrastructure follows the same service-module pattern:

```text
App/Services/
├── Session/
├── Network/
│   ├── Dependencies/
│   ├── Implementations/
│   ├── Models/
│   └── Protocols/
└── Database/
    ├── Dependencies/
    ├── Implementations/
    ├── Models/
    └── Protocols/
```

Network transports and database engines belong to `App/Services`. A
feature-specific API adapter, repository implementation, DTO, or persistence
mapping remains in that feature's `Data` folder. This prevents transport and
storage details from leaking into screen ViewModels.

## Test Structure

Tests mirror production ownership:

```text
AppTemplateTests/
├── App/
│   ├── Composition/
│   ├── Navigation/
│   │   ├── Core/
│   │   ├── DeepLinks/
│   │   ├── Lifecycle/
│   │   ├── Routing/
│   │   └── Snapshots/
│   └── Services/
│       └── Session/
├── Features/
│   ├── Authentication/
│   ├── Home/
│   ├── Browse/
│   └── Settings/
├── Project/
└── TestSupport/
    ├── Fakes/
    ├── Fixtures/
    └── Spies/
```

Test files move without changing their behavior. Test-only helpers move into
`TestSupport` only when more than one test suite reuses them. Empty
`TestSupport` categories are documented but do not receive fake production
types.

Folder paths are an architectural decision, not runtime behavior, so the
project does not ship brittle tests that grep source paths. One-time
migration checks verify the intended tree and absence of obsolete
directories. Existing construction tests continue to verify that Xcode
discovers moved source files and resources.

## Data and Dependency Flow

Folder moves do not alter the established flow:

```text
AppDependencies
    ├── BrowseDependencies → BrowseRepository
    └── SessionDependencies → SessionService

AppSceneView
    ├── scene-scoped AppRouter
    └── app-wide SessionStore

Screen
    ├── private, non-optional @State ViewModel
    ├── explicit feature dependency scope when needed
    ├── explicit shared store when needed
    └── scene router when navigation actions are needed
```

Routers remain the only owners of navigation paths and presentations.
ViewModels remain unaware of `AppDependencies` and SwiftUI Environment.

## Migration Strategy

1. Move entry, composition, navigation, Session, and resource files.
2. Move every feature into the uniform folder scaffold.
3. Add only the missing compile-safe feature extension points.
4. Mirror the production layout in `AppTemplateTests`.
5. Update `Info.plist` build settings and README structure documentation.
6. Verify no obsolete `Core`, old feature presentation paths, root-level
   resources, `Shared/Navigation`, or `Shared/Session` paths remain.
7. Run complete iOS and macOS tests.
8. Build Release for generic iOS/iPadOS and macOS.

Each step should preserve a compiling project. File moves and resource-path
changes are separated from placeholder additions so failures are easy to
localize.

## Verification

The completed refactor must satisfy all of the following:

- all existing and new Swift files are discovered by Xcode;
- the application URL scheme remains registered;
- `Info.plist` resolves from `Resources`;
- the asset catalog builds for iOS/iPadOS and macOS;
- no production type imports or resolves an obsolete path-based module;
- no placeholder is registered or instantiated at runtime;
- full iOS simulator tests pass;
- full macOS tests pass;
- generic iOS Release build passes;
- macOS Release build passes;
- `git diff --check` reports no whitespace errors.

## Non-Goals

- No navigation redesign.
- No dependency-injection redesign.
- No ViewModel behavior changes.
- No network or local database implementation.
- No extraction of speculative shared UI components.
- No package or target modularization.
