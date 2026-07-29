# Hierarchical Flow Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace feature-specific typed-array routers with one reusable router per independent flow, pass that router through the screen hierarchy, and move outgoing routes and destination mappings into their originating screens.

**Architecture:** `AppRouter` remains scene-scoped and owns root flow selection plus independent `FlowRouter` instances for Authentication and every tab. Each `FlowRouter` stores a heterogeneous `NavigationPath`; screen ViewModels receive `any IFlowRouter`, while flow and destination Views retain the concrete router needed for SwiftUI bindings and child construction. Screen-owned `NavigationRoute` enums and local `.navigationDestination` modifiers define the navigation graph.

**Tech Stack:** Swift 6 language mode with Swift 5 compatibility, SwiftUI, Observation, `NavigationStack`, `NavigationPath`, Swift Testing, Xcode 26.

## Global Constraints

- Deployment targets remain iOS 26.0, iPadOS 26.0, and macOS 26.0.
- Use native SwiftUI navigation with no third-party navigation dependency.
- `AppRouter` and every `FlowRouter` are scene-scoped and `@MainActor`; no global router singleton is allowed.
- Authentication and every tab start as independent flows with independent history.
- Every independent flow owns exactly one router instance and one navigation container.
- Screens own outgoing routes and destination mappings; routes contain only stable identifiers and small parameters.
- Screen ViewModels receive navigation through explicit `any IFlowRouter` initializer injection; no injected navigation closures or environment router lookup.
- Destination modifiers stay inside the owning navigation container and outside lazy containers.
- Existing unrelated working-tree changes must be preserved.

---

## Target File Map

### Shared navigation

- Create `AppTemplate/App/Navigation/Core/NavigationRoute.swift`: marker protocol for Codable, Hashable, Sendable screen routes.
- Create `AppTemplate/App/Navigation/Core/IFlowRouter.swift`: screen-facing stack operations.
- Create `AppTemplate/App/Navigation/Core/FlowRouter.swift`: observable heterogeneous path and concrete restoration operation.
- Delete `AppTemplate/App/Navigation/Core/StackRouting.swift`: obsolete associated-type router abstraction.
- Create `AppTemplate/App/Navigation/Snapshots/FlowPathSnapshot.swift`: Equatable Codable wrapper around a path representation.
- Modify `AppTemplate/App/Navigation/Snapshots/NavigationSnapshot.swift`: schema 2 snapshots for heterogeneous tab paths.
- Modify `AppTemplate/App/Navigation/Routing/AppRouter.swift`: independent Authentication/Home/Browse/Settings `FlowRouter` ownership and reset policy.
- Modify `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`: distinguish restored launch from new sign-in/logout transitions.

### Flow containers

- Create `AppTemplate/Features/Authentication/Flow/AuthenticationFlowView.swift`.
- Create `AppTemplate/Features/Home/Flow/HomeFlowView.swift`.
- Create `AppTemplate/Features/Browse/Flow/BrowseFlowView.swift`.
- Create `AppTemplate/Features/Settings/Flow/SettingsFlowView.swift`.
- Modify `AppTemplate/App/Navigation/Containers/AppRootView.swift`.
- Modify `AppTemplate/App/Navigation/Containers/AppShellView.swift`.

### Screen navigation

- Modify `AppTemplate/Features/Home/Screens/Home/Navigation/HomeRoute.swift`.
- Create `AppTemplate/Features/Home/Screens/HomeDetails/Navigation/HomeDetailsRoute.swift`.
- Create reserved leaf scaffolds:
  - `AppTemplate/Features/Authentication/Screens/Authentication/Navigation/AuthenticationRoute.swift`
  - `AppTemplate/Features/Browse/Screens/BrowseDetail/Navigation/BrowseDetailRoute.swift`
  - `AppTemplate/Features/Home/Screens/NavigationGuide/Navigation/NavigationGuideRoute.swift`
  - `AppTemplate/Features/Settings/Screens/About/Navigation/AboutRoute.swift`
- Modify Home, Home Details, Navigation Guide, Browse, and Settings Views and ViewModels.
- Move `AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift` to `AppTemplate/Features/Browse/Screens/Browse/View/BrowseView.swift`.
- Delete `AppTemplate/Features/Home/Navigation/HomeRouter.swift`.
- Delete `AppTemplate/Features/Browse/Navigation/BrowseRouter.swift`.
- Delete `AppTemplate/Features/Settings/Navigation/SettingsRouter.swift`.

### Tests and documentation

- Move `AppTemplateTests/App/Navigation/Core/StackRoutingTests.swift` to `AppTemplateTests/App/Navigation/Core/FlowRouterTests.swift`.
- Modify the AppRouter, lifecycle, snapshot, ViewModel, and construction tests named in the tasks below.
- Modify `README.md` to describe independent flow routers, screen-owned routes, and `NavigationPath` snapshots.

---

### Task 1: Reusable Flow Router Core

**Files:**
- Create: `AppTemplate/App/Navigation/Core/NavigationRoute.swift`
- Create: `AppTemplate/App/Navigation/Core/IFlowRouter.swift`
- Create: `AppTemplate/App/Navigation/Core/FlowRouter.swift`
- Move: `AppTemplateTests/App/Navigation/Core/StackRoutingTests.swift` → `AppTemplateTests/App/Navigation/Core/FlowRouterTests.swift`

**Interfaces:**
- Consumes: SwiftUI `NavigationPath`.
- Produces: `NavigationRoute`, `IFlowRouter`, and `FlowRouter.init(path:)`, `push(_:)`, `pop()`, `popToRoot()`, and `replacePath(with:)`.

- [ ] **Step 1: Replace the old core test with failing heterogeneous-router tests**

```swift
import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct FlowRouterTests {
    @Test
    func oneRouterStoresDifferentScreenRouteTypes() {
        let router = FlowRouter()

        router.push(FirstTestRoute.details)
        router.push(SecondTestRoute.guide)

        #expect(router.path.count == 2)
        #expect(router.path.codable != nil)
    }

    @Test
    func popAndPopToRootAreSafe() {
        let router = FlowRouter()
        router.pop()
        #expect(router.path.isEmpty)

        router.push(FirstTestRoute.details)
        router.push(SecondTestRoute.guide)
        router.pop()
        #expect(router.path.count == 1)

        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test
    func routersKeepIndependentHistories() {
        let first = FlowRouter()
        let second = FlowRouter()

        first.push(FirstTestRoute.details)

        #expect(first.path.count == 1)
        #expect(second.path.isEmpty)
    }

    @Test
    func existentialContractCanPushAConcreteScreenRoute() {
        let concrete = FlowRouter()
        let router: any IFlowRouter = concrete

        router.push(FirstTestRoute.details)

        #expect(concrete.path.count == 1)
    }
}

private nonisolated enum FirstTestRoute: String, NavigationRoute {
    case details
}

private nonisolated enum SecondTestRoute: String, NavigationRoute {
    case guide
}
```

- [ ] **Step 2: Run the focused test and verify the new types are missing**

Run:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS' -derivedDataPath /tmp/AppTemplate-flow-router-core -only-testing:AppTemplateTests/FlowRouterTests
```

Expected: FAIL because `FlowRouter`, `IFlowRouter`, and `NavigationRoute` do not exist.

- [ ] **Step 3: Add the route and router contracts**

`NavigationRoute.swift`:

```swift
import Foundation

nonisolated protocol NavigationRoute: Codable, Hashable, Sendable {}
```

`IFlowRouter.swift`:

```swift
@MainActor
protocol IFlowRouter: AnyObject {
    func push<Route: NavigationRoute>(_ route: Route)
    func pop()
    func popToRoot()
}
```

- [ ] **Step 4: Add the concrete heterogeneous router**

`FlowRouter.swift`:

```swift
import Observation
import SwiftUI

@MainActor
@Observable
final class FlowRouter: IFlowRouter {
    var path: NavigationPath

    init(path: NavigationPath = NavigationPath()) {
        self.path = path
    }

    func push<Route: NavigationRoute>(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else {
            return
        }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func replacePath(with path: NavigationPath) {
        self.path = path
    }
}
```

- [ ] **Step 5: Run the focused test and verify it passes**

Run the command from Step 2.

Expected: PASS for all `FlowRouterTests`.

- [ ] **Step 6: Commit the core only if it does not capture unrelated staged work**

```bash
git add AppTemplate/App/Navigation/Core/NavigationRoute.swift AppTemplate/App/Navigation/Core/IFlowRouter.swift AppTemplate/App/Navigation/Core/FlowRouter.swift AppTemplateTests/App/Navigation/Core/StackRoutingTests.swift AppTemplateTests/App/Navigation/Core/FlowRouterTests.swift
git commit --only AppTemplate/App/Navigation/Core/NavigationRoute.swift AppTemplate/App/Navigation/Core/IFlowRouter.swift AppTemplate/App/Navigation/Core/FlowRouter.swift AppTemplateTests/App/Navigation/Core/StackRoutingTests.swift AppTemplateTests/App/Navigation/Core/FlowRouterTests.swift -m "feat: add reusable flow router"
```

---

### Task 2: Atomic Hierarchical Navigation Migration

**Files:**
- Create and modify every production and test file listed in the Target File
  Map.
- Create: `AppTemplate/Features/Browse/Flow/BrowseFlowView.swift`
- Move: `AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift` → `AppTemplate/Features/Browse/Screens/Browse/View/BrowseView.swift`
- Modify: `AppTemplate/Features/Browse/Screens/Browse/Navigation/BrowseRoute.swift`
- Create: `AppTemplate/Features/Browse/Screens/BrowseDetail/Navigation/BrowseDetailRoute.swift`
- Modify: Browse View and `BrowseListViewModel.swift`
- Create: `AppTemplate/Features/Settings/Flow/SettingsFlowView.swift`
- Modify: Settings Route, View, and ViewModel
- Create: `AppTemplate/Features/Settings/Screens/About/Navigation/AboutRoute.swift`
- Create: `AppTemplate/Features/Authentication/Flow/AuthenticationFlowView.swift`
- Create: `AppTemplate/Features/Authentication/Screens/Authentication/Navigation/AuthenticationRoute.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppRootView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppShellView.swift`
- Delete: the three feature Router files and `StackRouting.swift`
- Modify: Browse, Settings, Authentication, and Project construction tests.

**Interfaces:**
- Consumes: Task 1 `FlowRouter`, `IFlowRouter`, and `NavigationRoute`.
- Produces: schema-2 mixed-route snapshots, an AppRouter with four independent
  flow routers, four flow roots, and screen-owned navigation for all sample
  features.

This is one atomic task because changing `AppRouter` from feature router types
to `FlowRouter` immediately changes AppShell and every feature-flow
initializer. Splitting those changes would leave the application target
uncompilable rather than producing independently reviewable deliverables.

- [ ] **Step 1: Rewrite failing router, snapshot, lifecycle, and screen routing tests**

Update AppRouter tests to require injected Authentication/Home/Browse/Settings
`FlowRouter` identity and these policies:

```swift
@Test
func successfulNewAuthenticationResetsHistoriesBeforeReplayingIntent() {
    let router = AppRouter(flow: .authentication)
    router.authentication.push(AuthenticationTestRoute.step)
    router.home.push(HomeRoute.details)
    router.settings.push(SettingsRoute.about)
    _ = router.handle(.browseItem(id: "swiftui"))

    #expect(router.completeAuthentication(succeeded: true) == .applied)
    #expect(router.flow == .main)
    #expect(router.authentication.path.isEmpty)
    #expect(router.home.path.isEmpty)
    #expect(router.settings.path.isEmpty)
    #expect(router.browse.path.count == 1)
}

@Test
func authenticatedColdLaunchPreservesRestoredTabHistories() {
    let router = AppRouter(flow: .launching)
    router.home.push(HomeRoute.details)

    _ = router.finishLaunching(isAuthenticated: true)

    #expect(router.flow == .main)
    #expect(router.home.path.count == 1)
}

private nonisolated enum AuthenticationTestRoute: String, NavigationRoute {
    case step
}
```

Update snapshot tests to require a mixed concrete path:

```swift
let router = AppRouter(selectedSection: .home)
router.home.push(HomeRoute.details)
router.home.push(HomeDetailsRoute.navigationGuide)

let data = try NavigationSnapshotCodec.encode(router.snapshot)
let restored = AppRouter()

#expect(restored.restore(from: data) == .restored)
#expect(restored.home.path.count == 2)
#expect(restored.snapshot == router.snapshot)
```

Retain unchanged/changed encoding, corrupt data, schema rejection, unknown
Browse identifier, queued deep link, contextual fallback, and independent
scene tests. Replace typed-array equality assertions with `count`, `isEmpty`,
or `snapshot` equality.

Add Home tests for `HomeRoute.details`, `HomeRoute.navigationGuide`,
`HomeDetailsRoute.navigationGuide`, local alert state, and Navigation Guide
`pop()`. Prove reusable-screen isolation with two parent routers:

```swift
let homeRouter = FlowRouter()
let browseRouter = FlowRouter()
let homeDetails = HomeDetailsViewModel(router: homeRouter)
let reusedDetails = HomeDetailsViewModel(router: browseRouter)

homeDetails.openNavigationGuide()

#expect(homeRouter.path.count == 1)
#expect(browseRouter.path.isEmpty)

reusedDetails.openNavigationGuide()

#expect(homeRouter.path.count == 1)
#expect(browseRouter.path.count == 1)
```

Add:

```swift
let router = FlowRouter()
let browse = BrowseListViewModel(
    dependencies: dependencies,
    router: router
)
browse.openItem(id: "swiftui")
#expect(router.path.count == 1)
```

and:

```swift
let router = FlowRouter()
let settings = SettingsViewModel(
    sessionStore: store,
    router: router
)
settings.openAbout()
#expect(router.path.count == 1)
```

Update construction tests to use `BrowseFlowView`, `SettingsFlowView`,
`AuthenticationFlowView`, and `HomeFlowView`.

- [ ] **Step 2: Run the rewritten navigation suites and verify failure**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS' -derivedDataPath /tmp/AppTemplate-hierarchical-red -only-testing:AppTemplateTests/AppRouterTests -only-testing:AppTemplateTests/NavigationSnapshotTests -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests -only-testing:AppTemplateTests/HomeViewModelTests -only-testing:AppTemplateTests/HomeDetailsViewModelTests -only-testing:AppTemplateTests/NavigationGuideViewModelTests -only-testing:AppTemplateTests/BrowseListViewModelTests -only-testing:AppTemplateTests/SettingsViewModelTests -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: FAIL because AppRouter still owns feature routers, snapshots still
store typed arrays, and the new flow/screen interfaces do not exist.

- [ ] **Step 3: Add heterogeneous path snapshots**

`FlowPathSnapshot.swift`:

```swift
import SwiftUI

struct FlowPathSnapshot: Codable, Equatable {
    let representation: NavigationPath.CodableRepresentation?

    init(path: NavigationPath) {
        representation = path.codable
    }

    var restoredPath: NavigationPath? {
        representation.map(NavigationPath.init)
    }

    var isRestorable: Bool {
        representation != nil
    }
}
```

Do not conform this type to Sendable because SwiftUI explicitly makes the
representation's Sendable conformance unavailable.

Change NavigationSnapshot to schema 2:

```swift
struct NavigationSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    var selectedSection: AppSection
    var homePath: FlowPathSnapshot
    var browsePath: FlowPathSnapshot
    var settingsPath: FlowPathSnapshot
}
```

Its initializer accepts concrete `NavigationPath` values.
`NavigationSnapshotCodec.encode` throws
`NavigationSnapshotEncodingError.nonRestorablePath` when any path lacks a
codable representation.

```swift
init(
    schemaVersion: Int = Self.currentSchemaVersion,
    selectedSection: AppSection,
    homePath: NavigationPath,
    browsePath: NavigationPath,
    settingsPath: NavigationPath
) {
    self.schemaVersion = schemaVersion
    self.selectedSection = selectedSection
    self.homePath = FlowPathSnapshot(path: homePath)
    self.browsePath = FlowPathSnapshot(path: browsePath)
    self.settingsPath = FlowPathSnapshot(path: settingsPath)
}

static func encode(_ snapshot: NavigationSnapshot) throws -> Data {
    guard snapshot.homePath.isRestorable,
          snapshot.browsePath.isRestorable,
          snapshot.settingsPath.isRestorable else {
        throw NavigationSnapshotEncodingError.nonRestorablePath
    }
    return try JSONEncoder().encode(snapshot)
}
```

- [ ] **Step 4: Migrate AppRouter and lifecycle**

AppRouter owns:

```swift
let authentication: FlowRouter
let home: FlowRouter
let browse: FlowRouter
let settings: FlowRouter
```

Implement:

- authenticated cold launch preserves restored tab paths and resets only
  Authentication;
- unauthenticated cold launch resets every flow and selects Home;
- successful new authentication resets every flow, selects Home, enters Main,
  then replays one pending intent;
- failed/cancelled authentication clears the pending intent and resets
  Authentication;
- `requireAuthentication()` resets every flow and enters Authentication;
- Browse deep links reset Browse, then push `BrowseRoute.item(id:)`;
- a section-root intent resets only its selected tab.

Restore `FlowPathSnapshot.restoredPath` with `replacePath(with:)`; treat a
missing representation as corrupt data.

Change lifecycle synchronization to:

```swift
case .unauthenticated:
    if router.flow == .launching {
        _ = router.finishLaunching(isAuthenticated: false)
    } else if router.flow == .main {
        router.requireAuthentication()
    }
case .authenticated:
    if router.flow == .launching {
        _ = router.finishLaunching(isAuthenticated: true)
    } else if router.flow == .authentication {
        _ = router.completeAuthentication(succeeded: true)
    }
```

- [ ] **Step 5: Implement Home as the screen-owned routing reference**

Define:

```swift
nonisolated enum HomeRoute: String, NavigationRoute {
    case details
    case navigationGuide
}

nonisolated enum HomeDetailsRoute: String, NavigationRoute {
    case navigationGuide
}

nonisolated enum NavigationGuideRoute {}
```

Remove `HomeSheetRoute`; retain local `HomeAlertRoute`.

- `HomeViewModel` receives `any IFlowRouter`, pushes its two `HomeRoute`
  cases, owns `alert`, and resets the router on confirmation.
- `HomeDetailsViewModel` receives `any IFlowRouter` and pushes
  `HomeDetailsRoute.navigationGuide`.
- `NavigationGuideViewModel` receives `any IFlowRouter` and calls `pop()`.
- `HomeFlowView` owns only `NavigationStack(path:)`.
- `HomeView` locally maps `HomeRoute` to `HomeDetailsView(router:)` and
  `NavigationGuideView(router:)`.
- `HomeDetailsView` locally maps `HomeDetailsRoute` to
  `NavigationGuideView(router:)`.
- Navigation Guide's Done action calls the ViewModel instead of environment
  dismiss.

- [ ] **Step 6: Migrate Browse**

- Make `BrowseRoute` conform to `NavigationRoute`.
- Make `BrowseListViewModel.init(dependencies:router:)` accept
  `any IFlowRouter` and add `openItem(id:)`.
- Replace list `NavigationLink` rows with Buttons calling `openItem(id:)`.
- Keep Browse's `.navigationDestination(for: BrowseRoute.self)` on the root
  non-lazy Group and pass dependencies to `BrowseDetailView`.
- Move the stack into `BrowseFlowView`.
- Add `nonisolated enum BrowseDetailRoute {}` as the reserved leaf scaffold.

- [ ] **Step 7: Migrate Settings**

- Make `SettingsRoute` conform to `NavigationRoute`.
- Make `SettingsViewModel.init(sessionStore:router:)` accept
  `any IFlowRouter` and add `openAbout()`.
- Replace the About `NavigationLink` with a Button calling `openAbout()`.
- Keep the destination mapping inside Settings View.
- Move the stack into `SettingsFlowView`.
- Add `nonisolated enum AboutRoute {}` as the reserved leaf scaffold.

- [ ] **Step 8: Add Authentication flow ownership**

Create `AuthenticationFlowView` with the Authentication `FlowRouter` bound to
one `NavigationStack`. It constructs the existing Authentication screen with
`sessionStore` and `AppRouter`. Add
`nonisolated enum AuthenticationRoute {}` as its reserved leaf route scaffold;
do not invent fake destinations.

```swift
struct AuthenticationFlowView: View {
    @Bindable var router: FlowRouter
    let sessionStore: SessionStore
    let appRouter: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            AuthenticationView(
                sessionStore: sessionStore,
                router: appRouter
            )
        }
    }
}
```

Update AppRoot:

```swift
AuthenticationFlowView(
    router: router.authentication,
    sessionStore: sessionStore,
    appRouter: router
)
```

- [ ] **Step 9: Wire independent tab flows**

Update AppShell tabs to construct:

```swift
HomeFlowView(router: router.home)
BrowseFlowView(router: router.browse, dependencies: dependencies.browse)
SettingsFlowView(router: router.settings, sessionStore: sessionStore)
```

- [ ] **Step 10: Remove obsolete router infrastructure**

Delete `HomeRouter.swift`, `BrowseRouter.swift`, `SettingsRouter.swift`, and
`StackRouting.swift`. Search for and remove all references to their type names
and to `HomeNavigationView`, `BrowseNavigationView`, and
`SettingsNavigationView`.

- [ ] **Step 11: Run rewritten suites and the full macOS suite**

Run the focused command from Step 2 and expect PASS, then:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS' -derivedDataPath /tmp/AppTemplate-hierarchical-navigation-macos
```

Expected: PASS.

- [ ] **Step 12: Commit the atomic migration only if path isolation is safe**

```bash
git add AppTemplate/App/Navigation AppTemplate/Features/Authentication AppTemplate/Features/Home AppTemplate/Features/Browse AppTemplate/Features/Settings AppTemplateTests/App/Navigation AppTemplateTests/Features AppTemplateTests/Project
git commit --only AppTemplate/App/Navigation AppTemplate/Features/Authentication AppTemplate/Features/Home AppTemplate/Features/Browse AppTemplate/Features/Settings AppTemplateTests/App/Navigation AppTemplateTests/Features AppTemplateTests/Project -m "refactor: adopt hierarchical flow navigation"
```

---

### Task 3: Documentation, Restoration Audit, and Multiplatform Verification

**Files:**
- Modify: `README.md`
- Modify as test evidence requires:
  - `AppTemplateTests/App/Navigation/DeepLinks/DeepLinkParserTests.swift`
  - `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
  - `AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift`

**Interfaces:**
- Consumes: completed flow architecture.
- Produces: documented rules and verified iOS/iPadOS/macOS behavior.

- [ ] **Step 1: Audit every navigation reference**

Run:

```bash
rg -n "HomeRouter|BrowseRouter|SettingsRouter|StackRouting|HomeNavigationView|BrowseNavigationView|SettingsNavigationView|\\[HomeRoute\\]|\\[BrowseRoute\\]|\\[SettingsRoute\\]" AppTemplate AppTemplateTests README.md
```

Expected: no obsolete architecture references.

- [ ] **Step 2: Update README navigation rules**

Document:

- `AppRouter` selects `AppFlow` and owns per-scene flow routers.
- Authentication and each tab are independent flows.
- `FlowView` owns one navigation container.
- one `FlowRouter` instance is passed down the hierarchy.
- screen ViewModels receive `any IFlowRouter`.
- outgoing routes and `.navigationDestination` live in their originating
  screen.
- leaf screens use an empty nonconforming route scaffold rather than a fake
  route case.
- snapshots store schema-2 heterogeneous `NavigationPath` representations.

Link the new design and this implementation plan.

- [ ] **Step 3: Verify snapshot and deep-link requirements**

Run:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS' -derivedDataPath /tmp/AppTemplate-navigation-audit -only-testing:AppTemplateTests/DeepLinkParserTests -only-testing:AppTemplateTests/AppRouterTests -only-testing:AppTemplateTests/NavigationSnapshotTests -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests
```

Expected: PASS, including a mixed Home/HomeDetails path round trip and canonical
Browse deep-link path replacement.

- [ ] **Step 4: Run the complete macOS test suite**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS' -derivedDataPath /tmp/AppTemplate-hierarchical-navigation-final-macos
```

Expected: PASS.

- [ ] **Step 5: Run the complete iOS/iPadOS test suite**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/AppTemplate-hierarchical-navigation-final-ios
```

Expected: PASS. The universal iOS target covers iPhone and iPadOS compilation;
if an iPad simulator is installed, also build with:

```bash
xcodebuild build -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' -derivedDataPath /tmp/AppTemplate-hierarchical-navigation-ipad
```

- [ ] **Step 6: Inspect the final diff and working tree**

Run:

```bash
git diff --check
git status --short
git diff --stat
```

Confirm that unrelated pre-existing Model/State scaffold changes remain intact
and no generated Xcode artifacts are tracked.

- [ ] **Step 7: Commit only documentation if doing so will not capture unrelated README work**

If README already contains unrelated unstaged edits, leave it uncommitted and
report that explicitly. Otherwise:

```bash
git add README.md
git commit --only README.md -m "docs: explain hierarchical flow navigation"
```
