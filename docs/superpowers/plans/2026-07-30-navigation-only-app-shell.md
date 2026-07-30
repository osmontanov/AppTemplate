# Navigation-Only App Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce AppTemplate to a navigation-first SwiftUI boilerplate with
static screens, navigation/presentation-only ViewModels, and exactly two empty
DI service examples.

**Architecture:** Keep one app-scoped `AppFlowRouter`, scene-scoped
`AppRouter` instances, typed screen-owned routes, snapshots, deep-link replay,
sheets, alerts, and dialogs. Remove all session, Browse loading, and Projects
data behavior. `AppDependencies` ends with only empty LocalDatabase and Remote
protocol/concrete actor pairs.

**Tech Stack:** Swift 6, SwiftUI Observation, Swift Testing, Xcode 26,
NavigationStack, NavigationPath, macOS 26, iOS 26, iPadOS 26.

## Global Constraints

- The app is a navigation-first boilerplate, not a functioning product.
- Views render static content and bind presentation state.
- Every screen keeps its own ViewModel and the existing
  Model/Navigation/State/View/ViewModel folder scaffold.
- ViewModels may contain only typed navigation, route identifiers, and
  sheet/alert/dialog presentation state.
- No feature may load, save, search, sort, validate, retry, authenticate, or
  own mutable domain data.
- Keep all existing screens, typed destinations, sheets, alerts, confirmation
  dialogs, root-flow buttons, and independent UI components.
- `ILocalDatabaseService`/`LocalDatabaseService` and
  `IRemoteService`/`RemoteService` are the only retained services; both
  protocols and implementations are empty.
- Empty feature dependency structs and passive Model/State/Domain examples may
  remain, but must not drive runtime behavior.
- Authentication `Continue` calls `setFlow(.main)`; Settings `Sign Out` calls
  `setFlow(.authentication)` without session state.
- The application starts in `.authentication`; `.launching` and session
  synchronization are removed.
- `.main` root transitions reset scene histories then replay only the receiving
  scene's pending intent. Non-main transitions reset histories and discard
  pending intent.
- Repeated `setFlow` calls always publish a fresh reset transition.
- No singleton, service locator, navigation closure, `AnyView`, `fatalError`,
  force cast, or ViewModel environment lookup.
- `nonisolated` must appear on its own line.
- Do not edit `AppTemplate.xcodeproj/project.pbxproj`.
- Preserve the user's existing unstaged whitespace change in the main checkout;
  implementation must occur in an isolated worktree.

---

### Task 1: Add the empty Remote DI example

**Files:**

- Create: `AppTemplate/App/Services/Remote/IRemoteService.swift`
- Create: `AppTemplate/App/Services/Remote/RemoteService.swift`
- Create: `AppTemplateTests/App/Services/Remote/RemoteServiceTests.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift`

**Interfaces:**

- Consumes: existing empty `ILocalDatabaseService` and
  `LocalDatabaseService`.
- Produces: empty `IRemoteService`, empty `RemoteService`, and interim
  `AppDependencies.localDatabase` / `AppDependencies.remote` properties.
- The existing Browse, Projects, and Session graph properties remain
  temporarily so this task is independently buildable. Later tasks remove them.

- [ ] **Step 1: Write the failing Remote service test**

Create:

```swift
import Testing
@testable import AppTemplate

struct RemoteServiceTests {
    @Test
    func concreteExampleSatisfiesTheEmptyInterface() {
        let service: any IRemoteService = RemoteService()

        #expect(service is RemoteService)
    }
}
```

Extend `AppDependenciesTests` with an assertion that `live()` exposes concrete
LocalDatabase and Remote services. Extend its injected-graph test with two
private empty actors:

```swift
private actor InjectedLocalDatabaseService: ILocalDatabaseService {}
private actor InjectedRemoteService: IRemoteService {}
```

and assert that
`AppDependencies.test(browseService:sessionService:localDatabaseService:remoteService:)`
preserves their identity.

- [ ] **Step 2: Run the focused tests and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/RemoteServiceTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -only-testing:AppTemplateTests/LocalDatabaseServiceTests
```

Expected: exit 65 because `IRemoteService`, `RemoteService`, and the new
dependency properties do not exist.

- [ ] **Step 3: Add the empty protocol and actor**

`IRemoteService.swift`:

```swift
nonisolated
protocol IRemoteService: Sendable {}
```

`RemoteService.swift`:

```swift
actor RemoteService: IRemoteService {}
```

Keep the LocalDatabase declarations unchanged:

```swift
nonisolated
protocol ILocalDatabaseService: Sendable {}

actor LocalDatabaseService: ILocalDatabaseService {}
```

- [ ] **Step 4: Add the two examples to the interim graph**

Add these immutable properties to `AppDependencies`:

```swift
let localDatabase: any ILocalDatabaseService
let remote: any IRemoteService
```

Use these interim signatures while retaining Browse/Projects/Session:

```swift
init(
    browse: BrowseDependencies,
    projects: ProjectsDependencies,
    session: SessionDependencies,
    localDatabase: any ILocalDatabaseService,
    remote: any IRemoteService
)

static func preview(
    browseItems: [BrowseItem],
    session: UserSession?,
    localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
    remoteService: any IRemoteService = RemoteService()
) -> AppDependencies

static func test(
    browseService: any IBrowseService,
    sessionService: any ISessionService,
    localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
    remoteService: any IRemoteService = RemoteService()
) -> AppDependencies
```

`live()` supplies `LocalDatabaseService()` and `RemoteService()` in addition
to the existing graph. `preview` and `test` pass their two new arguments
unchanged into the initializer.

- [ ] **Step 5: Run focused and full macOS tests**

Run the Step 2 command, then:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/App/AppDependencies \
  AppTemplate/App/Services/LocalDatabase AppTemplate/App/Services/Remote \
  AppTemplateTests/App/Composition \
  AppTemplateTests/App/Services/LocalDatabase \
  AppTemplateTests/App/Services/Remote
git commit -m "feat: add empty remote service example"
```

---

### Task 2: Remove session behavior and make root authentication navigational

**Files:**

- Delete: `AppTemplate/App/Services/Session/ISessionService.swift`
- Delete: `AppTemplate/App/Services/Session/SessionService.swift`
- Delete: `AppTemplate/App/Services/Session/SessionDependencies.swift`
- Delete: `AppTemplate/App/Services/Session/SessionStore.swift`
- Delete: `AppTemplate/App/Models/State/SessionState.swift`
- Delete: `AppTemplate/App/Models/Domain/UserSession.swift`
- Delete: `AppTemplateTests/App/Services/Session/SessionServiceTests.swift`
- Delete: `AppTemplateTests/App/Services/Session/SessionStoreTests.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Modify: `AppTemplate/App/Entry/AppTemplateApp.swift`
- Modify: `AppTemplate/App/Entry/ContentView.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppFlow.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppFlowRouter.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppRootView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppShellView.swift`
- Modify: `AppTemplate/Features/Authentication/Flow/AuthenticationFlowView.swift`
- Modify: `AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift`
- Modify: `AppTemplate/Features/Authentication/Screens/Authentication/ViewModel/AuthenticationViewModel.swift`
- Modify: `AppTemplate/Features/Settings/Flow/SettingsFlowView.swift`
- Modify: `AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift`
- Modify: `AppTemplate/Features/Settings/Screens/Settings/ViewModel/SettingsViewModel.swift`
- Modify: `AppTemplate/Features/Settings/Screens/SessionInfo/View/SessionInfoView.swift`
- Modify: `AppTemplate/Features/Settings/Screens/SessionInfo/ViewModel/SessionInfoViewModel.swift`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- Modify: `AppTemplateTests/App/Navigation/Routing/AppFlowRouterTests.swift`
- Modify: `AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift`
- Modify: `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
- Modify: `AppTemplateTests/Features/Authentication/Screens/Authentication/AuthenticationViewModelTests.swift`
- Modify: `AppTemplateTests/Features/Settings/Screens/Settings/SettingsViewModelTests.swift`
- Modify: `AppTemplateTests/Features/Settings/Screens/SessionInfo/SessionInfoViewModelTests.swift`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**

- Consumes: `AppFlowRouter`, `IRouter`, scene lifecycle, and the interim graph
  from Task 1.
- Produces: `AppFlow` without `.launching`,
  `AppFlowRouter(flow: .authentication)` by default,
  `AuthenticationViewModel.continueToApp()`, and
  `SettingsViewModel.returnToAuthentication()`.
- `AppDependencies` becomes Browse + Projects + LocalDatabase + Remote. Session
  is removed.

- [ ] **Step 1: Rewrite root-flow tests first**

Replace session synchronization tests with:

```swift
@Test
func defaultRouterStartsInAuthentication() {
    let router = AppFlowRouter()

    #expect(router.flow == .authentication)
    #expect(router.transition.historyAction == .preserve)
    #expect(router.transition.pendingIntentAction == .preserve)
}

@Test
func mainFlowResetsAndReplaysPendingIntent() {
    let router = AppFlowRouter(flow: .authentication)

    router.setFlow(.main)

    #expect(router.flow == .main)
    #expect(router.transition.historyAction == .reset)
    #expect(router.transition.pendingIntentAction == .replay)
}

@Test(arguments: [
    AppFlow.authentication,
    AppFlow.onboarding,
    AppFlow.maintenance
])
func nonMainFlowResetsAndDiscardsPendingIntent(flow: AppFlow) {
    let router = AppFlowRouter(flow: .main)

    router.setFlow(flow)

    #expect(router.flow == flow)
    #expect(router.transition.historyAction == .reset)
    #expect(router.transition.pendingIntentAction == .discard)
}
```

Retain the repeated same-flow fresh-ID test.

- [ ] **Step 2: Rewrite Authentication and Settings tests**

Authentication:

```swift
@Test
func continueOpensMainAndReplaysTheReceivingScene() {
    let appFlowRouter = AppFlowRouter(flow: .authentication)
    let viewModel = AuthenticationViewModel(
        router: FlowRouter(appFlowRouter: appFlowRouter)
    )

    viewModel.continueToApp()

    #expect(appFlowRouter.flow == .main)
    #expect(appFlowRouter.transition.pendingIntentAction == .replay)
}
```

Keep Help push, cancellation fresh-transition, and construction tests using
only a router.

Settings:

```swift
@Test
func returnToAuthenticationReplacesTheRoot() {
    let appFlowRouter = AppFlowRouter(flow: .main)
    let viewModel = SettingsViewModel(
        router: FlowRouter(appFlowRouter: appFlowRouter)
    )

    viewModel.returnToAuthentication()

    #expect(appFlowRouter.flow == .authentication)
    #expect(appFlowRouter.transition.pendingIntentAction == .discard)
}
```

Retain About push and Session Info sheet present/dismiss tests. Replace
`SessionInfoViewModelTests` with dependency-free ViewModel/screen construction.

- [ ] **Step 3: Add a direct two-scene replay regression**

In `AppSceneNavigationLifecycleTests`, start one shared app router in
`.authentication`, restore two lifecycles with the current transition, queue a
different URL in each, call `setFlow(.main)`, and apply the transition to both.
Assert that each scene selects and builds only its own exact destination.

Delete tests that call `synchronizeSession`, assert authenticated cold-history
preservation, or construct a launching router. Keep restoration ordering,
snapshot recovery, queued URL order, and duplicate-transition tests.

- [ ] **Step 4: Run focused tests and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/AppFlowRouterTests \
  -only-testing:AppTemplateTests/AppRouterTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests \
  -only-testing:AppTemplateTests/AuthenticationViewModelTests \
  -only-testing:AppTemplateTests/SettingsViewModelTests \
  -only-testing:AppTemplateTests/SessionInfoViewModelTests
```

Expected: exit 65 because the dependency-free initializers and methods do not
exist and `.launching` still exists.

- [ ] **Step 5: Simplify `AppFlow` and `AppFlowRouter`**

`AppFlow` contains exactly:

```swift
case authentication
case onboarding
case main
case maintenance
```

`AppFlowRouter` keeps only its transition, computed flow, initializer,
`setFlow`, and private transition builder:

```swift
init(flow: AppFlow = .authentication) {
    transition = AppFlowTransition(
        id: UUID(),
        flow: flow,
        historyAction: .preserve,
        pendingIntentAction: .preserve
    )
}

func setFlow(_ flow: AppFlow) {
    transition(
        to: flow,
        historyAction: .reset,
        pendingIntentAction: flow == .main ? .replay : .discard
    )
}
```

Delete session phase tracking and `synchronizeSession(_:)`.

- [ ] **Step 6: Remove Session from composition without changing lifecycle order**

`AppTemplateApp` owns `AppDependencies.live()` and:

```swift
@State private var appFlowRouter = AppFlowRouter(flow: .authentication)
```

Delete `SessionStore` state/environment injection. `AppSceneView` must retain
this order:

1. restore snapshot;
2. apply/record the current transition;
3. mark restored;
4. drain queued URLs.

Remove only session start/synchronization and session phase observation.
Retain snapshot persistence, transition observation, transition-ID
deduplication, and `onOpenURL`.

Remove the `.launching` and session-environment branches/parameters from
`AppRootView`, `AppShellView`, `ContentView`, and previews.
`ContentView` constructs its matching `AppFlowRouter`/`AppRouter` pair with
`.authentication`, matching the real application entry.

- [ ] **Step 7: Make Authentication and Settings static**

`AuthenticationViewModel`:

```swift
private let router: any IRouter

init(router: any IRouter) {
    self.router = router
}

func continueToApp() {
    router.setFlow(.main)
}
```

Keep `cancelAuthentication()` and `openHelp()`. Remove async/failure/retry
state. `AuthenticationView` renders static navigation-example copy and uses
ordinary synchronous buttons.

`SettingsViewModel` keeps router, `SettingsSheetRoute?`, About push, sheet
present/dismiss, and:

```swift
func returnToAuthentication() {
    router.setFlow(.authentication)
}
```

`SettingsView` renders static Session text, keeps Session Info sheet, and maps
the Sign Out button to `returnToAuthentication()`.

`SessionInfoViewModel` becomes an empty `@Observable` screen scaffold.
`SessionInfoView` keeps its Done dismissal and renders static template text.

- [ ] **Step 8: Remove session types and update the interim graph**

Delete all listed Session production/tests/model files and embedded service
doubles. `AppDependencies` now contains:

- `browse: BrowseDependencies`;
- `projects: ProjectsDependencies`;
- `localDatabase: any ILocalDatabaseService`;
- `remote: any IRemoteService`.

Use these factory signatures:

```swift
static func preview(
    browseItems: [BrowseItem],
    localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
    remoteService: any IRemoteService = RemoteService()
) -> AppDependencies

static func test(
    browseService: any IBrowseService,
    localDatabaseService: any ILocalDatabaseService,
    remoteService: any IRemoteService
) -> AppDependencies
```

`live()` creates `BrowseService.live()`, `ProjectsDependencies()`,
`LocalDatabaseService()`, and `RemoteService()`. Update composition tests to
assert these four interim graph edges and remove all session
doubles/assertions.

- [ ] **Step 9: Run focused, full macOS, and session-removal guards**

Run the Step 4 command and the full macOS suite. Then:

```bash
! rg -n \
  'SessionService|ISessionService|SessionStore|SessionDependencies|SessionPhase|SessionFailure|synchronizeSession|\\.launching' \
  AppTemplate AppTemplateTests
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 10: Commit**

```bash
git add AppTemplate/App AppTemplate/Features/Authentication \
  AppTemplate/Features/Settings AppTemplateTests/App \
  AppTemplateTests/Features/Authentication \
  AppTemplateTests/Features/Settings \
  AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "refactor: make authentication navigation-only"
```

---

### Task 3: Remove Browse loading and data behavior

**Files:**

- Delete: `AppTemplate/App/Services/Browse/IBrowseService.swift`
- Delete: `AppTemplate/App/Services/Browse/BrowseService.swift`
- Delete: `AppTemplate/Features/Browse/State/BrowseFailure.swift`
- Delete: `AppTemplate/Features/Browse/State/BrowsePreferencesStore.swift`
- Delete: `AppTemplate/Features/Browse/Screens/Browse/State/BrowseListState.swift`
- Delete: `AppTemplate/Features/Browse/Screens/BrowseDetail/State/BrowseDetailState.swift`
- Delete: `AppTemplate/Features/Browse/Screens/RelatedItems/State/RelatedItemsState.swift`
- Delete: `AppTemplate/Features/Browse/Screens/RelatedItemDetail/State/RelatedItemDetailState.swift`
- Delete: `AppTemplateTests/App/Services/Browse/BrowseServiceTests.swift`
- Delete: `AppTemplateTests/Features/Browse/TestSupport/BrowseServiceDoubles.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppShellView.swift`
- Modify: `AppTemplate/Features/Browse/Dependencies/BrowseDependencies.swift`
- Modify: `AppTemplate/Features/Browse/Flow/BrowseFlowView.swift`
- Modify: all Views and ViewModels under:
  `AppTemplate/Features/Browse/Screens/Browse`,
  `BrowseDetail`, `BrowseOptions`, `RelatedItems`, and `RelatedItemDetail`
- Modify:
  `AppTemplateTests/Features/Browse/Screens/Browse/BrowseListViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Browse/Screens/BrowseDetail/BrowseDetailViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Browse/Screens/BrowseOptions/BrowseOptionsViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Browse/Screens/RelatedItems/RelatedItemsViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Browse/Screens/RelatedItemDetail/RelatedItemDetailViewModelTests.swift`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**

- Consumes: typed Browse routes and passive `BrowseItem.ID`.
- Produces:
  `BrowseFlowView(router:)`, `BrowseView(router:)`,
  `BrowseDetailView(id:router:)`,
  `RelatedItemsView(sourceItemID:router:)`,
  `RelatedItemDetailView(id:)`, and dependency-free `BrowseOptionsView()`.
- `AppDependencies` becomes Projects + LocalDatabase + Remote.

- [ ] **Step 1: Rewrite Browse tests for the desired APIs**

The retained tests cover only:

```swift
let router = FlowRouter()
let viewModel = BrowseListViewModel(router: router)
viewModel.openItem(id: "swiftui")
#expect(router.path.count == 1)

viewModel.openOptions()
#expect(viewModel.sheet == .options)
viewModel.dismissSheet()
#expect(viewModel.sheet == nil)
```

`BrowseDetailViewModelTests` assert the supplied ID and related-items push.
`RelatedItemsViewModelTests` assert source ID and related-item push.
`RelatedItemDetailViewModelTests` assert only the supplied ID.
`BrowseOptionsViewModelTests` assert construction of the empty ViewModel and
sheet View.

Construction tests use only the interfaces listed above. Delete all service,
load, empty, failure, retry, cancellation, stale-response, and sort assertions.

- [ ] **Step 2: Run Browse tests and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/BrowseListViewModelTests \
  -only-testing:AppTemplateTests/BrowseDetailViewModelTests \
  -only-testing:AppTemplateTests/BrowseOptionsViewModelTests \
  -only-testing:AppTemplateTests/RelatedItemsViewModelTests \
  -only-testing:AppTemplateTests/RelatedItemDetailViewModelTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: exit 65 because the service-free initializers do not exist.

- [ ] **Step 3: Reduce Browse ViewModels**

Use these exact responsibilities:

```swift
BrowseListViewModel(router:)
// router + BrowseSheetRoute?
// openItem, openOptions, dismissSheet

BrowseDetailViewModel(id:router:)
// id + router + openRelatedItems

RelatedItemsViewModel(sourceItemID:router:)
// sourceItemID + router + openItem

RelatedItemDetailViewModel(id:)
// id only

BrowseOptionsViewModel()
// empty screen scaffold
```

No Browse ViewModel may contain a dependency, preference, state machine,
`Task`, request version, async method, sorting/filtering, or failure behavior.

- [ ] **Step 4: Render static Browse views**

`BrowseView` renders direct native Buttons for `"swiftui"`,
`"observation"`, and `"routing"` instead of a collection supplied by its
ViewModel. It retains its Options sheet and typed destination mapping.

Detail views show the supplied stable identifier and explanatory text.
`RelatedItemsView` renders direct example buttons without filtering a fetched
collection. `BrowseOptionsView` keeps the sheet and Done dismissal but replaces
the sort Picker with static template copy.

Delete `.task`, `.task(id:)`, `onDisappear`, retry/error/loading branches, and
all service/dependency parameters.

- [ ] **Step 5: Delete Browse service/state and collapse its graph edge**

Make `BrowseDependencies` an empty scaffold:

```swift
nonisolated
struct BrowseDependencies: Sendable {
    init() {}
}
```

Delete service/preference/failure/load-state files and their tests/doubles.
Remove Browse from `AppDependencies`; its factories now build only Projects,
LocalDatabase, and Remote. `AppShellView` constructs
`BrowseFlowView(router: router.browse)`.

Use these graph factory signatures:

```swift
static func preview(
    localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
    remoteService: any IRemoteService = RemoteService()
) -> AppDependencies

static func test(
    localDatabaseService: any ILocalDatabaseService,
    remoteService: any IRemoteService
) -> AppDependencies
```

`live()` creates `ProjectsDependencies()`, `LocalDatabaseService()`, and
`RemoteService()`.

- [ ] **Step 6: Run focused/full tests and guards**

Run the Step 2 command and the full macOS suite. Then:

```bash
! rg -n \
  'IBrowseService|BrowseService|BrowsePreferencesStore|BrowseFailure|BrowseListState|BrowseDetailState|RelatedItemsState|RelatedItemDetailState' \
  AppTemplate AppTemplateTests
! rg -n \
  '\\b(async|Task|load|retry|cancel|requestVersion|sortOrder)\\b' \
  AppTemplate/Features/Browse --glob '*.swift'
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate/App AppTemplate/Features/Browse \
  AppTemplateTests/App AppTemplateTests/Features/Browse \
  AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "refactor: make browse navigation-only"
```

---

### Task 4: Remove Projects store, draft, lookup, and save behavior

**Files:**

- Delete: `AppTemplate/Features/Projects/State/ProjectsStore.swift`
- Delete: `AppTemplate/Features/Projects/State/CreateProjectDraftState.swift`
- Delete: `AppTemplateTests/Features/Projects/State/ProjectsStoreTests.swift`
- Create: `AppTemplate/Features/Projects/State/CreateProjectFlowState.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Modify: `AppTemplate/App/Entry/AppTemplateApp.swift`
- Modify: `AppTemplate/App/Entry/ContentView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppRootView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppShellView.swift`
- Modify: `AppTemplate/Features/Projects/Flow/ProjectsFlowView.swift`
- Modify: `AppTemplate/Features/Projects/Flow/CreateProjectFlowView.swift`
- Modify: all Views and ViewModels under:
  `AppTemplate/Features/Projects/Screens/Projects`, `ProjectDetails`,
  `TaskDetails`, `ProjectInfo`, `ProjectBasics`, `ProjectOptions`, and
  `ProjectReview`
- Modify:
  `AppTemplateTests/Features/Projects/Screens/Projects/ProjectsViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Projects/Screens/ProjectDetails/ProjectDetailsViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Projects/Screens/TaskDetails/TaskDetailsViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Projects/Screens/ProjectInfo/ProjectInfoViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Projects/Screens/ProjectBasics/ProjectBasicsViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Projects/Screens/ProjectOptions/ProjectOptionsViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Projects/Screens/ProjectReview/ProjectReviewViewModelTests.swift`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**

- Consumes: passive `ProjectItem.ID`, `ProjectTaskItem.ID`, typed Projects
  routes, `FlowRouter`, and `IAppFlowRouter`.
- Produces:
  `ProjectsFlowView(router:)`,
  `CreateProjectFlowView(appFlowRouter:)`,
  store-free screen initializers, and presentation-only
  `CreateProjectFlowState`.
- `AppDependencies` reaches its final shape: LocalDatabase + Remote only.

- [ ] **Step 1: Rewrite Projects tests first**

Tests assert:

- Projects pushes an arbitrary stable project ID and presents/dismisses the
  Create Project sheet.
- Project Details retains `projectID`, pushes an arbitrary stable task ID, and
  presents/dismisses Project Info.
- Task Details retains arbitrary `projectID` and `taskID`.
- Project Info retains an arbitrary `projectID`.
- Project Basics always pushes `.options`.
- Project Options always pushes `.review`.
- Project Review finish changes only flow presentation state.

The finish test:

```swift
@Test
func finishMarksTheCreateProjectFlowForDismissal() {
    let flowState = CreateProjectFlowState()
    let viewModel = ProjectReviewViewModel(flowState: flowState)

    viewModel.finish()

    #expect(flowState.isFinished)
}
```

Delete all lookup, unavailable, draft binding, validation, save, generated ID,
idempotency, and store mutation assertions.

- [ ] **Step 2: Run Projects tests and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/ProjectsViewModelTests \
  -only-testing:AppTemplateTests/ProjectDetailsViewModelTests \
  -only-testing:AppTemplateTests/TaskDetailsViewModelTests \
  -only-testing:AppTemplateTests/ProjectInfoViewModelTests \
  -only-testing:AppTemplateTests/ProjectBasicsViewModelTests \
  -only-testing:AppTemplateTests/ProjectOptionsViewModelTests \
  -only-testing:AppTemplateTests/ProjectReviewViewModelTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: exit 65 because the store-free APIs and
`CreateProjectFlowState` do not exist.

- [ ] **Step 3: Add presentation-only Create Project state**

```swift
import Observation

@MainActor
@Observable
final class CreateProjectFlowState {
    var isFinished = false
}
```

`ProjectReviewViewModel` stores this state and its only method is:

```swift
func finish() {
    flowState.isFinished = true
}
```

This is sheet presentation state, not project data. Do not inject a navigation
closure.

- [ ] **Step 4: Reduce Projects and destination screens**

Use these exact initializers:

```swift
ProjectsFlowView(router: FlowRouter)
ProjectsView(router: FlowRouter)
ProjectsViewModel(router: any IRouter)

ProjectDetailsView(projectID: ProjectItem.ID, router: FlowRouter)
ProjectDetailsViewModel(projectID: ProjectItem.ID, router: any IRouter)

TaskDetailsView(
    projectID: ProjectItem.ID,
    taskID: ProjectTaskItem.ID
)
TaskDetailsViewModel(
    projectID: ProjectItem.ID,
    taskID: ProjectTaskItem.ID
)

ProjectInfoView(projectID: ProjectItem.ID)
ProjectInfoViewModel(projectID: ProjectItem.ID)
```

Views render static labels/buttons and supplied IDs. `ProjectsView` uses direct
buttons for sample stable IDs. `ProjectDetailsView` uses direct static task
buttons. Remove collection, lookup, and unavailable branches.

- [ ] **Step 5: Reduce the independent Create Project flow**

`CreateProjectFlowView` keeps:

- its own `@State FlowRouter`;
- an `@State CreateProjectFlowState`;
- its `localRouter` read-only test seam;
- `init(appFlowRouter: any IAppFlowRouter)`;
- internal
  `init(flowState: CreateProjectFlowState, appFlowRouter: any IAppFlowRouter)`
  for the real-sheet regression test;
- `@Environment(\.dismiss)` at the flow root.

The screens use:

```swift
ProjectBasicsView(router: FlowRouter, flowState: CreateProjectFlowState)
ProjectOptionsView(router: FlowRouter, flowState: CreateProjectFlowState)
ProjectReviewView(flowState: CreateProjectFlowState)
```

Basics and Options ViewModels keep only their router and push the next typed
route. Review marks the flow state finished. The flow root observes
`isFinished` and dismisses the containing sheet. No draft, store, validation,
save, or navigation closure remains.

- [ ] **Step 6: Delete stores and finalize `AppDependencies`**

Delete `ProjectsStore`, `CreateProjectDraftState`, and `ProjectsStoreTests`.
Keep `ProjectsDependencies` as an empty folder scaffold, but remove it from the
runtime graph.

Final graph:

```swift
nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService
}
```

Use:

```swift
static func live() -> AppDependencies

static func preview(
    localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
    remoteService: any IRemoteService = RemoteService()
) -> AppDependencies

static func test(
    localDatabaseService: any ILocalDatabaseService,
    remoteService: any IRemoteService
) -> AppDependencies
```

`live()` constructs the two concrete examples; `preview` and `test` preserve
the injected existential values. `AppShellView` constructs
`ProjectsFlowView(router: router.projects)` and passes no dependency/store.

Because no feature consumes an example service, remove `dependencies`
parameters from `ContentView`, `AppSceneView`, `AppRootView`, and
`AppShellView`. `AppTemplateApp` still constructs and retains one immutable
`AppDependencies.live()` graph as the future composition root, but passes no
service into a screen. Previews construct the navigation root directly and
`AppDependenciesTests` compile-test the graph/factories.

- [ ] **Step 7: Update construction and real-sheet dismissal coverage**

`ProjectConfigurationTests` constructs every Projects flow/screen with the new
APIs. Keep the modal-router isolation/global-forwarding test.

Replace the macOS draft/save sheet test with:

1. present `CreateProjectFlowView` using an injected
   `CreateProjectFlowState`;
2. verify the sheet appears;
3. call `ProjectReviewViewModel(flowState:).finish()`;
4. verify the attached sheet disappears;
5. make no assertion about created data.

- [ ] **Step 8: Run focused/full tests and guards**

Run the Step 2 command and the full macOS suite. Then:

```bash
! rg -n \
  'ProjectsStore|ProjectsStoreError|CreateProjectDraftState' \
  AppTemplate AppTemplateTests
! rg -n \
  '\\b(Service|Store|Repository|AppDependencies|async|Task|load|retry|save|signIn|signOut)\\b' \
  AppTemplate/Features/Projects --glob '*.swift'
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 9: Commit**

```bash
git add AppTemplate/App AppTemplate/Features/Projects \
  AppTemplateTests/App AppTemplateTests/Features/Projects \
  AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "refactor: make projects navigation-only"
```

---

### Task 5: Strip presentation data and lookup from remaining ViewModels

**Files:**

- Modify:
  `AppTemplate/Features/Home/Screens/HomeDetails/View/HomeDetailsView.swift`
- Modify:
  `AppTemplate/Features/Home/Screens/HomeDetails/ViewModel/HomeDetailsViewModel.swift`
- Modify:
  `AppTemplate/Features/Home/Screens/NavigationGuide/Model/NavigationGuideModel.swift`
- Modify:
  `AppTemplate/Features/Home/Screens/NavigationGuide/View/NavigationGuideView.swift`
- Modify:
  `AppTemplate/Features/Home/Screens/NavigationGuide/ViewModel/NavigationGuideViewModel.swift`
- Modify:
  `AppTemplate/Features/Home/Screens/GuideTopic/View/GuideTopicView.swift`
- Modify:
  `AppTemplate/Features/Home/Screens/GuideTopic/ViewModel/GuideTopicViewModel.swift`
- Modify:
  `AppTemplate/Features/Home/Screens/QuickStart/View/QuickStartView.swift`
- Modify:
  `AppTemplate/Features/Home/Screens/QuickStart/ViewModel/QuickStartViewModel.swift`
- Modify: `AppTemplate/Features/Settings/Screens/About/View/AboutView.swift`
- Modify:
  `AppTemplate/Features/Settings/Screens/About/ViewModel/AboutViewModel.swift`
- Modify:
  `AppTemplateTests/Features/Home/Screens/HomeDetails/HomeDetailsViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Home/Screens/NavigationGuide/NavigationGuideViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Home/Screens/GuideTopic/GuideTopicViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Home/Screens/QuickStart/QuickStartViewModelTests.swift`
- Modify:
  `AppTemplateTests/Features/Settings/Screens/About/AboutViewModelTests.swift`

**Interfaces:**

- Consumes: existing Home/Settings typed routes.
- Produces: ViewModels containing only routers or stable destination IDs.
- Static strings, icons, and direct presentation rows move into Views.

- [ ] **Step 1: Rewrite tests around navigation-only responsibilities**

Remove ViewModel assertions for titles, messages, platform arrays, guide
arrays, and model lookup.

Retain:

- Home Details typed push and independent-router tests;
- Navigation Guide pop and topic-push tests using a literal stable ID;
- Guide Topic supplied-ID retention;
- construction tests;
- About platform push;
- Platform Details supplied-name retention.

`QuickStartViewModelTests` becomes only construction of its empty ViewModel and
sheet View.

- [ ] **Step 2: Run focused tests and verify they expose old APIs**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/HomeDetailsViewModelTests \
  -only-testing:AppTemplateTests/NavigationGuideViewModelTests \
  -only-testing:AppTemplateTests/GuideTopicViewModelTests \
  -only-testing:AppTemplateTests/QuickStartViewModelTests \
  -only-testing:AppTemplateTests/AboutViewModelTests \
  -only-testing:AppTemplateTests/PlatformDetailsViewModelTests
```

Then run this structural RED guard:

```bash
! rg -n \
  'let title|let message|var items|supportedPlatforms|exampleDescription|NavigationGuideModel\\.items|\\.first\\s*\\{' \
  AppTemplate/Features/Home/Screens/*/ViewModel \
  AppTemplate/Features/Settings/Screens/*/ViewModel
```

Expected: the test command may pass after test simplification, but the guard
must exit nonzero because presentation data and lookup remain in ViewModels.
The guard is this refactor's RED evidence.

- [ ] **Step 3: Move static presentation into Views**

- `HomeDetailsViewModel`: router + `openNavigationGuide()` only.
- `NavigationGuideViewModel`: router + `close()` + `openTopic(id:)` only.
- `NavigationGuideModel`: empty passive Model scaffold.
- `GuideTopicViewModel`: supplied stable `id` only.
- `QuickStartViewModel`: empty `@Observable` scaffold.
- `AboutViewModel`: router + `openPlatform(name:)` only.
- `PlatformDetailsViewModel`: supplied `name` only.

Views render direct static text/buttons. Navigation Guide may use a private
View-owned immutable row type. Guide Topic displays the received ID rather than
looking it up. About renders direct platform buttons and static explanatory
text.

- [ ] **Step 4: Run focused/full tests and the guard**

Run the Step 2 test command and guard, then the full macOS suite. Expected:
PASS and zero guard matches.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Home AppTemplate/Features/Settings \
  AppTemplateTests/Features/Home AppTemplateTests/Features/Settings
git commit -m "refactor: keep view models navigation-only"
```

---

### Task 6: Update architecture documentation and verify the reduction

**Files:**

- Modify: `README.md`
- Modify:
  `docs/superpowers/specs/2026-07-30-global-app-flow-router-design.md`
- Verify: all `AppTemplateTests`

**Interfaces:**

- Consumes: the complete navigation-only implementation.
- Produces: accurate public documentation, structural evidence, three-platform
  test evidence, and interactive sheet/alert/navigation smoke evidence.

- [ ] **Step 1: Update README and supersession note**

README must state:

- the template has no real authentication, network, database, Browse, or
  Projects behavior;
- LocalDatabase and Remote are empty DI examples;
- ViewModels are navigation/presentation-only;
- the app starts in Authentication and Continue/Sign Out demonstrate root-flow
  replacement;
- sheets, alerts, dialogs, typed routes, deep links, snapshots, and
  multi-window root flow remain functional.

Add a short note to the older global-flow design that its session-service and
authenticated-cold-restoration sections are superseded by
`2026-07-30-navigation-only-app-shell-design.md`. Do not rewrite its history.

- [ ] **Step 2: Run final source guards**

```bash
test "$(rg --files AppTemplate/App/Services | sort | wc -l | tr -d ' ')" -eq 4
rg --files AppTemplate/App/Services | sort

! rg -n \
  'SessionService|ISessionService|SessionStore|SessionDependencies|SessionPhase|SessionFailure|synchronizeSession|ProjectsStore|CreateProjectDraftState|IBrowseService|BrowseService|BrowsePreferencesStore|BrowseFailure|\\.launching' \
  AppTemplate AppTemplateTests

! rg -n \
  '\\b(Service|Store|Repository|AppDependencies)\\b' \
  AppTemplate/Features --glob '*.swift'

! rg -n \
  '\\b(async|Task|load|retry|save|signIn|signOut)\\b' \
  AppTemplate/Features --glob '*ViewModel.swift'

test "$(rg -n 'case authentication|case onboarding|case main|case maintenance' \
  AppTemplate/App/Navigation/Routing/AppFlow.swift | wc -l | tr -d ' ')" -eq 4

test "$(rg -n 'func setFlow\\(_ flow: AppFlow\\)' \
  AppTemplate/App/Navigation | wc -l | tr -d ' ')" -ge 2

! rg -n 'nonisolated (protocol|struct|enum|class|actor)' \
  AppTemplate AppTemplateTests --glob '*.swift'

git diff --exit-code main...HEAD -- AppTemplate.xcodeproj/project.pbxproj
git diff --check
```

Expected service files are exactly:

```text
AppTemplate/App/Services/LocalDatabase/ILocalDatabaseService.swift
AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift
AppTemplate/App/Services/Remote/IRemoteService.swift
AppTemplate/App/Services/Remote/RemoteService.swift
```

All commands exit 0.

- [ ] **Step 3: Run the complete macOS suite**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/AppTemplate-navigation-only-macos
```

Expected: exit 0, no failures or skips.

- [ ] **Step 4: Run the complete iPhone suite**

Before the first XcodeBuildMCP simulator call, run
`session_show_defaults`. Use iPhone 17 Pro, iOS 26.5, UDID
`A2DCC39D-84E2-4E96-B1EF-C6D841FD3B8A`.

Equivalent shell command:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/AppTemplate-navigation-only-iphone
```

Expected: exit 0, no failures or skips.

- [ ] **Step 5: Run the complete iPad suite**

Use iPad Pro 13-inch (M5), iOS 26.5, UDID
`1B12574D-F163-4952-8E39-4DD541C39F56`.

Equivalent shell command:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  -derivedDataPath /tmp/AppTemplate-navigation-only-ipad
```

Expected: exit 0, no failures or skips.

- [ ] **Step 6: Run interactive smoke checks**

On iPhone:

1. Authentication → Continue → Main/Home.
2. Home → Quick Start sheet → Done.
3. Home → reset-navigation alert → Cancel, then Reset.
4. Browse → Options sheet → Done.
5. Browse → static item → Related Items → related item.
6. Projects → Create Project sheet → Basics → Options → Review → Finish;
   verify the sheet dismisses and no data is created.
7. Settings → Session Info sheet → Done.
8. Settings → Sign Out → Authentication.
9. While Authentication is visible, open a project/task deep link; Continue
   must replay the exact destination in the receiving scene.

Repeat root, Browse sheet, and Create Project sheet transitions on iPad.

On macOS, open two windows with distinct tabs/paths, trigger a root transition,
and verify both roots change while scene paths remain independently owned.

- [ ] **Step 7: Commit documentation**

```bash
git add README.md \
  docs/superpowers/specs/2026-07-30-global-app-flow-router-design.md
git commit -m "docs: explain navigation-only template"
```

- [ ] **Step 8: Request final whole-branch review**

Review the complete implementation range against:

- exactly two empty DI services;
- no Session/Browse/Projects runtime logic;
- navigation/presentation-only ViewModels;
- every screen/folder scaffold preserved;
- sheets, alerts, dialogs, typed routes, snapshots, and deep links preserved;
- scene-local pending-intent replay;
- no project-file or unrelated main-checkout changes;
- three-platform tests and interactive smoke evidence.
