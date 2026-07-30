# Global App Flow Router Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one app-scoped root-flow router with universal `setFlow(_:)`, while preserving independent navigation histories and pending deep links for every window.

**Architecture:** `AppTemplateApp` owns one observable `AppFlowRouter`; each `AppSceneView` continues to own a separate `AppRouter`. Screen `FlowRouter` instances conform to a composite `IRouter` and delegate global flow changes to the shared router, while retaining their own `NavigationPath`.

**Tech Stack:** Swift 6, SwiftUI Observation, NavigationStack, Swift Testing, Xcode 26, iOS 26, iPadOS 26, macOS 26.

## Global Constraints

- Public `setFlow(_:)` always publishes a new transition and resets every scene's histories, even when the requested flow is already visible.
- Authenticated cold restoration preserves the restored selected tab and tab histories.
- Session state remains owned by the shared `SessionStore`; changing root UI never fabricates authentication.
- Pending deep links remain scene-scoped and replay only in the scene that received them.
- `AppDependencies` remains an immutable service graph and does not store navigation state.
- No singleton, service locator, navigation closure, `AnyView`, `fatalError`, force cast, or ViewModel environment lookup may be added.
- Keep screen-owned routes, destinations, sheets, alerts, and dialogs.
- Keep all `nonisolated` declarations on their own line, matching project style.
- Do not edit `AppTemplate.xcodeproj/project.pbxproj`; the project uses file-system-synchronized groups.
- Execute implementation in a Superpowers-owned worktree so the existing user-owned whitespace change in `AppTemplate/App/Entry/AppTemplateApp.swift` remains untouched in the main checkout.

---

### Task 1: Build the app-scoped flow transition engine

**Files:**
- Modify: `AppTemplate/App/Navigation/Routing/AppFlow.swift`
- Create: `AppTemplate/App/Navigation/Routing/AppFlowTransition.swift`
- Create: `AppTemplate/App/Navigation/Routing/IAppFlowRouter.swift`
- Create: `AppTemplate/App/Navigation/Routing/AppFlowRouter.swift`
- Test: `AppTemplateTests/App/Navigation/Routing/AppFlowRouterTests.swift`

**Interfaces:**
- Consumes: existing `AppFlow`, `SessionPhase`, and `UserSession`.
- Produces: `AppFlowTransition`, `AppFlowHistoryAction`, `PendingIntentAction`, `IAppFlowRouter`, and concrete observable `AppFlowRouter`.

- [ ] **Step 1: Write failing transition tests**

Add a Swift Testing suite covering explicit repetition and session policy:

```swift
import Testing
@testable import AppTemplate

@MainActor
struct AppFlowRouterTests {
    @Test
    func repeatedExplicitFlowProducesNewResetTransition() {
        let router = AppFlowRouter(flow: .authentication)
        let firstID = router.transition.id

        router.setFlow(.authentication)

        #expect(router.flow == .authentication)
        #expect(router.transition.id != firstID)
        #expect(router.transition.historyAction == .reset)
        #expect(router.transition.pendingIntentAction == .discard)
    }

    @Test
    func authenticatedColdRestorePreservesHistories() {
        let router = AppFlowRouter(flow: .launching)
        let session = UserSession(id: "member", displayName: "Member")

        router.synchronizeSession(.loading)
        router.synchronizeSession(.authenticated(session))

        #expect(router.flow == .main)
        #expect(router.transition.historyAction == .preserve)
        #expect(router.transition.pendingIntentAction == .replay)
    }

    @Test
    func newAuthenticationResetsHistories() {
        let router = AppFlowRouter(flow: .launching)
        let session = UserSession(id: "member", displayName: "Member")

        router.synchronizeSession(.unauthenticated)
        router.synchronizeSession(.loading)
        router.synchronizeSession(.authenticated(session))

        #expect(router.flow == .main)
        #expect(router.transition.historyAction == .reset)
        #expect(router.transition.pendingIntentAction == .replay)
    }

    @Test
    func logoutDiscardsPendingNavigation() {
        let router = AppFlowRouter(flow: .launching)
        let session = UserSession(id: "member", displayName: "Member")
        router.synchronizeSession(.authenticated(session))

        router.synchronizeSession(.loading)
        router.synchronizeSession(.unauthenticated)

        #expect(router.flow == .authentication)
        #expect(router.transition.historyAction == .reset)
        #expect(router.transition.pendingIntentAction == .discard)
    }

    @Test
    func duplicateSessionReportIsIdempotent() {
        let router = AppFlowRouter(flow: .launching)
        router.synchronizeSession(.unauthenticated)
        let transition = router.transition

        router.synchronizeSession(.unauthenticated)

        #expect(router.transition == transition)
    }

    @Test
    func failedSignInPreservesAuthenticationHistory() {
        let router = AppFlowRouter(flow: .launching)
        router.synchronizeSession(.unauthenticated)
        router.synchronizeSession(.loading)

        router.synchronizeSession(.unauthenticated)

        #expect(router.flow == .authentication)
        #expect(router.transition.historyAction == .preserve)
        #expect(router.transition.pendingIntentAction == .preserve)
    }

    @Test
    func failedSignOutPreservesMainHistory() {
        let router = AppFlowRouter(flow: .launching)
        let session = UserSession(id: "member", displayName: "Member")
        router.synchronizeSession(.authenticated(session))
        router.synchronizeSession(.loading)

        router.synchronizeSession(.authenticated(session))

        #expect(router.flow == .main)
        #expect(router.transition.historyAction == .preserve)
        #expect(router.transition.pendingIntentAction == .replay)
    }
}
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/AppFlowRouterTests
```

Expected: exit 65 because `AppFlowRouter` and transition types do not exist.

- [ ] **Step 3: Add transition value types and protocol**

Create:

```swift
import Foundation

nonisolated
enum AppFlowHistoryAction: Equatable, Sendable {
    case preserve
    case reset
}

nonisolated
enum PendingIntentAction: Equatable, Sendable {
    case preserve
    case replay
    case discard
}

nonisolated
struct AppFlowTransition: Equatable, Sendable {
    let id: UUID
    let flow: AppFlow
    let historyAction: AppFlowHistoryAction
    let pendingIntentAction: PendingIntentAction
}
```

Create the screen-facing protocol:

```swift
@MainActor
protocol IAppFlowRouter: AnyObject {
    func setFlow(_ flow: AppFlow)
}
```

- [ ] **Step 4: Implement `AppFlowRouter`**

Implement an `@MainActor @Observable` class with:

```swift
private(set) var transition: AppFlowTransition
var flow: AppFlow { transition.flow }
func setFlow(_ flow: AppFlow)
func synchronizeSession(_ phase: SessionPhase)
```

Use a private stable-session enum so session policy is unambiguous:

```swift
private enum StableSessionState: Equatable {
    case idle
    case unauthenticated
    case authenticated(UserSession)
}
```

Required policy:

```text
public setFlow(non-main)   → reset + discard
public setFlow(main)       → reset + replay
idle/loading               → launching + preserve + preserve
cold authenticated restore → main + preserve + replay
new authentication         → main + reset + replay
logout                     → authentication + reset + discard
failed sign-in             → authentication + preserve + preserve
failed sign-out            → main + preserve + replay
```

Store the last observed `SessionPhase` to suppress duplicate reports from
multiple windows. Always create a fresh UUID for public `setFlow(_:)`.

- [ ] **Step 5: Run focused and full macOS tests**

Run the focused command from Step 2, then:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64'
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/App/Navigation/Routing \
  AppTemplateTests/App/Navigation/Routing/AppFlowRouterTests.swift
git commit -m "feat: add global app flow transitions"
```

### Task 2: Compose local and global routing behind one ViewModel contract

**Files:**
- Create: `AppTemplate/App/Navigation/Core/IRouter.swift`
- Modify: `AppTemplate/App/Navigation/Core/FlowRouter.swift`
- Modify: `AppTemplateTests/App/Navigation/Core/FlowRouterTests.swift`

**Interfaces:**
- Consumes: `IFlowRouter` and `IAppFlowRouter`.
- Produces: `IRouter` and a `FlowRouter` that delegates `setFlow(_:)`.

- [ ] **Step 1: Add failing delegation tests**

Add:

```swift
@Test
func flowRouterDelegatesGlobalFlowChanges() {
    let appFlowRouter = AppFlowRouterSpy()
    let router = FlowRouter(appFlowRouter: appFlowRouter)

    router.setFlow(.authentication)

    #expect(appFlowRouter.receivedFlows == [.authentication])
}

@Test
func compositeContractSupportsLocalAndGlobalNavigation() {
    let appFlowRouter = AppFlowRouterSpy()
    let concrete = FlowRouter(appFlowRouter: appFlowRouter)
    let router: any IRouter = concrete

    router.push(TestRoute.first)
    router.setFlow(.main)

    #expect(concrete.path.count == 1)
    #expect(appFlowRouter.receivedFlows == [.main])
}

@MainActor
private final class AppFlowRouterSpy: IAppFlowRouter {
    private(set) var receivedFlows: [AppFlow] = []

    func setFlow(_ flow: AppFlow) {
        receivedFlows.append(flow)
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/FlowRouterTests
```

Expected: exit 65 because `IRouter` and the injected initializer are absent.

- [ ] **Step 3: Add the composite protocol and delegation**

Create:

```swift
@MainActor
protocol IRouter: IFlowRouter, IAppFlowRouter {}
```

Change `FlowRouter` to:

```swift
@MainActor
@Observable
final class FlowRouter: IRouter {
    var path: NavigationPath
    private let appFlowRouter: any IAppFlowRouter

    init(
        path: NavigationPath = NavigationPath(),
        appFlowRouter: any IAppFlowRouter = AppFlowRouter(flow: .main)
    ) {
        self.path = path
        self.appFlowRouter = appFlowRouter
    }

    func setFlow(_ flow: AppFlow) {
        appFlowRouter.setFlow(flow)
    }
}
```

Keep the existing push, pop, pop-to-root, and path replacement behavior
unchanged. The default app-flow router is only an isolated convenience for
unit tests and previews; every production flow created by `AppRouter` must
receive the shared instance explicitly.

- [ ] **Step 4: Run focused and full macOS tests**

Run the focused command from Step 2 and the full macOS suite. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Navigation/Core \
  AppTemplateTests/App/Navigation/Core/FlowRouterTests.swift
git commit -m "feat: compose local and app flow routing"
```

### Task 3: Move root-flow ownership out of scene routers

**Files:**
- Modify: `AppTemplate/App/Entry/AppTemplateApp.swift`
- Modify: `AppTemplate/App/Entry/ContentView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppRootView.swift`
- Modify: `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- Modify: `AppTemplate/Features/Authentication/Flow/AuthenticationFlowView.swift`
- Modify: `AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift`
- Modify: `AppTemplate/Features/Authentication/Screens/Authentication/ViewModel/AuthenticationViewModel.swift`
- Modify: `AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift`
- Modify: `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
- Modify: `AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift`
- Modify: `AppTemplateTests/Features/Authentication/Screens/Authentication/AuthenticationViewModelTests.swift`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**
- Consumes: concrete shared `AppFlowRouter`, `AppFlowTransition`, and delegated
  `FlowRouter`.
- Produces: scene-local `AppRouter.apply(_:)`, global root observation, and
  migrated deep-link/session behavior without `AppRouter.flow`.

- [ ] **Step 1: Rewrite router and lifecycle tests for the new ownership**

Add or migrate tests proving:

```swift
let appFlowRouter = AppFlowRouter(flow: .main)
let first = AppSceneNavigationLifecycle(appFlowRouter: appFlowRouter)
let second = AppSceneNavigationLifecycle(appFlowRouter: appFlowRouter)

first.router.home.push(HomeRoute.details)
second.router.projects.push(ProjectsRoute.project(id: "template"))

appFlowRouter.setFlow(.authentication)
first.apply(appFlowRouter.transition)
second.apply(appFlowRouter.transition)

#expect(first.router.home.path.isEmpty)
#expect(second.router.projects.path.isEmpty)
#expect(first.router.selectedSection == .home)
#expect(second.router.selectedSection == .home)
```

Retain and adapt the existing tests for:

- authenticated cold launch preserving restored histories;
- signed-out deep link preservation and replay after authentication;
- authentication cancellation discarding `pendingIntent`;
- two scenes sharing session root state but not histories;
- corrupt snapshot recovery;
- unknown Browse and Projects deep links;
- schema-two migration.

Replace assertions against `router.flow` with assertions against the shared
`appFlowRouter.flow`.

Replace the old Authentication cancellation assertion with:

```swift
let appFlowRouter = AppFlowRouter(flow: .authentication)
let flowRouter = FlowRouter(appFlowRouter: appFlowRouter)
let viewModel = AuthenticationViewModel(
    sessionStore: makeSessionStore(),
    router: flowRouter
)
let previousID = appFlowRouter.transition.id

viewModel.cancelAuthentication()

#expect(appFlowRouter.flow == .authentication)
#expect(appFlowRouter.transition.id != previousID)
#expect(appFlowRouter.transition.pendingIntentAction == .discard)
```

- [ ] **Step 2: Run AppRouter, lifecycle, and snapshot tests and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/AppRouterTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests \
  -only-testing:AppTemplateTests/NavigationSnapshotTests \
  -only-testing:AppTemplateTests/AuthenticationViewModelTests
```

Expected: exit 65 until ownership is migrated.

- [ ] **Step 3: Refactor `AppRouter`**

Make `AppRouter` store:

```swift
let appFlowRouter: AppFlowRouter
var selectedSection: AppSection
let authentication: FlowRouter
let home: FlowRouter
let browse: FlowRouter
let projects: FlowRouter
let settings: FlowRouter
private(set) var pendingIntent: NavigationIntent?
```

Remove:

```swift
var flow: AppFlow
finishLaunching(isAuthenticated:)
completeAuthentication(succeeded:)
requireAuthentication()
```

Construct every production `FlowRouter` with the same `appFlowRouter`. Change
`handle(_:)` to defer unless `appFlowRouter.flow == .main`.

Add:

```swift
@discardableResult
func apply(_ transition: AppFlowTransition) -> NavigationOutcome? {
    if transition.historyAction == .reset {
        resetFlowHistories()
    }

    switch transition.pendingIntentAction {
    case .preserve:
        return nil
    case .discard:
        pendingIntent = nil
        return nil
    case .replay:
        return replayPendingIntent()
    }
}
```

Keep `resetNavigation()` for corrupt/unsupported snapshots; it clears both
histories and pending intent.

- [ ] **Step 4: Refactor scene lifecycle and root composition**

`AppTemplateApp` creates one:

```swift
@State private var appFlowRouter = AppFlowRouter(flow: .launching)
```

and passes it to each `AppSceneView`.

`AppSceneView` constructs its state with:

```swift
init(appFlowRouter: AppFlowRouter, dependencies: AppDependencies) {
    self.appFlowRouter = appFlowRouter
    self.dependencies = dependencies
    _lifecycle = State(
        initialValue: AppSceneNavigationLifecycle(
            appFlowRouter: appFlowRouter
        )
    )
}
```

It synchronizes `SessionStore.phase` through the shared `AppFlowRouter` and
observes `appFlowRouter.transition`. Each transition calls
`lifecycle.apply(_:)` and persists the resulting scene snapshot after
restoration.

`AppRootView` switches on `appFlowRouter.flow`, accepts the scene router as a
plain stored property, and applies:

```swift
.id(appFlowRouter.transition.id)
```

to the root content so repeated explicit transitions recreate local
presentation state.

Update `ContentView` and previews to construct one matching pair of
`AppFlowRouter` and scene `AppRouter`.

In the same atomic migration, change `AuthenticationViewModel` to:

```swift
private let router: any IRouter

init(
    sessionStore: SessionStore,
    router: any IRouter
) {
    self.sessionStore = sessionStore
    self.router = router
}

func cancelAuthentication() {
    router.setFlow(.authentication)
}
```

Keep sign-in and retry routed through `SessionStore`. Remove the full
`AppRouter` parameter from `AuthenticationView`, `AuthenticationFlowView`,
their construction tests, and `AppRootView`.

- [ ] **Step 5: Run focused tests, then the full macOS suite**

Run the Step 2 command and then the full macOS suite. Expected: PASS with the
existing snapshot schema unchanged.

- [ ] **Step 6: Run structural ownership guards**

```bash
! rg -n 'var flow: AppFlow|router\.flow\s*=|finishLaunching|completeAuthentication|requireAuthentication' AppTemplate
test "$(rg -n 'AppFlowRouter\\(flow: \\.launching\\)' AppTemplate/App/Entry/AppTemplateApp.swift | wc -l | tr -d ' ')" -eq 1
git diff --check
```

Expected: all commands exit 0 inside the clean implementation worktree.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate/App/Entry AppTemplate/App/Navigation \
  AppTemplate/Features/Authentication AppTemplateTests/App/Navigation \
  AppTemplateTests/Features/Authentication AppTemplateTests/Project
git commit -m "refactor: share root flow across scenes"
```

### Task 4: Add Onboarding and Maintenance root flows

**Files:**
- Modify: `AppTemplate/App/Navigation/Routing/AppFlow.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppRootView.swift`
- Create: `AppTemplate/Features/Onboarding/Flow/OnboardingFlowView.swift`
- Create: `AppTemplate/Features/Onboarding/Screens/Onboarding/Model/OnboardingModel.swift`
- Create: `AppTemplate/Features/Onboarding/Screens/Onboarding/Navigation/OnboardingRoute.swift`
- Create: `AppTemplate/Features/Onboarding/Screens/Onboarding/State/OnboardingState.swift`
- Create: `AppTemplate/Features/Onboarding/Screens/Onboarding/View/OnboardingView.swift`
- Create: `AppTemplate/Features/Onboarding/Screens/Onboarding/ViewModel/OnboardingViewModel.swift`
- Create: `AppTemplate/Features/Maintenance/Flow/MaintenanceFlowView.swift`
- Create: `AppTemplate/Features/Maintenance/Screens/Maintenance/Model/MaintenanceModel.swift`
- Create: `AppTemplate/Features/Maintenance/Screens/Maintenance/Navigation/MaintenanceRoute.swift`
- Create: `AppTemplate/Features/Maintenance/Screens/Maintenance/State/MaintenanceState.swift`
- Create: `AppTemplate/Features/Maintenance/Screens/Maintenance/View/MaintenanceView.swift`
- Create: `AppTemplate/Features/Maintenance/Screens/Maintenance/ViewModel/MaintenanceViewModel.swift`
- Modify: `AppTemplate/Features/Home/Screens/Home/View/HomeView.swift`
- Modify: `AppTemplate/Features/Home/Screens/Home/ViewModel/HomeViewModel.swift`
- Test: `AppTemplateTests/Features/Onboarding/Screens/Onboarding/OnboardingViewModelTests.swift`
- Test: `AppTemplateTests/Features/Maintenance/Screens/Maintenance/MaintenanceViewModelTests.swift`
- Modify: `AppTemplateTests/Features/Home/Screens/Home/HomeViewModelTests.swift`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**
- Consumes: `any IRouter` and global root mappings.
- Produces: `.onboarding`, `.maintenance`, two independent flow roots, and
  reachable sample transitions from Home.

- [ ] **Step 1: Write failing ViewModel and construction tests**

Use an `IAppFlowRouter` spy through `FlowRouter`:

```swift
@Test
func finishingOnboardingOpensMain() {
    let appFlowRouter = AppFlowRouter(flow: .onboarding)
    let router = FlowRouter(appFlowRouter: appFlowRouter)
    let viewModel = OnboardingViewModel(router: router)

    viewModel.finish()

    #expect(appFlowRouter.flow == .main)
    #expect(appFlowRouter.transition.historyAction == .reset)
}

@Test
func leavingMaintenanceOpensMain() {
    let appFlowRouter = AppFlowRouter(flow: .maintenance)
    let router = FlowRouter(appFlowRouter: appFlowRouter)
    let viewModel = MaintenanceViewModel(router: router)

    viewModel.returnToApp()

    #expect(appFlowRouter.flow == .main)
}
```

Extend `HomeViewModelTests` to prove:

```swift
viewModel.openOnboarding()
#expect(appFlowRouter.flow == .onboarding)

viewModel.openMaintenance()
#expect(appFlowRouter.flow == .maintenance)
```

Add construction coverage for both `FlowView` roots and their initial screens.

- [ ] **Step 2: Run the new feature tests and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/OnboardingViewModelTests \
  -only-testing:AppTemplateTests/MaintenanceViewModelTests \
  -only-testing:AppTemplateTests/HomeViewModelTests
```

Expected: exit 65 because the flows and APIs do not exist.

- [ ] **Step 3: Add root cases and scene routers**

Add:

```swift
case onboarding
case maintenance
```

to `AppFlow`. Add `onboarding` and `maintenance` `FlowRouter` properties to
`AppRouter`, construct them with the shared app flow router, and include both
in reset logic. Do not add their paths to `NavigationSnapshot`; both are
transient root processes.

- [ ] **Step 4: Add symmetric feature scaffolds and Views**

Both initial screens use the established five folders. Their route enums are
empty nonconforming scaffolds because the examples have no outgoing stack
destination:

```swift
nonisolated
enum OnboardingRoute {}

nonisolated
enum MaintenanceRoute {}
```

Create matching neutral model and state scaffolds:

```swift
nonisolated
struct OnboardingModel:
    Equatable,
    Sendable {
}

nonisolated
struct OnboardingState:
    Equatable,
    Sendable {
}
```

Use the same declaration shape for `MaintenanceModel` and `MaintenanceState`.

`OnboardingViewModel.finish()` calls `router.setFlow(.main)`.
`MaintenanceViewModel.returnToApp()` calls `router.setFlow(.main)`.

Each `FlowView` follows the existing flow-root pattern:

```swift
struct OnboardingFlowView: View {
    @Bindable var router: FlowRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            OnboardingView(router: router)
        }
    }
}
```

Use the same shape for Maintenance. Each screen owns its ViewModel with
`@State`, renders a native title and explanatory text, and exposes exactly one
primary action: `Finish Onboarding` or `Return to App`. Do not add custom
visual styling.

- [ ] **Step 5: Map roots and add reachable Home examples**

Map both new cases exhaustively in `AppRootView`. Change `HomeViewModel` to
accept `any IRouter` and add:

```swift
func openOnboarding() {
    router.setFlow(.onboarding)
}

func openMaintenance() {
    router.setFlow(.maintenance)
}
```

Add corresponding Buttons to `HomeView`, making both sample flows reachable
without deep-link or test-only hooks.

- [ ] **Step 6: Run focused and full macOS tests**

Run the Step 2 command and then the full macOS suite. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate/App/Navigation AppTemplate/Features/Home \
  AppTemplate/Features/Onboarding AppTemplate/Features/Maintenance \
  AppTemplateTests/Features/Home AppTemplateTests/Features/Onboarding \
  AppTemplateTests/Features/Maintenance AppTemplateTests/Project
git commit -m "feat: add onboarding and maintenance flows"
```

### Task 5: Migrate remaining ViewModels and independent modal flows to `IRouter`

**Files:**
- Modify: `AppTemplate/Features/Home/Screens/HomeDetails/ViewModel/HomeDetailsViewModel.swift`
- Modify: `AppTemplate/Features/Home/Screens/NavigationGuide/ViewModel/NavigationGuideViewModel.swift`
- Modify: `AppTemplate/Features/Browse/Screens/Browse/ViewModel/BrowseListViewModel.swift`
- Modify: `AppTemplate/Features/Browse/Screens/BrowseDetail/ViewModel/BrowseDetailViewModel.swift`
- Modify: `AppTemplate/Features/Browse/Screens/RelatedItems/ViewModel/RelatedItemsViewModel.swift`
- Modify: `AppTemplate/Features/Projects/Screens/Projects/ViewModel/ProjectsViewModel.swift`
- Modify: `AppTemplate/Features/Projects/Screens/ProjectDetails/ViewModel/ProjectDetailsViewModel.swift`
- Modify: `AppTemplate/Features/Projects/Screens/ProjectBasics/ViewModel/ProjectBasicsViewModel.swift`
- Modify: `AppTemplate/Features/Projects/Screens/ProjectOptions/ViewModel/ProjectOptionsViewModel.swift`
- Modify: `AppTemplate/Features/Settings/Screens/Settings/ViewModel/SettingsViewModel.swift`
- Modify: `AppTemplate/Features/Settings/Screens/About/ViewModel/AboutViewModel.swift`
- Modify: `AppTemplate/Features/Projects/Flow/CreateProjectFlowView.swift`
- Modify: `AppTemplate/Features/Projects/Screens/Projects/View/ProjectsView.swift`
- Modify: matching tests under `AppTemplateTests/Features`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**
- Consumes: composite `any IRouter`.
- Produces: shared global-flow access for every existing navigation-aware
  ViewModel and for the independent Create Project modal flow.

- [ ] **Step 1: Write a failing Create Project construction test**

Update the existing real-sheet or construction test before production code:

```swift
@Test
func createProjectFlowReceivesThePresentingAppFlowRouter() {
    let appFlowRouter = AppFlowRouter(flow: .main)
    let presentingRouter = FlowRouter(appFlowRouter: appFlowRouter)

    _ = CreateProjectFlowView(
        store: ProjectsStore(),
        appFlowRouter: presentingRouter
    )

    #expect(appFlowRouter.flow == .main)
}
```

- [ ] **Step 2: Run Projects construction tests and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: exit 65 because `CreateProjectFlowView` does not accept the app-flow
delegate.

- [ ] **Step 3: Migrate navigation-aware ViewModels**

Mechanically replace `any IFlowRouter` with `any IRouter` in the files listed
above. Do not change their local push/pop behavior. Existing concrete
`FlowRouter` call sites continue to satisfy the stronger contract.

Run:

```bash
! rg -n 'private let router: any IFlowRouter|router: any IFlowRouter' \
  AppTemplate/Features
```

Expected: no navigation-aware ViewModel still requests the narrower contract.

- [ ] **Step 4: Preserve the shared delegate in Create Project**

Change the modal flow initializer to receive the presenting router as an app
flow delegate:

```swift
init(
    store: ProjectsStore,
    appFlowRouter: any IAppFlowRouter
) {
    self.store = store
    _router = State(
        initialValue: FlowRouter(appFlowRouter: appFlowRouter)
    )
    _draft = State(initialValue: CreateProjectDraftState())
}
```

`ProjectsView` presents it with:

```swift
CreateProjectFlowView(
    store: viewModel.store,
    appFlowRouter: router
)
```

Keep the internal draft-injection initializer used by the real-sheet
dismissal regression test, adding the same app-flow dependency there.

- [ ] **Step 5: Run all feature tests and full macOS tests**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/HomeViewModelTests \
  -only-testing:AppTemplateTests/BrowseListViewModelTests \
  -only-testing:AppTemplateTests/ProjectsViewModelTests \
  -only-testing:AppTemplateTests/SettingsViewModelTests

xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/Features AppTemplateTests/Features \
  AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "refactor: expose app flows to view models"
```

### Task 6: Document and verify the complete architecture

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-07-30-global-app-flow-router-design.md` only if implementation names differ without changing behavior
- Test: all existing `AppTemplateTests`

**Interfaces:**
- Consumes: completed global-flow implementation.
- Produces: final documentation and fresh three-platform evidence.

- [ ] **Step 1: Update README examples**

Document:

```swift
router.push(HomeRoute.details)
router.setFlow(.onboarding)
router.setFlow(.maintenance)
router.setFlow(.main)
```

Explain that root flow is shared across windows while selected tabs and
NavigationPaths remain per scene. State that public `setFlow` resets histories
and authenticated cold restoration preserves them.

- [ ] **Step 2: Run static guards**

```bash
git diff --check
! rg -n 'AppRouter\\.shared|AnyView|fatalError|router\\.flow\\s*=|var flow: AppFlow' AppTemplate
! rg -n 'finishLaunching|completeAuthentication|requireAuthentication' AppTemplate
test "$(rg -n 'func setFlow\\(_ flow: AppFlow\\)' AppTemplate/App/Navigation | wc -l | tr -d ' ')" -ge 2
test "$(rg -n 'case onboarding|case maintenance' AppTemplate/App/Navigation/Routing/AppFlow.swift | wc -l | tr -d ' ')" -eq 2
```

Expected: all commands exit 0.

- [ ] **Step 3: Run the complete macOS suite**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/AppTemplate-global-flow-macos
```

Expected: exit 0, no failures or skips.

- [ ] **Step 4: Run the complete iPhone suite**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/AppTemplate-global-flow-iphone
```

Expected: exit 0, no failures or skips.

- [ ] **Step 5: Run the complete iPad suite**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  -derivedDataPath /tmp/AppTemplate-global-flow-ipad
```

Expected: exit 0, no failures or skips.

- [ ] **Step 6: Run interactive root-flow smoke checks**

On iPhone 17 Pro:

```text
Home → Onboarding Example → Finish → Main/Home root
Home → Maintenance Example → Return to App → Main/Home root
Home → Details → set same Main flow → Home root
signed-out deep link → Authentication → sign in → receiving destination
```

Repeat the Onboarding and Maintenance transitions on iPad. On macOS, open two
windows, put them on different tabs and paths, trigger Onboarding in one, and
verify both roots change while their scene routers remain distinct.

- [ ] **Step 7: Commit documentation**

```bash
git add README.md docs/superpowers/specs/2026-07-30-global-app-flow-router-design.md
git commit -m "docs: explain global app flow routing"
```

- [ ] **Step 8: Request final review**

Review the complete implementation range against:

- one app-scoped flow router;
- independent scene routers;
- explicit same-flow reset;
- authenticated cold restoration;
- session failure behavior;
- pending deep-link replay;
- Onboarding and Maintenance reachability;
- no unrelated changes or user-owned main-checkout modifications.
