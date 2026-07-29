# Hierarchical Flow Navigation Design

Date: 2026-07-29
Status: Approved concept; awaiting written-spec review

## Context

AppTemplate currently models every tab with a feature-specific router and one
typed route array, such as `[HomeRoute]`. Destination mappings are concentrated
in a feature navigation view.

The approved direction changes the ownership boundary:

- an independent flow owns one router and one navigation container;
- that router is passed through the whole screen hierarchy of the flow;
- each screen owns the routes that originate from that screen;
- each screen declares its own destination mappings at its root view;
- a screen opened by another flow automatically operates on that flow's router.

This design supersedes the typed-route-array and centralized feature
destination ownership described in the original multiplatform navigation
design. The application-level flow, deep-link, per-scene, and independent-tab
requirements remain in force.

## Definitions

### Application flow

`AppFlow` replaces the application's root interface. Its initial states remain:

- `launching`
- `authentication`
- `main`

Changing `AppFlow` is a root replacement, not a push. Successful
authentication changes the root to `main`; logout changes it to
`authentication`.

### Independent navigation flow

An independent navigation flow starts from its own zero point and owns:

- one `FlowRouter` instance;
- one `NavigationStack` or, where appropriate, `NavigationSplitView`;
- one independent navigation history.

The initial independent flows are:

- Authentication;
- Home tab;
- Browse tab;
- Settings tab.

Login, registration, verification, and password recovery are screens inside
the Authentication flow unless a future product explicitly makes one of them
an independently presented process.

Every tab is an independent flow so switching tabs preserves each tab's
history. A multi-screen sheet, onboarding process, or other independently
dismissible process also becomes a flow when it starts from a new zero point.
A one-screen sheet or alert is not automatically a flow.

### Screen route

A screen route describes destinations initiated by that screen. It does not
identify the router and it does not create a new navigation stack.

Examples:

- `HomeRoute.details` means the Home screen requests Home Details.
- `HomeDetailsRoute.navigationGuide` means Home Details requests the
  Navigation Guide.

A leaf screen with no outgoing stack navigation does not need a usable route
type. Its reserved `Navigation` folder may contain a nonconforming empty route
scaffold if structural symmetry is desired; fake placeholder route cases must
not be added.

## Selected Architecture

### Shared router contract

All independent flows use separate instances of the same reusable
`FlowRouter` implementation. Screen-facing code depends on `any IFlowRouter`;
the flow root retains the concrete `FlowRouter` so SwiftUI can observe and bind
its path.

The minimum stack-routing contract is:

```swift
@MainActor
protocol IFlowRouter: AnyObject {
    func push<Route: NavigationRoute>(_ route: Route)
    func pop()
    func popToRoot()
}
```

Routes used in a restorable path conform to:

```swift
protocol NavigationRoute: Hashable, Codable {}
```

`FlowRouter` stores a heterogeneous `NavigationPath`:

```swift
@MainActor
@Observable
final class FlowRouter: IFlowRouter {
    var path = NavigationPath()

    func push<Route: NavigationRoute>(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
```

The router controls flow history only. It does not build Views, resolve
services, own screen ViewModels, or know feature-specific route enums.

### Flow root

A flow root is a thin infrastructure View. It:

- receives or creates the flow's concrete `FlowRouter`;
- binds `router.path` to the flow's navigation container;
- constructs the initial screen and passes the same router down.

The suffix `FlowView` is used instead of `NavigationView` to avoid confusion
with SwiftUI's legacy `NavigationView` API.

```swift
struct HomeFlowView: View {
    @State private var router: FlowRouter

    init(router: FlowRouter = FlowRouter()) {
        _router = State(initialValue: router)
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            HomeView(router: router)
        }
    }
}
```

There is one flow root per independent flow, not one per screen.

### Router propagation

The exact same router instance is passed down every pushed screen:

```text
HomeFlowView
└── HomeView(router: homeRouter)
    └── HomeDetailsView(router: homeRouter)
        └── NavigationGuideView(router: homeRouter)
```

If `HomeDetailsView` is opened from Browse, it receives `browseRouter`.
Subsequent routes from Home Details are therefore appended to the Browse
history without Home Details knowing which flow owns it.

Views may retain the concrete `FlowRouter` when they need to pass it to a
destination. ViewModels receive `any IFlowRouter` and can only invoke the
shared navigation operations.

### Screen-owned destinations

Each screen places the destination mapping for its outgoing route on the
screen's non-lazy root container:

```swift
struct HomeDetailsView: View {
    let router: FlowRouter
    @State private var viewModel: HomeDetailsViewModel

    init(router: FlowRouter) {
        self.router = router
        _viewModel = State(
            initialValue: HomeDetailsViewModel(router: router)
        )
    }

    var body: some View {
        content
            .navigationDestination(for: HomeDetailsRoute.self) { route in
                switch route {
                case .navigationGuide:
                    NavigationGuideView(router: router)
                }
            }
    }
}
```

Destination modifiers must:

- be inside the flow's navigation container;
- be attached outside `List`, `Table`, lazy stacks, and lazy grids;
- switch exhaustively over the screen-owned route;
- pass the same flow router to child screens.

This keeps the destination graph next to the screen that initiates the
transition and allows a reusable screen to behave consistently in any flow.

### ViewModel interaction

A screen ViewModel receives the router through explicit initializer injection:

```swift
@MainActor
@Observable
final class HomeDetailsViewModel {
    private let router: any IFlowRouter

    init(router: any IFlowRouter) {
        self.router = router
    }

    func openNavigationGuide() {
        router.push(HomeDetailsRoute.navigationGuide)
    }

    func close() {
        router.pop()
    }
}
```

No navigation closures are injected. There is no service locator, router
lookup, environment lookup, or global router singleton.

### Tabs and application ownership

`AppRouter` remains scene-scoped and owns application-level state:

- current `AppFlow`;
- selected tab;
- pending deep-link intent;
- one `FlowRouter` for Authentication;
- one `FlowRouter` for each tab.

`MainFlowView` presents the tab shell and injects the appropriate router into
each tab flow:

```text
MainFlowView
├── HomeFlowView(homeRouter)
├── BrowseFlowView(browseRouter)
└── SettingsFlowView(settingsRouter)
```

Authentication uses its own `FlowRouter`; it never appends authentication
screens to a tab's path. Successful authentication resets the Authentication
path, selects the Home tab, resets every tab path, and changes `AppFlow` to
`main`. Logout resets every tab path, resets the Authentication path, and
changes `AppFlow` to `authentication`. This prevents navigation state from one
signed-in session leaking into another.

## Presentations

Stack history and transient presentation state have different lifetimes.

- `FlowRouter` owns the heterogeneous push path.
- A screen ViewModel owns its screen-specific sheet, popover, dialog, and
  alert route state.
- A presented multi-screen process creates a new independent `FlowRouter` and
  flow root.
- Transient presentations are not restored in navigation snapshots.

This avoids type-erasing arbitrary modal routes into the shared router while
keeping the initiating screen's presentation behavior explicit and testable.

## Deep Links

`DeepLinkParser` continues to produce a typed `NavigationIntent`. `AppRouter`
applies an intent by:

1. selecting the required `AppFlow`;
2. selecting the required tab;
3. resetting the target flow to its root;
4. pushing the canonical concrete screen-owned route sequence for the intent.

Deep links never mutate a View directly. A deep link route sequence must use
the same concrete route types as interactive navigation.

## Restoration and Snapshots

Typed arrays in `NavigationSnapshot` are replaced by a codable representation
of each heterogeneous `NavigationPath`.

- Every value appended to a restorable path must conform to
  `NavigationRoute`.
- A snapshot remains scene-scoped and schema-versioned.
- Each tab's path is encoded independently.
- A path whose codable representation is unavailable is treated as
  non-restorable and resets safely.
- Unknown, renamed, corrupt, or incompatible route data resets only the
  affected flow where possible.
- Alerts, sheets, authentication form fields, and other transient state are
  excluded.

Snapshot tests must prove round-trip restoration for paths containing more
than one concrete screen-route type.

## Folder Ownership

The target structure is:

```text
App/
└── Navigation/
    ├── Core/
    │   ├── NavigationRoute.swift
    │   ├── IFlowRouter.swift
    │   └── FlowRouter.swift
    ├── Routing/
    │   ├── AppFlow.swift
    │   └── AppRouter.swift
    └── Snapshots/

Features/
└── Home/
    ├── Flow/
    │   └── HomeFlowView.swift
    └── Screens/
        ├── Home/
        │   └── Navigation/
        │       └── HomeRoute.swift
        ├── HomeDetails/
        │   └── Navigation/
        │       └── HomeDetailsRoute.swift
        └── NavigationGuide/
            └── Navigation/
                └── NavigationGuideRoute.swift
```

Feature-specific router classes are removed after all consumers migrate to
independent `FlowRouter` instances. A screen's `View`, `ViewModel`, `State`,
and `Model` ownership remains unchanged.

## Error Handling

- `pop()` on an empty path is a safe no-op.
- Unsupported deep links fall back to the nearest valid flow root.
- Corrupt or incompatible snapshot data resets safely without crashing.
- No navigation operation uses `fatalError`, forced casts, or force unwraps.
- Screen route switches remain exhaustive.
- A route must never contain a View, ViewModel, service, router, or full domain
  object; it carries only stable identifiers and small navigation parameters.

## Testing Strategy

Unit tests cover:

- `FlowRouter` push, pop, and pop-to-root with heterogeneous route types;
- isolation between two `FlowRouter` instances;
- injection through `any IFlowRouter`;
- Codable round trips for every nonempty screen route;
- snapshot round trips with mixed route types;
- safe handling of corrupt and unsupported snapshot schemas;
- AppFlow authentication/main replacement;
- independent history preservation for every tab;
- deep links that construct mixed screen-route paths;
- reusable screen routing under two different parent flow routers.

Focused UI or integration checks cover:

- Home to Home Details to Navigation Guide;
- opening the reusable Home Details screen from another flow;
- native back navigation updating the bound path;
- switching tabs without losing history;
- logout replacing the root and preventing access to the previous main
  hierarchy;
- destination mappings on iPhone, iPad, and Mac.

## Acceptance Criteria

- AppFlow owns launching, authentication, and main root replacement.
- Authentication and every tab start as independent flows.
- Every independent flow owns exactly one router instance and one navigation
  container.
- The same router instance is passed through the complete screen hierarchy of
  its flow.
- Screens own outgoing route definitions and destination mappings.
- Screen ViewModels depend on `any IFlowRouter`, not concrete feature routers
  or navigation closures.
- A reusable screen operates correctly under different parent flow routers.
- Every tab preserves independent history.
- Mixed screen-route paths round-trip through a versioned scene snapshot.
- The project builds and tests on iOS/iPadOS 26 and macOS 26.
