# Screen Capsule and Service-Only Architecture Design

## Goal

Reorganize the boilerplate so that every user-facing screen has an obvious
home, reusable UI is independent from screens, all application models have one
owner, and data access uses a single Service abstraction instead of parallel
Service and Repository layers.

This is an architectural organization refactor. It must preserve navigation
behavior, dependency lifetimes, async cancellation, session behavior, deep
links, snapshots, and supported platforms.

## Constraints

- Keep deployment targets at iOS 26.0, iPadOS 26.0, and macOS 26.0.
- Add no third-party dependencies.
- Keep `AppRouter` scene-scoped and `SessionStore` app-scoped.
- Keep every full screen's ViewModel private, non-optional, and owned by its
  View through SwiftUI `@State`.
- Do not inject the complete `AppDependencies` container into a ViewModel.
- Do not create a Repository layer or Repository types.
- Do not create Local or Remote variants for a Service unless a real local
  database or remote API implementation exists.
- Preserve Git history for moves where the type itself does not change.
- Use file-system-synchronized Xcode groups rather than manually registering
  individual Swift files.

## Top-Level Ownership

```text
AppTemplate/
├── App/
│   ├── Composition/
│   ├── Entry/
│   ├── Models/
│   │   ├── Domain/
│   │   ├── Local/
│   │   └── Remote/
│   ├── Navigation/
│   └── Services/
├── Features/
├── Utilities/
│   └── UIComponents/
└── Resources/
```

### `App/Models`

All application models live under `App/Models`; features do not own separate
Domain or Data model trees.

```text
App/Models/
├── Domain/
├── Local/
└── Remote/
```

`Domain` owns models used by application logic and presentation state,
including:

- `BrowseItem`
- `UserSession`
- `BrowseFailure`
- `BrowseListState`
- `BrowseDetailState`
- `NavigationGuideItem`
- the existing compile-safe `AuthenticationModel`, `HomeModel`, and
  `SettingsModel` template extension points

`Local` is reserved for future database record models. `Remote` is reserved
for future API DTOs. Neither folder receives a fake Swift model. They are
preserved in source control with a `.gitkeep` file until real persistence or
network work introduces concrete types.

Navigation types are not general models. Route types remain with the screen
that declares its possible destinations.

### `App/Services`

Services are the only data and operation boundary. There is no
`App/Repositories` directory and no type whose name ends in `Repository`.

```text
App/Services/
├── Browse/
│   ├── IBrowseService.swift
│   └── BrowseService.swift
├── Session/
│   ├── ISessionService.swift
│   ├── SessionService.swift
│   ├── SessionDependencies.swift
│   └── SessionStore.swift
└── LocalDatabase/
    ├── ILocalDatabaseService.swift
    └── LocalDatabaseService.swift
```

Service protocols use the explicit `I<ServiceName>` naming convention.
Concrete implementations use `<ServiceName>`:

- `IBrowseService` is implemented by `BrowseService`.
- `ISessionService` is implemented by `SessionService`.

`BrowseService` preserves the current deterministic in-memory Browse example.
It is not named `BrowseLocalService` because it is not backed by a local
database. `SessionService` preserves the current example session behavior and
replaces `InMemorySessionService`.

A future implementation may use names such as `BrowseLocalService` only when
it actually talks to a local database, or `BrowseRemoteService` only when it
actually talks to a remote API. Those types are not created by this refactor.

`ILocalDatabaseService` and `LocalDatabaseService` are deliberately empty,
compile-safe examples of the naming and DI pattern for a future local database
service. They contain no methods or state, are not registered in
`AppDependencies`, and are never instantiated at runtime.

`SessionStore` remains the app-wide observable owner of session presentation
state. It is colocated with the Session service module, but it is not a second
data-access abstraction.

### `Utilities/UIComponents`

All reusable UI component types live in:

```text
Utilities/UIComponents/
```

The existing `AuthenticationComponents`, `BrowseComponents`, `HomeComponents`,
and `SettingsComponents` extension-point types move there. Feature-level
`UI/Components` folders are removed.

A type in `Utilities/UIComponents` must not depend on:

- a screen View or ViewModel;
- a feature Router or Route;
- `AppDependencies`;
- a feature-specific dependency scope.

It may accept plain models, bindings, values, and callbacks. This keeps UI
components reusable and independent from screen ownership.

## Feature Capsule Structure

The selected organization is a Feature Capsule. Dependencies and Routers are
shared by a feature, while every screen owns its View and ViewModel.

```text
Features/<Feature>/
├── Dependencies/
├── Navigation/          # feature Router
└── Screens/
    └── <Screen>/
        ├── View/
        ├── ViewModel/
        └── Navigation/  # Route only when this screen declares destinations
```

There are no feature-level `Data`, `Domain`, `Repositories`, `Services`, `UI`,
or shared `ViewModels` directories.

Every full screen has its own directory and concrete View/ViewModel pair.
Leaf screens do not receive fake Routers or Routes. Their View and ViewModel
are sufficient. A `Navigation` directory is present only when the screen
declares real destinations.

### Authentication

```text
Features/Authentication/
├── Dependencies/
│   └── AuthenticationDependencies.swift
└── Screens/
    └── Authentication/
        ├── View/
        │   └── AuthenticationView.swift
        └── ViewModel/
            └── AuthenticationViewModel.swift
```

Authentication continues to use app-owned `AppRouter`; it does not create a
competing feature Router or Route.

### Browse

```text
Features/Browse/
├── Dependencies/
│   └── BrowseDependencies.swift
├── Navigation/
│   └── BrowseRouter.swift
└── Screens/
    ├── Browse/
    │   ├── View/
    │   │   └── BrowseNavigationView.swift
    │   ├── ViewModel/
    │   │   └── BrowseListViewModel.swift
    │   └── Navigation/
    │       └── BrowseRoute.swift
    └── BrowseDetail/
        ├── View/
        │   └── BrowseDetailView.swift
        └── ViewModel/
            └── BrowseDetailViewModel.swift
```

### Home

```text
Features/Home/
├── Dependencies/
│   └── HomeDependencies.swift
├── Navigation/
│   └── HomeRouter.swift
└── Screens/
    ├── Home/
    │   ├── View/
    │   │   └── HomeView.swift
    │   ├── ViewModel/
    │   │   └── HomeViewModel.swift
    │   └── Navigation/
    │       └── HomeRoute.swift
    ├── HomeDetails/
    │   ├── View/
    │   │   └── HomeDetailsView.swift
    │   └── ViewModel/
    │       └── HomeDetailsViewModel.swift
    └── NavigationGuide/
        ├── View/
        │   └── NavigationGuideView.swift
        └── ViewModel/
            └── NavigationGuideViewModel.swift
```

`HomeRoute`, `HomeSheet`, and `HomeAlert` remain together because they describe
destinations and presentations declared by the Home navigation screen.

### Settings

```text
Features/Settings/
├── Dependencies/
│   └── SettingsDependencies.swift
├── Navigation/
│   └── SettingsRouter.swift
└── Screens/
    ├── Settings/
    │   ├── View/
    │   │   └── SettingsView.swift
    │   ├── ViewModel/
    │   │   └── SettingsViewModel.swift
    │   └── Navigation/
    │       └── SettingsRoute.swift
    └── About/
        ├── View/
        │   └── AboutView.swift
        └── ViewModel/
            └── AboutViewModel.swift
```

## Dependency and Data Flow

```text
AppDependencies
    ├── BrowseDependencies → any IBrowseService
    └── SessionDependencies → any ISessionService

Screen View
    ├── private @State ViewModel
    ├── feature dependency scope when data operations are needed
    ├── shared SessionStore when session state is needed
    └── feature Router or AppRouter when navigation is needed

ViewModel
    └── I<ServiceName> → Domain models
```

`AppDependencies.live()` constructs `BrowseService` and `SessionService`.
Preview and test factories accept explicit `any IBrowseService` and
`any ISessionService` values. Test doubles conform to the same interfaces.

`BrowseDependencies.repository` becomes `BrowseDependencies.service`.
Browse ViewModels call `service.items()` and `service.item(id:)`. Their public
screen behavior and task ownership remain unchanged.

Services throw operational errors. ViewModels translate them into screen
presentation state. Views render loading, content, not-found, and failure
states. Existing cancellation handling, request versioning, and stale-response
protection remain intact.

## Test Ownership and Verification

Tests mirror the new production ownership. A feature test file that covers
multiple screens is split so that each screen's ViewModel tests live under the
matching screen directory.

```text
AppTemplateTests/
├── App/
│   ├── Composition/
│   ├── Models/
│   ├── Navigation/
│   └── Services/
│       ├── Browse/
│       ├── Session/
│       └── LocalDatabase/
├── Features/
│   ├── Authentication/Screens/Authentication/
│   ├── Browse/Screens/Browse/
│   ├── Browse/Screens/BrowseDetail/
│   ├── Home/Screens/Home/
│   ├── Home/Screens/HomeDetails/
│   ├── Home/Screens/NavigationGuide/
│   ├── Settings/Screens/Settings/
│   └── Settings/Screens/About/
└── Project/
```

Verification covers:

- focused tests for renamed Browse and Session service interfaces;
- existing ViewModel behavior, navigation, deep-link, snapshot, and session
  tests;
- one-time structural guards confirming the new directories and absence of
  all Repository types and obsolete feature-level layers;
- the complete macOS test suite;
- the complete iOS 26 Simulator test suite;
- Release builds for generic macOS and iOS Simulator destinations.

Folder paths are not added as permanent runtime unit-test assertions.
Structural checks are migration guards; construction and behavior tests remain
the durable verification.

## Migration

1. Add central Domain model ownership and reserved Local/Remote model
   directories.
2. Replace Browse Repository names with `IBrowseService` and `BrowseService`.
3. Replace Session protocol/implementation names with `ISessionService` and
   `SessionService`.
4. Add the inert `ILocalDatabaseService` and `LocalDatabaseService` example.
5. Update `AppDependencies`, feature dependencies, ViewModels, previews, and
   tests to consume `I<ServiceName>`.
6. Move every View and ViewModel into its screen capsule.
7. Keep feature Routers at feature level and move Routes into their
   navigation-owning screen.
8. Move all models into `App/Models/Domain`.
9. Move all UI component extension points into
   `Utilities/UIComponents`.
10. Remove obsolete feature-level Data, Domain, Repositories, Services, UI,
    loose screen files, and feature-level ViewModels directories.
11. Mirror screen ownership in tests and update the README.
12. Run structural, test, and Release-build verification.

## Non-Goals

- Implementing a network client or local database.
- Adding fake Local or Remote DTOs.
- Registering the empty LocalDatabase example in DI.
- Changing screen layout or copy.
- Changing navigation routes, deep-link syntax, restoration format, session
  semantics, or async behavior.
- Adding a Service per screen when the screen has no data operation.
