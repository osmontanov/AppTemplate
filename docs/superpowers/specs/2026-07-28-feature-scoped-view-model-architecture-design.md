# Feature-Scoped ViewModel Architecture Design

Date: 2026-07-28
Status: Ready for written review

## Context

AppTemplate is a SwiftUI boilerplate targeting iOS 26, iPadOS 26, and macOS 26. It already has:

- typed, scene-scoped navigation;
- deep links and versioned navigation restoration;
- an immutable, type-safe application dependency graph;
- app-wide session state;
- async, actor-compatible service protocols;
- feature-scoped Browse presentation stores.

The next architectural layer standardizes the relationship between dependencies, services, repositories, navigation, Views, and ViewModels. Every full user-facing screen will have a ViewModel, while infrastructure containers and small stateless subviews will remain plain SwiftUI Views.

The design must stay easy to construct, explicit at compile time, compatible with multi-window navigation, and ready for future network and local-database implementations.

## Goals

- Give every full user-facing screen one concrete ViewModel.
- Use Swift Observation rather than `ObservableObject`.
- Keep ViewModel ownership stable and obvious.
- Preserve the existing type-safe DI graph and scene-scoped routers.
- Keep feature call sites short as the number of services grows.
- Prevent ViewModels from accessing the entire application container.
- Keep network and persistence details behind repository or service protocols.
- Preserve deep linking and restoration without requiring a ViewModel to exist.
- Support deterministic previews and parallel unit tests.
- Retain the existing async cancellation and stale-response protections.

## Non-Goals

- Introduce `BaseView`, `BaseViewModel`, or a marker ViewModel protocol.
- Build a runtime service registry, resolver, or property-wrapper DI system.
- Add a generic ViewModel factory.
- Make every small row, section, or stateless component own a ViewModel.
- Move SwiftUI-only mechanisms such as `DismissAction`, focus, or layout state into ViewModels.
- Implement the future network stack or local database in this increment.
- Move navigation paths into ViewModels.
- Make routers load domain data.

## Research Basis

Apple's current SwiftUI model-data guidance recommends:

- applying `@Observable` to reference models used by SwiftUI;
- storing an observable model owned by a View in `@State`;
- using `@Bindable` only when a control or container requires a binding;
- placing one source of truth at the narrowest owning boundary;
- passing observable models explicitly or through typed Environment according to scope.

Primary references:

- [Managing model data in your app](https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app)
- [Model data](https://developer.apple.com/documentation/swiftui/model-data)
- [Migrating from ObservableObject to Observable](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)
- [Discover Observation in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10149/)
- [Managing user interface state](https://developer.apple.com/documentation/swiftui/managing-user-interface-state)

## Considered Approaches

### Whole Application Container Injection

Every ViewModel would receive `AppDependencies`.

This provides short call sites but hides actual requirements, couples every feature to the complete application graph, and permits dependency lookup behavior that can drift toward a service locator.

### Every Dependency as a Separate Argument

Every View and ViewModel would receive each repository, service, store, and router separately.

This maximizes visibility but causes long initializers and repeated wiring as a feature grows.

### Feature-Scoped Dependencies

The selected approach groups immutable services by feature while keeping runtime state and navigation in their correct scopes.

It provides short call sites without giving a feature access to unrelated services.

## Architectural Overview

```text
AppTemplateApp                                      app-wide
├── AppDependencies
│   ├── BrowseDependencies
│   │   └── BrowseRepository
│   └── SessionDependencies
│       └── SessionService
├── SessionStore                                    app-wide observable state
└── WindowGroup
    └── AppSceneView                                one per window
        ├── AppSceneNavigationLifecycle
        ├── AppRouter                               scene-scoped
        │   ├── HomeRouter
        │   ├── BrowseRouter
        │   └── SettingsRouter
        ├── NavigationSnapshot                      scene-scoped persistence
        └── User-facing screens
            └── @State ConcreteViewModel            screen-scoped
```

Future infrastructure fits below the existing repository boundary:

```text
BrowseViewModel
    ↓
BrowseRepository
    ├── NetworkClient
    └── LocalDatabase
```

Views and ViewModels do not know whether a repository result came from a server, a cache, or a database.

## Ownership and Lifetime

| Object | Owner | Lifetime |
| --- | --- | --- |
| `AppDependencies` | `AppTemplateApp` | Application |
| Feature dependency values | `AppDependencies` | Application |
| Repositories and services | `AppDependencies` | Application |
| `SessionStore` | `AppTemplateApp` | Application |
| `AppSceneNavigationLifecycle` | `AppSceneView` | Window scene |
| `AppRouter` and child routers | Scene lifecycle | Window scene |
| `NavigationSnapshot` data | `@SceneStorage` | Window scene |
| Screen ViewModel | Owning screen View through `@State` | Screen identity |
| Small local control state | The narrowest View through `@State` | View identity |

The router and immutable feature dependencies passed to a screen must remain stable for that screen identity. A destination whose identifier changes must receive a new SwiftUI identity. Typed navigation routes already provide this identity for Browse detail destinations.

## Dependency Graph

`AppDependencies` becomes an application composition of feature-scoped dependency values:

```swift
nonisolated struct AppDependencies: Sendable {
    let browse: BrowseDependencies
    let session: SessionDependencies
}

nonisolated struct BrowseDependencies: Sendable {
    let repository: any BrowseRepository
}

nonisolated struct SessionDependencies: Sendable {
    let service: any SessionService
}
```

`BrowseDependencies` lives in `Features/Browse/Domain/BrowseDependencies.swift`.
`SessionDependencies` lives in `Core/Session/SessionDependencies.swift`.
Empty dependency groups are not created. Home and About have no service
dependencies, so their ViewModels receive only the inputs they use.

`AppDependencies.live()`, `preview(...)`, and `test(...)` remain the only supported graph-construction paths:

- `live()` creates declared production implementations;
- `preview(...)` creates deterministic preview implementations;
- `test(...)` requires caller-supplied test services.

`AppTemplateApp` creates shared session state from the scoped service:

```swift
let dependencies = AppDependencies.live()
let sessionStore = SessionStore(service: dependencies.session.service)
```

No ViewModel receives `AppDependencies`. A ViewModel receives either a feature dependency value or the exact runtime collaborator it needs.

## Feature Composition Boundary

Application and feature shell Views connect the three independent scopes:

```swift
HomeNavigationView(
    router: router.home
)

BrowseNavigationView(
    router: router.browse,
    dependencies: dependencies.browse
)

SettingsNavigationView(
    router: router.settings,
    sessionStore: sessionStore
)
```

The typed SwiftUI Environment remains appropriate for the app-wide `SessionStore` at the outer application boundary. `AppRootView` and `AppShellView` may read it and pass it explicitly into screen initializers. A ViewModel never performs an Environment lookup.

This preserves the existing hybrid DI rule:

- immutable app services originate from `AppDependencies`;
- app-wide observable UI state may cross the broad hierarchy through typed Environment;
- feature Views and ViewModels declare concrete requirements through initializers.

## View and ViewModel Relationship

Every full user-facing screen owns one concrete, non-optional ViewModel:

```swift
@MainActor
@Observable
final class BrowseListViewModel {
    private let dependencies: BrowseDependencies

    init(dependencies: BrowseDependencies) {
        self.dependencies = dependencies
    }
}

struct BrowseNavigationView: View {
    @Bindable var router: BrowseRouter
    @State private var viewModel: BrowseListViewModel

    init(
        router: BrowseRouter,
        dependencies: BrowseDependencies
    ) {
        self.router = router
        _viewModel = State(
            initialValue: BrowseListViewModel(
                dependencies: dependencies
            )
        )
    }
}
```

Rules:

- ViewModels are `@MainActor @Observable final class`.
- The owning View stores its ViewModel in private `@State`.
- ViewModel initialization is synchronous and has no side effects.
- The View starts lifecycle work through `.task` or `.task(id:)`.
- A View uses `@Bindable` only when SwiftUI requires `$path`, `$text`, or another binding.
- Child Views receive small values, bindings, or callbacks rather than the entire ViewModel unless they are genuine co-owners of the same screen presentation state.
- SwiftUI presentation primitives such as `dismiss`, focus, and layout remain in the View.
- ViewModels contain presentation state, input transformation, async orchestration, and user-intent methods.
- Domain work stays in repositories, services, or future use cases.

There is no shared `ViewModel` protocol because it would not add behavior or safety.

## Navigation Relationship

Routers remain the only owners of navigation state:

- `AppRouter` owns root flow, selected section, pending intent, and feature routers.
- Feature routers own typed paths and typed presentation routes.
- Views bind `NavigationStack` and presentation modifiers to routers.
- Deep links and restoration update routers directly.
- Destination mapping remains in SwiftUI Views.
- Routers never create Views, ViewModels, or repositories.

A ViewModel receives a router only when it performs programmatic navigation or presentation as part of a user intent. A ViewModel is not given a router merely for uniformity.

Declarative `NavigationLink(value:)` may continue to write a typed route through the View's stack binding without a redundant ViewModel method. This is SwiftUI navigation composition, not business logic.

No navigation path is copied into ViewModel state.

## Screen ViewModels

### AuthenticationViewModel

Inputs:

- shared `SessionStore`;
- scene `AppRouter`.

Responsibilities:

- expose display-safe restoration failure state;
- request sign-in;
- retry session restoration;
- cancel authentication and clear the scene's pending intent.

### HomeViewModel

Inputs:

- `HomeRouter`.

Responsibilities:

- open Home details;
- present the navigation guide;
- request, confirm, or cancel navigation reset;
- expose alert presentation state suitable for a SwiftUI binding.

### HomeDetailsViewModel

Inputs:

- none.

Responsibilities:

- provide the immutable presentation model for the Home details screen.

### NavigationGuideViewModel

Inputs:

- none.

Responsibilities:

- provide navigation-guide presentation items.

The View owns the SwiftUI `dismiss` action.

### BrowseListViewModel

Inputs:

- `BrowseDependencies`.

Responsibilities:

- load Browse records;
- expose `BrowseListState`;
- retry;
- own and cancel list-loading work;
- reject stale or cancelled results.

This replaces `BrowseListStore` without changing its proven behavior.

### BrowseDetailViewModel

Inputs:

- stable `BrowseItem.ID`;
- `BrowseDependencies`.

Responsibilities:

- load one record by identifier;
- distinguish `content`, `notFound`, and `failed`;
- retry;
- own and cancel detail-loading work;
- reject stale or cancelled results.

This replaces `BrowseDetailStore` without changing its proven behavior.

### SettingsViewModel

Inputs:

- shared `SessionStore`;

Responsibilities:

- expose session presentation state;
- request sign-out;
- expose display-safe sign-out failure state;

The Settings View retains its declarative `NavigationLink(value:)` for About.
`SettingsRouter` remains a View dependency for the `NavigationStack` binding and
is not injected into `SettingsViewModel`.

### AboutViewModel

Inputs:

- none.

Responsibilities:

- provide supported-platform and template-example presentation data.

## Async Lifecycle

View lifecycle starts screen work:

```swift
.task {
    await viewModel.load()
}

.onDisappear {
    viewModel.cancel()
}
```

Browse ViewModels retain the existing ownership model:

1. Starting a load increments a request version.
2. Any previous owned task is cancelled.
3. The ViewModel publishes `loading`.
4. The service call runs across the async `Sendable` boundary.
5. Cancellation is checked after suspension.
6. A result is published only when its version is still current.
7. A non-cooperative stale response is ignored.

Session operations continue to run through the shared `SessionStore`, which retains its command-version and startup-task coalescing behavior.

No initializer starts asynchronous work.

## Error Handling

- Service and repository errors never pass directly into UI text.
- ViewModels expose typed, display-safe presentation failures.
- Cancellation is a normal lifecycle outcome and does not become a user-visible error.
- A missing Browse record produces `notFound`, not `failed`.
- A stale async response cannot overwrite a newer result.
- A failed sign-out restores the previous stable authenticated state.
- Corrupt navigation state resets safely and remains a router responsibility.
- Unsupported deep links fall back safely and remain a navigation-lifecycle responsibility.

## Previews

Previews use `AppDependencies.preview(...)` and pass the appropriate feature scope:

```swift
BrowseNavigationView(
    router: BrowseRouter(),
    dependencies: dependencies.browse
)
```

Screen ViewModels may accept deterministic presentation inputs where a static screen needs multiple preview states. Production initializers never fall back to preview fixtures.

## Testing Strategy

### ViewModel Unit Tests

Every ViewModel is constructed directly with:

- a real lightweight feature router where navigation behavior matters;
- actor-backed or immutable test repositories and services;
- a test `SessionStore` where shared session behavior matters.

Tests cover:

- presentation data for static screens;
- navigation and presentation user intents;
- success and failure states;
- retry behavior;
- cancellation;
- stale-response rejection;
- `notFound`;
- session restoration, sign-in, and sign-out integration.

`BrowseStoreTests` becomes `BrowseViewModelTests`, preserving all existing concurrency coverage.

### Existing Navigation Tests

Router, deep-link, lifecycle, and snapshot tests remain independent of ViewModels. This proves navigation can operate before a screen is instantiated.

### Construction and Platform Verification

Construction tests instantiate every full screen with explicit dependencies. The complete test suite and builds run against:

- the universal iOS target, which covers iPhone and iPad device families;
- the native macOS target.

## File and Naming Direction

Presentation types use the `ViewModel` suffix:

- `BrowseListStore` becomes `BrowseListViewModel`;
- `BrowseDetailStore` becomes `BrowseDetailViewModel`;
- new screen-specific types use `<Screen>ViewModel`.

Feature dependency values live near their owning service boundary:

- `BrowseDependencies` in the Browse feature;
- `SessionDependencies` in Core Session or App Dependencies.

Infrastructure containers keep their existing names and do not receive artificial ViewModels:

- `AppSceneView`;
- `AppRootView`;
- `AppShellView`;
- small stateless rows and sections.

## Dependency Direction Rules

Allowed:

```text
View -> ViewModel
View -> Router binding
ViewModel -> feature Repository or shared Store
ViewModel -> feature Router when programmatic navigation is required
Repository -> NetworkClient or LocalDatabase
App composition root -> every concrete implementation
```

Forbidden:

```text
ViewModel -> AppDependencies
ViewModel -> SwiftUI Environment lookup
Router -> View, ViewModel, Repository, Network, or Database
View -> NetworkClient or LocalDatabase
Repository -> ViewModel or Router
Global resolve(), mutable registration, or production fixture fallback
```

## Acceptance Criteria

- Every full user-facing screen has one concrete ViewModel.
- Infrastructure containers and small stateless subviews do not get artificial ViewModels.
- Every ViewModel is non-optional, `@MainActor`, and Observation-based.
- Every owning View stores its ViewModel in `@State`.
- `AppDependencies` exposes feature-scoped dependency values.
- No ViewModel receives the whole application container.
- Routers remain scene-scoped and independent of ViewModels.
- Deep links and restoration work before destination ViewModels exist.
- Browse async behavior retains cancellation and stale-response safety.
- Shared session behavior remains consistent across windows.
- Previews and tests use explicit dependency construction.
- The project builds and all tests pass for iOS/iPadOS and macOS targets.
