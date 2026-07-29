# Expanded Navigation and Sheets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add meaningful deeper push navigation, screen-owned one-screen sheets, a new Projects tab, and an independent multi-screen create-project sheet flow.

**Architecture:** Authentication and every tab retain one scene-scoped `FlowRouter` and one main `NavigationStack`. Each screen owns its outgoing push Route, destination mapping, and optional sheet route; the create-project sheet is the only modal that starts a new temporary flow. Projects uses feature-scoped observable state, schema-3 navigation snapshots migrate schema 2, and project deep links construct canonical mixed screen-owned paths.

**Tech Stack:** Swift 6, SwiftUI Observation, `NavigationStack`, `NavigationPath`, `.sheet(item:)`, Swift Testing, Xcode 26, iOS/iPadOS/macOS 26.

## Global Constraints

- Support iOS 26, iPadOS 26, and macOS 26 without adding dependencies.
- Keep exactly one main `FlowRouter` and navigation container per independent app flow.
- Keep simple sheets transient and free of nested navigation containers.
- Give the create-project sheet exactly one temporary `FlowRouter` and `NavigationStack`.
- Keep push Route and `.navigationDestination` ownership on the initiating screen.
- Keep sheet enums on the initiating screen ViewModel; do not conform them to `NavigationRoute` or `Codable`.
- Inject `any IFlowRouter` into ViewModels; do not inject navigation, save, cancel, or completion closures.
- Every new full screen gets `Model`, `Navigation`, `State`, `View`, and `ViewModel` files.
- Keep `nonisolated` on its own line before declarations.
- Preserve existing Browse loading, retry, error, and cancellation semantics.
- Do not add Services, Repositories, network clients, database code, force unwraps, forced casts, `fatalError`, or `AnyView`.
- Preserve unrelated working-tree changes and stage only task-owned files.

---

## File Map

### Application files modified

- `AppTemplate/App/AppDependencies/AppDependencies.swift`: add the Projects dependency scope.
- `AppTemplate/App/Navigation/Containers/AppShellView.swift`: add the Projects tab.
- `AppTemplate/App/Navigation/DeepLinks/DeepLinkParser.swift`: parse Projects URLs.
- `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`: persist migrated snapshots.
- `AppTemplate/App/Navigation/Routing/AppRouter.swift`: own/reset/restore the Projects Router and apply project intents.
- `AppTemplate/App/Navigation/Routing/AppSection.swift`: add `.projects`.
- `AppTemplate/App/Navigation/Routing/NavigationIntent.swift`: add project and task intents.
- `AppTemplate/App/Navigation/Snapshots/NavigationSnapshot.swift`: schema 3 and schema-2 decoding.
- `README.md`: document Projects, sheets, and snapshot migration.

### Shared domain files created

- `AppTemplate/App/Models/Domain/ProjectItem.swift`
- `AppTemplate/App/Models/Domain/ProjectTaskItem.swift`

### Feature foundations created

- `AppTemplate/Features/Projects/Dependencies/ProjectsDependencies.swift`
- `AppTemplate/Features/Projects/Flow/ProjectsFlowView.swift`
- `AppTemplate/Features/Projects/Flow/CreateProjectFlowView.swift`
- `AppTemplate/Features/Projects/State/ProjectsStore.swift`
- `AppTemplate/Features/Projects/State/CreateProjectDraftState.swift`
- `AppTemplate/Features/Browse/State/BrowsePreferencesStore.swift`

### Screen files created

- `AppTemplate/Features/Authentication/Screens/AuthenticationHelp/Model/AuthenticationHelpModel.swift`
- `AppTemplate/Features/Authentication/Screens/AuthenticationHelp/Navigation/AuthenticationHelpRoute.swift`
- `AppTemplate/Features/Authentication/Screens/AuthenticationHelp/State/AuthenticationHelpState.swift`
- `AppTemplate/Features/Authentication/Screens/AuthenticationHelp/View/AuthenticationHelpView.swift`
- `AppTemplate/Features/Authentication/Screens/AuthenticationHelp/ViewModel/AuthenticationHelpViewModel.swift`
- `AppTemplate/Features/Home/Screens/GuideTopic/Model/GuideTopicModel.swift`
- `AppTemplate/Features/Home/Screens/GuideTopic/Navigation/GuideTopicRoute.swift`
- `AppTemplate/Features/Home/Screens/GuideTopic/State/GuideTopicState.swift`
- `AppTemplate/Features/Home/Screens/GuideTopic/View/GuideTopicView.swift`
- `AppTemplate/Features/Home/Screens/GuideTopic/ViewModel/GuideTopicViewModel.swift`
- `AppTemplate/Features/Home/Screens/QuickStart/Model/QuickStartModel.swift`
- `AppTemplate/Features/Home/Screens/QuickStart/Navigation/QuickStartRoute.swift`
- `AppTemplate/Features/Home/Screens/QuickStart/State/QuickStartState.swift`
- `AppTemplate/Features/Home/Screens/QuickStart/View/QuickStartView.swift`
- `AppTemplate/Features/Home/Screens/QuickStart/ViewModel/QuickStartViewModel.swift`
- `AppTemplate/Features/Browse/Screens/BrowseOptions/Model/BrowseOptionsModel.swift`
- `AppTemplate/Features/Browse/Screens/BrowseOptions/Navigation/BrowseOptionsRoute.swift`
- `AppTemplate/Features/Browse/Screens/BrowseOptions/State/BrowseOptionsState.swift`
- `AppTemplate/Features/Browse/Screens/BrowseOptions/View/BrowseOptionsView.swift`
- `AppTemplate/Features/Browse/Screens/BrowseOptions/ViewModel/BrowseOptionsViewModel.swift`
- `AppTemplate/Features/Browse/Screens/RelatedItems/Model/RelatedItemsModel.swift`
- `AppTemplate/Features/Browse/Screens/RelatedItems/Navigation/RelatedItemsRoute.swift`
- `AppTemplate/Features/Browse/Screens/RelatedItems/State/RelatedItemsState.swift`
- `AppTemplate/Features/Browse/Screens/RelatedItems/View/RelatedItemsView.swift`
- `AppTemplate/Features/Browse/Screens/RelatedItems/ViewModel/RelatedItemsViewModel.swift`
- `AppTemplate/Features/Browse/Screens/RelatedItemDetail/Model/RelatedItemDetailModel.swift`
- `AppTemplate/Features/Browse/Screens/RelatedItemDetail/Navigation/RelatedItemDetailRoute.swift`
- `AppTemplate/Features/Browse/Screens/RelatedItemDetail/State/RelatedItemDetailState.swift`
- `AppTemplate/Features/Browse/Screens/RelatedItemDetail/View/RelatedItemDetailView.swift`
- `AppTemplate/Features/Browse/Screens/RelatedItemDetail/ViewModel/RelatedItemDetailViewModel.swift`
- `AppTemplate/Features/Settings/Screens/PlatformDetails/Model/PlatformDetailsModel.swift`
- `AppTemplate/Features/Settings/Screens/PlatformDetails/Navigation/PlatformDetailsRoute.swift`
- `AppTemplate/Features/Settings/Screens/PlatformDetails/State/PlatformDetailsState.swift`
- `AppTemplate/Features/Settings/Screens/PlatformDetails/View/PlatformDetailsView.swift`
- `AppTemplate/Features/Settings/Screens/PlatformDetails/ViewModel/PlatformDetailsViewModel.swift`
- `AppTemplate/Features/Settings/Screens/SessionInfo/Model/SessionInfoModel.swift`
- `AppTemplate/Features/Settings/Screens/SessionInfo/Navigation/SessionInfoRoute.swift`
- `AppTemplate/Features/Settings/Screens/SessionInfo/State/SessionInfoState.swift`
- `AppTemplate/Features/Settings/Screens/SessionInfo/View/SessionInfoView.swift`
- `AppTemplate/Features/Settings/Screens/SessionInfo/ViewModel/SessionInfoViewModel.swift`
- `AppTemplate/Features/Projects/Screens/Projects/Model/ProjectsModel.swift`
- `AppTemplate/Features/Projects/Screens/Projects/Navigation/ProjectsRoute.swift`
- `AppTemplate/Features/Projects/Screens/Projects/State/ProjectsState.swift`
- `AppTemplate/Features/Projects/Screens/Projects/View/ProjectsView.swift`
- `AppTemplate/Features/Projects/Screens/Projects/ViewModel/ProjectsViewModel.swift`
- `AppTemplate/Features/Projects/Screens/ProjectDetails/Model/ProjectDetailsModel.swift`
- `AppTemplate/Features/Projects/Screens/ProjectDetails/Navigation/ProjectDetailsRoute.swift`
- `AppTemplate/Features/Projects/Screens/ProjectDetails/State/ProjectDetailsState.swift`
- `AppTemplate/Features/Projects/Screens/ProjectDetails/View/ProjectDetailsView.swift`
- `AppTemplate/Features/Projects/Screens/ProjectDetails/ViewModel/ProjectDetailsViewModel.swift`
- `AppTemplate/Features/Projects/Screens/TaskDetails/Model/TaskDetailsModel.swift`
- `AppTemplate/Features/Projects/Screens/TaskDetails/Navigation/TaskDetailsRoute.swift`
- `AppTemplate/Features/Projects/Screens/TaskDetails/State/TaskDetailsState.swift`
- `AppTemplate/Features/Projects/Screens/TaskDetails/View/TaskDetailsView.swift`
- `AppTemplate/Features/Projects/Screens/TaskDetails/ViewModel/TaskDetailsViewModel.swift`
- `AppTemplate/Features/Projects/Screens/ProjectInfo/Model/ProjectInfoModel.swift`
- `AppTemplate/Features/Projects/Screens/ProjectInfo/Navigation/ProjectInfoRoute.swift`
- `AppTemplate/Features/Projects/Screens/ProjectInfo/State/ProjectInfoState.swift`
- `AppTemplate/Features/Projects/Screens/ProjectInfo/View/ProjectInfoView.swift`
- `AppTemplate/Features/Projects/Screens/ProjectInfo/ViewModel/ProjectInfoViewModel.swift`
- `AppTemplate/Features/Projects/Screens/ProjectBasics/Model/ProjectBasicsModel.swift`
- `AppTemplate/Features/Projects/Screens/ProjectBasics/Navigation/ProjectBasicsRoute.swift`
- `AppTemplate/Features/Projects/Screens/ProjectBasics/State/ProjectBasicsState.swift`
- `AppTemplate/Features/Projects/Screens/ProjectBasics/View/ProjectBasicsView.swift`
- `AppTemplate/Features/Projects/Screens/ProjectBasics/ViewModel/ProjectBasicsViewModel.swift`
- `AppTemplate/Features/Projects/Screens/ProjectOptions/Model/ProjectOptionsModel.swift`
- `AppTemplate/Features/Projects/Screens/ProjectOptions/Navigation/ProjectOptionsRoute.swift`
- `AppTemplate/Features/Projects/Screens/ProjectOptions/State/ProjectOptionsState.swift`
- `AppTemplate/Features/Projects/Screens/ProjectOptions/View/ProjectOptionsView.swift`
- `AppTemplate/Features/Projects/Screens/ProjectOptions/ViewModel/ProjectOptionsViewModel.swift`
- `AppTemplate/Features/Projects/Screens/ProjectReview/Model/ProjectReviewModel.swift`
- `AppTemplate/Features/Projects/Screens/ProjectReview/Navigation/ProjectReviewRoute.swift`
- `AppTemplate/Features/Projects/Screens/ProjectReview/State/ProjectReviewState.swift`
- `AppTemplate/Features/Projects/Screens/ProjectReview/View/ProjectReviewView.swift`
- `AppTemplate/Features/Projects/Screens/ProjectReview/ViewModel/ProjectReviewViewModel.swift`

### Test files created

- `AppTemplateTests/App/Models/Domain/ProjectItemTests.swift`
- `AppTemplateTests/Features/Projects/State/ProjectsStoreTests.swift`
- `AppTemplateTests/Features/Projects/Screens/Projects/ProjectsViewModelTests.swift`
- `AppTemplateTests/Features/Projects/Screens/ProjectDetails/ProjectDetailsViewModelTests.swift`
- `AppTemplateTests/Features/Projects/Screens/TaskDetails/TaskDetailsViewModelTests.swift`
- `AppTemplateTests/Features/Projects/Screens/ProjectInfo/ProjectInfoViewModelTests.swift`
- `AppTemplateTests/Features/Projects/Screens/ProjectBasics/ProjectBasicsViewModelTests.swift`
- `AppTemplateTests/Features/Projects/Screens/ProjectOptions/ProjectOptionsViewModelTests.swift`
- `AppTemplateTests/Features/Projects/Screens/ProjectReview/ProjectReviewViewModelTests.swift`
- `AppTemplateTests/Features/Authentication/Screens/AuthenticationHelp/AuthenticationHelpViewModelTests.swift`
- `AppTemplateTests/Features/Home/Screens/GuideTopic/GuideTopicViewModelTests.swift`
- `AppTemplateTests/Features/Home/Screens/QuickStart/QuickStartViewModelTests.swift`
- `AppTemplateTests/Features/Browse/Screens/BrowseOptions/BrowseOptionsViewModelTests.swift`
- `AppTemplateTests/Features/Browse/Screens/RelatedItems/RelatedItemsViewModelTests.swift`
- `AppTemplateTests/Features/Browse/Screens/RelatedItemDetail/RelatedItemDetailViewModelTests.swift`
- `AppTemplateTests/Features/Settings/Screens/PlatformDetails/PlatformDetailsViewModelTests.swift`
- `AppTemplateTests/Features/Settings/Screens/SessionInfo/SessionInfoViewModelTests.swift`

---

### Task 1: Projects domain and feature state

**Files:**

- Create: `AppTemplate/App/Models/Domain/ProjectItem.swift`
- Create: `AppTemplate/App/Models/Domain/ProjectTaskItem.swift`
- Create: `AppTemplate/Features/Projects/Dependencies/ProjectsDependencies.swift`
- Create: `AppTemplate/Features/Projects/State/ProjectsStore.swift`
- Create: `AppTemplate/Features/Projects/State/CreateProjectDraftState.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Create: `AppTemplateTests/App/Models/Domain/ProjectItemTests.swift`
- Create: `AppTemplateTests/Features/Projects/State/ProjectsStoreTests.swift`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`

**Interfaces:**

- Produces: `ProjectItem`, `ProjectTaskItem`, `ProjectsDependencies`, `ProjectsStore`, and `CreateProjectDraftState`.
- Produces: `ProjectsStore.init(projects: [ProjectItem])`,
  `private(set) var projects: [ProjectItem]`,
  `project(id: ProjectItem.ID) -> ProjectItem?`,
  `task(projectID: ProjectItem.ID, taskID: ProjectTaskItem.ID) -> ProjectTaskItem?`,
  and `addProject(from: CreateProjectDraftState) throws -> ProjectItem`.
- Consumes: no new production interfaces.

- [ ] **Step 1: Write failing domain and store tests**

```swift
@MainActor
@Test
func storeLooksUpProjectsAndTasksByStableID() throws {
    let task = ProjectTaskItem(id: "task-1", title: "Ship", isComplete: false)
    let project = ProjectItem(
        id: "project-1",
        title: "Template",
        summary: "Navigation work",
        colorName: "blue",
        tasks: [task]
    )
    let store = ProjectsStore(projects: [project])

    #expect(store.project(id: "project-1") == project)
    #expect(store.task(projectID: "project-1", taskID: "task-1") == task)
    #expect(store.project(id: "missing") == nil)
}

@MainActor
@Test
func addingDraftCreatesExactlyOneProject() throws {
    let store = ProjectsStore(projects: [])
    let draft = CreateProjectDraftState()
    draft.title = "  New Project  "
    draft.summary = "Example"
    draft.colorName = "indigo"

    let created = try store.addProject(from: draft)

    #expect(store.projects == [created])
    #expect(created.title == "New Project")
    #expect(created.tasks.isEmpty)
}
```

Also add a test asserting a whitespace-only title throws
`ProjectsStoreError.emptyTitle` and leaves `projects` unchanged.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ProjectItemTests \
  -only-testing:AppTemplateTests/ProjectsStoreTests
```

Expected: build failure because the Projects domain and state types do not
exist.

- [ ] **Step 3: Implement the domain and state interfaces**

Use these declarations:

```swift
nonisolated
struct ProjectTaskItem: Identifiable, Codable, Hashable, Sendable {
    typealias ID = String

    let id: ID
    var title: String
    var isComplete: Bool
}

nonisolated
struct ProjectItem: Identifiable, Codable, Hashable, Sendable {
    typealias ID = String

    let id: ID
    var title: String
    var summary: String
    var colorName: String
    var tasks: [ProjectTaskItem]
}

nonisolated
struct ProjectsDependencies: Sendable {
    init() {}
}

@MainActor
@Observable
final class CreateProjectDraftState {
    var title = ""
    var summary = ""
    var colorName = "blue"

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated
enum ProjectsStoreError: Error, Equatable, Sendable {
    case emptyTitle
}
```

`ProjectsStore` must accept injected projects, expose deterministic example
projects through its convenience/default initializer, and generate a new
`UUID().uuidString` only inside `addProject(from:)`.

Add `projects: ProjectsDependencies` to `AppDependencies`; construct
`ProjectsDependencies()` in `live()`, `preview(...)`, and `test(...)` without
changing those factory signatures.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the command from Step 2 plus:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AppDependenciesTests
```

Expected: all selected tests pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Models/Domain/ProjectItem.swift \
  AppTemplate/App/Models/Domain/ProjectTaskItem.swift \
  AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplate/Features/Projects/Dependencies/ProjectsDependencies.swift \
  AppTemplate/Features/Projects/State \
  AppTemplateTests/App/Models/Domain/ProjectItemTests.swift \
  AppTemplateTests/App/Composition/AppDependenciesTests.swift \
  AppTemplateTests/Features/Projects/State/ProjectsStoreTests.swift
git commit -m "feat: add projects domain and feature state"
```

### Task 2: Projects tab and main push hierarchy

**Files:**

- Create: `AppTemplate/Features/Projects/Flow/ProjectsFlowView.swift`
- Create all five scaffold files for `Projects/Screens/Projects`
- Create all five scaffold files for `Projects/Screens/ProjectDetails`
- Create all five scaffold files for `Projects/Screens/TaskDetails`
- Modify: `AppTemplate/App/Navigation/Routing/AppSection.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppShellView.swift`
- Create: `AppTemplateTests/Features/Projects/Screens/Projects/ProjectsViewModelTests.swift`
- Create: `AppTemplateTests/Features/Projects/Screens/ProjectDetails/ProjectDetailsViewModelTests.swift`
- Create: `AppTemplateTests/Features/Projects/Screens/TaskDetails/TaskDetailsViewModelTests.swift`
- Modify: `AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**

- Consumes: `ProjectsStore`, `ProjectsDependencies`, `ProjectItem`, and `ProjectTaskItem` from Task 1.
- Produces: `ProjectsRoute.project(id:)` and
  `ProjectDetailsRoute.task(projectID:taskID:)`.
- Produces: `AppRouter.projects` and `AppSection.projects`.
- Produces: `ProjectsViewModel.init(store:router:)`,
  `openProject(id: ProjectItem.ID)`;
  `ProjectDetailsViewModel.init(projectID:store:router:)`,
  `openTask(id: ProjectTaskItem.ID)`; and
  `TaskDetailsViewModel.init(projectID:taskID:store:)`.

- [ ] **Step 1: Write failing Router and ViewModel tests**

```swift
@MainActor
@Test
func projectsAndDetailsPushScreenOwnedRoutes() {
    let router = FlowRouter()
    let store = ProjectsStore()
    let project = store.projects[0]
    let task = project.tasks[0]
    let projects = ProjectsViewModel(store: store, router: router)

    projects.openProject(id: project.id)
    #expect(router.path.count == 1)

    let details = ProjectDetailsViewModel(
        projectID: project.id,
        store: store,
        router: router
    )
    details.openTask(id: task.id)
    #expect(router.path.count == 2)
}

@MainActor
@Test
func missingProjectAndTaskResolveToUnavailableContent() {
    let store = ProjectsStore(projects: [])

    #expect(
        ProjectDetailsViewModel(
            projectID: "missing",
            store: store,
            router: FlowRouter()
        ).project == nil
    )
    #expect(
        TaskDetailsViewModel(
            projectID: "missing",
            taskID: "missing",
            store: store
        ).task == nil
    )
}

@MainActor
@Test
func appRouterOwnsAndResetsProjectsHistory() {
    let router = AppRouter()
    router.projects.push(ProjectsRoute.project(id: "project-1"))

    router.requireAuthentication()

    #expect(router.projects.path.isEmpty)
}
```

Update the designated-initializer test to inject and identity-check a
`projects` Router. Extend the existing authentication-failure and logout tests
to prove they reset Projects alongside the other flow histories. Add
construction assertions for `ProjectsFlowView`, `ProjectsView`,
`ProjectDetailsView`, and `TaskDetailsView` with explicit Router, store, and
dependency arguments.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ProjectsViewModelTests \
  -only-testing:AppTemplateTests/ProjectDetailsViewModelTests \
  -only-testing:AppTemplateTests/TaskDetailsViewModelTests \
  -only-testing:AppTemplateTests/AppRouterTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: build failure for missing Projects screens, routes, and Router.

- [ ] **Step 3: Implement the Projects hierarchy**

Use these routes:

```swift
nonisolated
enum ProjectsRoute: NavigationRoute {
    case project(id: ProjectItem.ID)
}

nonisolated
enum ProjectDetailsRoute: NavigationRoute {
    case task(
        projectID: ProjectItem.ID,
        taskID: ProjectTaskItem.ID
    )
}

nonisolated
enum TaskDetailsRoute {}
```

`ProjectsViewModel` exposes `store.projects` and pushes `ProjectsRoute`.
`ProjectDetailsViewModel` resolves its project, exposes its tasks, and pushes
`ProjectDetailsRoute`. `TaskDetailsViewModel` resolves the project and task;
missing IDs produce nil content rendered with `EmptyStateView`.

`ProjectsView` owns the `ProjectsRoute` destination mapping.
`ProjectDetailsView` owns the `ProjectDetailsRoute` mapping.
`TaskDetailsView` is a leaf.

`ProjectsFlowView` owns `@State private var store: ProjectsStore`, binds one
`NavigationStack` to the injected Router, and constructs `ProjectsView`.

Add `.projects` to `AppSection`. Add `projects: FlowRouter` to both AppRouter
initializers, `router(for:)`, and `resetFlowHistories()`. Add this tab between
Browse and Settings:

```swift
Tab("Projects", systemImage: "folder", value: AppSection.projects) {
    ProjectsFlowView(
        router: router.projects,
        dependencies: dependencies.projects
    )
}
```

Create empty Model and State structs for each new screen using the established
multiline conformance style.

- [ ] **Step 4: Run focused and construction tests**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ProjectsViewModelTests \
  -only-testing:AppTemplateTests/ProjectDetailsViewModelTests \
  -only-testing:AppTemplateTests/TaskDetailsViewModelTests \
  -only-testing:AppTemplateTests/AppRouterTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: all selected tests pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Navigation/Routing/AppSection.swift \
  AppTemplate/App/Navigation/Routing/AppRouter.swift \
  AppTemplate/App/Navigation/Containers/AppShellView.swift \
  AppTemplate/Features/Projects \
  AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift \
  AppTemplateTests/Features/Projects/Screens \
  AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "feat: add projects navigation flow"
```

### Task 3: Projects sheets and create-project modal flow

**Files:**

- Create: `AppTemplate/Features/Projects/Flow/CreateProjectFlowView.swift`
- Create all five scaffold files for `Projects/Screens/ProjectInfo`
- Create all five scaffold files for `Projects/Screens/ProjectBasics`
- Create all five scaffold files for `Projects/Screens/ProjectOptions`
- Create all five scaffold files for `Projects/Screens/ProjectReview`
- Modify: `AppTemplate/Features/Projects/Screens/Projects/Navigation/ProjectsRoute.swift`
- Modify: `AppTemplate/Features/Projects/Screens/Projects/View/ProjectsView.swift`
- Modify: `AppTemplate/Features/Projects/Screens/Projects/ViewModel/ProjectsViewModel.swift`
- Modify: `AppTemplate/Features/Projects/Screens/ProjectDetails/Navigation/ProjectDetailsRoute.swift`
- Modify: `AppTemplate/Features/Projects/Screens/ProjectDetails/View/ProjectDetailsView.swift`
- Modify: `AppTemplate/Features/Projects/Screens/ProjectDetails/ViewModel/ProjectDetailsViewModel.swift`
- Create: `AppTemplateTests/Features/Projects/Screens/ProjectBasics/ProjectBasicsViewModelTests.swift`
- Create: `AppTemplateTests/Features/Projects/Screens/ProjectOptions/ProjectOptionsViewModelTests.swift`
- Create: `AppTemplateTests/Features/Projects/Screens/ProjectReview/ProjectReviewViewModelTests.swift`
- Create: `AppTemplateTests/Features/Projects/Screens/ProjectInfo/ProjectInfoViewModelTests.swift`
- Extend: `AppTemplateTests/Features/Projects/Screens/Projects/ProjectsViewModelTests.swift`
- Extend: `AppTemplateTests/Features/Projects/Screens/ProjectDetails/ProjectDetailsViewModelTests.swift`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**

- Consumes: the main Projects Router and shared `ProjectsStore`.
- Produces: `ProjectsSheetRoute.createProject`,
  `ProjectDetailsSheetRoute.projectInfo(projectID:)`,
  `ProjectBasicsRoute.options`, and `ProjectOptionsRoute.review`.
- Produces: a temporary Router and draft owned only by `CreateProjectFlowView`.
- Produces: `ProjectBasicsViewModel.init(draft:router:)`,
  `continueToOptions()`; `ProjectOptionsViewModel.init(draft:router:)`,
  `continueToReview()`; `ProjectReviewViewModel.init(draft:store:)`,
  `save() throws -> ProjectItem`; and
  `ProjectInfoViewModel.init(projectID:store:)`.

- [ ] **Step 1: Write failing sheet and draft-flow tests**

```swift
@MainActor
@Test
func projectsOwnsCreateProjectSheetState() {
    let viewModel = ProjectsViewModel(
        store: ProjectsStore(),
        router: FlowRouter()
    )

    viewModel.openCreateProject()
    #expect(viewModel.sheet == .createProject)

    viewModel.dismissSheet()
    #expect(viewModel.sheet == nil)
}

@MainActor
@Test
func projectDetailsOwnsProjectInfoSheetState() {
    let store = ProjectsStore()
    let projectID = store.projects[0].id
    let viewModel = ProjectDetailsViewModel(
        projectID: projectID,
        store: store,
        router: FlowRouter()
    )

    viewModel.openProjectInfo()
    #expect(viewModel.sheet == .projectInfo(projectID: projectID))

    viewModel.dismissSheet()
    #expect(viewModel.sheet == nil)
}

@MainActor
@Test
func basicsValidatesBeforePushingOptions() {
    let router = FlowRouter()
    let draft = CreateProjectDraftState()
    let viewModel = ProjectBasicsViewModel(draft: draft, router: router)

    viewModel.continueToOptions()
    #expect(viewModel.validationMessage == "Project name is required.")
    #expect(router.path.isEmpty)

    draft.title = "Template"
    viewModel.continueToOptions()
    #expect(viewModel.validationMessage == nil)
    #expect(router.path.count == 1)
}

@MainActor
@Test
func optionsKeepsTheSameDraftAndPushesReview() {
    let router = FlowRouter()
    let draft = CreateProjectDraftState()
    draft.title = "Template"
    let viewModel = ProjectOptionsViewModel(draft: draft, router: router)

    #expect(viewModel.draft === draft)
    viewModel.continueToReview()
    #expect(router.path.count == 1)
}

@MainActor
@Test
func reviewSavesExactlyOneProject() throws {
    let store = ProjectsStore(projects: [])
    let draft = CreateProjectDraftState()
    draft.title = "Template"
    let viewModel = ProjectReviewViewModel(draft: draft, store: store)

    let created = try viewModel.save()

    #expect(store.projects == [created])
}

@MainActor
@Test
func editingDraftWithoutSavingLeavesStoreUnchanged() {
    let store = ProjectsStore(projects: [])
    let draft = CreateProjectDraftState()
    draft.title = "Discarded"
    draft.summary = "Close the sheet before Review saves."

    #expect(store.projects.isEmpty)
}

@MainActor
@Test
func projectInfoHandlesUnknownProject() {
    let viewModel = ProjectInfoViewModel(
        projectID: "missing",
        store: ProjectsStore(projects: [])
    )

    #expect(viewModel.project == nil)
}
```

Extend `ProjectConfigurationTests` to construct `CreateProjectFlowView` and
all four new sheet-flow screens with explicit Router, store, and draft
arguments.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ProjectBasicsViewModelTests \
  -only-testing:AppTemplateTests/ProjectOptionsViewModelTests \
  -only-testing:AppTemplateTests/ProjectReviewViewModelTests \
  -only-testing:AppTemplateTests/ProjectInfoViewModelTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: missing ViewModels and modal routes.

- [ ] **Step 3: Implement sheet routes and create flow**

Use transient sheet routes:

```swift
nonisolated
enum ProjectsSheetRoute: String, Identifiable, Hashable, Sendable {
    case createProject
    var id: Self { self }
}

nonisolated
enum ProjectDetailsSheetRoute: Identifiable, Hashable, Sendable {
    case projectInfo(projectID: ProjectItem.ID)
    var id: Self { self }
}
```

Do not add `Codable` or `NavigationRoute`.

Use step routes:

```swift
nonisolated
enum ProjectBasicsRoute: String, NavigationRoute {
    case options
}

nonisolated
enum ProjectOptionsRoute: String, NavigationRoute {
    case review
}

nonisolated
enum ProjectReviewRoute {}
```

`CreateProjectFlowView` owns:

```swift
@State private var router = FlowRouter()
@State private var draft = CreateProjectDraftState()
let store: ProjectsStore
```

It contains the only sheet-local `NavigationStack`. Basics and Options own
their outgoing destination mappings. Review calls `viewModel.save()`, then
calls `dismiss()` in the View only after save succeeds.

`ProjectsView` presents `.createProject` with `.sheet(item:)`.
`ProjectDetailsView` presents Project Info the same way. Both sheet content
Views call `dismiss()` internally and contain no NavigationStack.

Create exact empty Model and State scaffolds for all four screens.

- [ ] **Step 4: Run all Projects tests**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ProjectsStoreTests \
  -only-testing:AppTemplateTests/ProjectsViewModelTests \
  -only-testing:AppTemplateTests/ProjectDetailsViewModelTests \
  -only-testing:AppTemplateTests/ProjectBasicsViewModelTests \
  -only-testing:AppTemplateTests/ProjectOptionsViewModelTests \
  -only-testing:AppTemplateTests/ProjectReviewViewModelTests \
  -only-testing:AppTemplateTests/ProjectInfoViewModelTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: all Projects tests pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Projects \
  AppTemplateTests/Features/Projects \
  AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "feat: add projects sheets and creation flow"
```

### Task 4: Authentication and Home expansion

**Files:**

- Create all five scaffold files for `Authentication/Screens/AuthenticationHelp`
- Create all five scaffold files for `Home/Screens/GuideTopic`
- Create all five scaffold files for `Home/Screens/QuickStart`
- Modify: `AppTemplate/Features/Authentication/Screens/Authentication/Navigation/AuthenticationRoute.swift`
- Modify: `AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift`
- Modify: `AppTemplate/Features/Authentication/Screens/Authentication/ViewModel/AuthenticationViewModel.swift`
- Modify: `AppTemplate/Features/Authentication/Flow/AuthenticationFlowView.swift`
- Modify: `AppTemplate/Features/Home/Screens/Home/Navigation/HomeRoute.swift`
- Modify: `AppTemplate/Features/Home/Screens/Home/View/HomeView.swift`
- Modify: `AppTemplate/Features/Home/Screens/Home/ViewModel/HomeViewModel.swift`
- Modify: `AppTemplate/Features/Home/Screens/NavigationGuide/Model/NavigationGuideModel.swift`
- Modify: `AppTemplate/Features/Home/Screens/NavigationGuide/Navigation/NavigationGuideRoute.swift`
- Modify: `AppTemplate/Features/Home/Screens/NavigationGuide/View/NavigationGuideView.swift`
- Modify: `AppTemplate/Features/Home/Screens/NavigationGuide/ViewModel/NavigationGuideViewModel.swift`
- Create the three corresponding test files listed in the File Map.
- Modify existing Authentication, Home, and NavigationGuide ViewModel tests.

**Interfaces:**

- Produces: `AuthenticationRoute.help`,
  `NavigationGuideRoute.topic(id:)`, and `HomeSheetRoute.quickStart`.
- Consumes: existing AppRouter for authentication completion and the injected
  flow Router for push navigation.
- Produces: `AuthenticationViewModel.init(sessionStore:router:flowRouter:)`
  and `openHelp()`; `HomeViewModel.openQuickStart()` and `dismissSheet()`;
  `NavigationGuideViewModel.openTopic(id:)`; and
  `GuideTopicViewModel.init(id:)`.

- [ ] **Step 1: Write failing route and sheet tests**

```swift
@MainActor
@Test
func authenticationHelpUsesAuthenticationFlowRouter() {
    let flowRouter = FlowRouter()
    let viewModel = AuthenticationViewModel(
        sessionStore: makeSessionStore(),
        router: AppRouter(flow: .authentication),
        flowRouter: flowRouter
    )

    viewModel.openHelp()

    #expect(flowRouter.path.count == 1)
}

@MainActor
@Test
func homeOwnsQuickStartSheetState() {
    let viewModel = HomeViewModel(router: FlowRouter())
    viewModel.openQuickStart()
    #expect(viewModel.sheet == .quickStart)
    viewModel.dismissSheet()
    #expect(viewModel.sheet == nil)
}

@MainActor
@Test
func guidePushesItsOwnTopicRoute() throws {
    let router = FlowRouter()
    let viewModel = NavigationGuideViewModel(router: router)
    let item = try #require(viewModel.items.first)

    viewModel.openTopic(id: item.id)

    #expect(router.path.count == 1)
}
```

Extend `ProjectConfigurationTests` to construct Authentication Help, Guide
Topic, and Quick Start with their explicit dependencies.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AuthenticationViewModelTests \
  -only-testing:AppTemplateTests/AuthenticationHelpViewModelTests \
  -only-testing:AppTemplateTests/HomeViewModelTests \
  -only-testing:AppTemplateTests/NavigationGuideViewModelTests \
  -only-testing:AppTemplateTests/GuideTopicViewModelTests \
  -only-testing:AppTemplateTests/QuickStartViewModelTests
```

Expected: missing route cases, sheet state, and new screen types.

- [ ] **Step 3: Implement Authentication Help, Guide Topic, and Quick Start**

Add:

```swift
nonisolated
enum AuthenticationRoute: String, NavigationRoute {
    case help
}

nonisolated
enum NavigationGuideRoute: NavigationRoute {
    case topic(id: NavigationGuideItem.ID)
}

nonisolated
enum HomeSheetRoute: String, Identifiable, Hashable, Sendable {
    case quickStart
    var id: Self { self }
}
```

Move the existing guide item array from the ViewModel into the screen Model:

```swift
nonisolated
struct NavigationGuideModel: Equatable, Sendable {
    static let items = [
        NavigationGuideItem(
            id: "screen-owned-routes",
            title: "Screen-owned routes",
            systemImage: "list.bullet.rectangle"
        ),
        NavigationGuideItem(
            id: "independent-flows",
            title: "Independent flows",
            systemImage: "square.3.layers.3d"
        ),
        NavigationGuideItem(
            id: "scene-restoration",
            title: "Scene restoration",
            systemImage: "arrow.clockwise"
        )
    ]
}
```

Authentication ViewModel receives both `AppRouter` and `any IFlowRouter`.
Authentication View owns the Help destination mapping.

Navigation Guide retains the concrete Router in its View, renders items as
buttons, derives `items` from `NavigationGuideModel.items`, and owns the Guide
Topic destination mapping. Guide Topic resolves the stable ID from
`NavigationGuideModel.items` and shows an empty state if absent.

Home ViewModel owns `sheet: HomeSheetRoute?`; Home View presents Quick Start
with `.sheet(item:)`. Quick Start is read-only, has its own ViewModel, calls
`dismiss()`, and has no NavigationStack.

- [ ] **Step 4: Run affected and construction tests**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AuthenticationViewModelTests \
  -only-testing:AppTemplateTests/AuthenticationHelpViewModelTests \
  -only-testing:AppTemplateTests/HomeViewModelTests \
  -only-testing:AppTemplateTests/NavigationGuideViewModelTests \
  -only-testing:AppTemplateTests/GuideTopicViewModelTests \
  -only-testing:AppTemplateTests/QuickStartViewModelTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: all selected tests pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Authentication \
  AppTemplate/Features/Home \
  AppTemplateTests/Features/Authentication \
  AppTemplateTests/Features/Home \
  AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "feat: expand authentication and home navigation"
```

### Task 5: Browse options sheet

**Files:**

- Create: `AppTemplate/Features/Browse/State/BrowsePreferencesStore.swift`
- Create all five scaffold files for `Browse/Screens/BrowseOptions`
- Modify: `AppTemplate/Features/Browse/Flow/BrowseFlowView.swift`
- Modify: `AppTemplate/Features/Browse/Screens/Browse/Navigation/BrowseRoute.swift`
- Modify: `AppTemplate/Features/Browse/Screens/Browse/View/BrowseView.swift`
- Modify: `AppTemplate/Features/Browse/Screens/Browse/ViewModel/BrowseListViewModel.swift`
- Create: `AppTemplateTests/Features/Browse/Screens/BrowseOptions/BrowseOptionsViewModelTests.swift`
- Modify: `AppTemplateTests/Features/Browse/Screens/Browse/BrowseListViewModelTests.swift`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**

- Produces: `BrowseSortOrder`, `BrowsePreferencesStore`, and
  `BrowseSheetRoute.options`.
- Produces: `BrowseListViewModel.init(dependencies:router:preferences:)`,
  `visibleItems`, `openOptions()`, and `dismissSheet()`;
  `BrowseOptionsViewModel.init(preferences:)` and mutable `sortOrder`.
- Preserves: `BrowseListState` and all service lifecycle behavior.

- [ ] **Step 1: Write failing sorting and sheet tests**

```swift
@MainActor
@Test
func browseDerivesVisibleItemsFromSharedSortPreference() async {
    let preferences = BrowsePreferencesStore(sortOrder: .titleDescending)
    let viewModel = BrowseListViewModel(
        dependencies: makeBrowseDependencies(items: [
            BrowseItem(id: "a", title: "Alpha", summary: ""),
            BrowseItem(id: "z", title: "Zulu", summary: "")
        ]),
        router: FlowRouter(),
        preferences: preferences
    )

    await viewModel.load()

    #expect(viewModel.visibleItems.map(\.id) == ["z", "a"])
}

@MainActor
@Test
func browseOwnsOptionsSheetState() {
    let viewModel = makeBrowseListViewModel()
    viewModel.openOptions()
    #expect(viewModel.sheet == .options)
    viewModel.dismissSheet()
    #expect(viewModel.sheet == nil)
}

@MainActor
@Test
func optionsWritesThroughToSharedPreferences() {
    let preferences = BrowsePreferencesStore()
    let viewModel = BrowseOptionsViewModel(preferences: preferences)

    viewModel.sortOrder = .titleDescending

    #expect(preferences.sortOrder == .titleDescending)
}
```

Extend `ProjectConfigurationTests` to construct `BrowseOptionsView` with the
shared preferences store.

- [ ] **Step 2: Run Browse tests and verify RED**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/BrowseListViewModelTests \
  -only-testing:AppTemplateTests/BrowseOptionsViewModelTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: missing preference types and updated ViewModel initializer.

- [ ] **Step 3: Implement shared options state and sheet**

```swift
nonisolated
enum BrowseSortOrder: String, CaseIterable, Identifiable, Sendable {
    case titleAscending
    case titleDescending
    var id: Self { self }
}

@MainActor
@Observable
final class BrowsePreferencesStore {
    var sortOrder: BrowseSortOrder
    init(sortOrder: BrowseSortOrder = .titleAscending) {
        self.sortOrder = sortOrder
    }
}

nonisolated
enum BrowseSheetRoute: String, Identifiable, Hashable, Sendable {
    case options
    var id: Self { self }
}
```

Browse Flow owns the preferences store. Browse List ViewModel exposes
`visibleItems` derived from loaded content and `preferences.sortOrder`, plus
sheet open/dismiss methods. Browse Options ViewModel proxies the shared store.
The sheet uses a Picker, applies changes live, dismisses itself, and contains
no NavigationStack.

- [ ] **Step 4: Run full Browse tests**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/BrowseListViewModelTests \
  -only-testing:AppTemplateTests/BrowseDetailViewModelTests \
  -only-testing:AppTemplateTests/BrowseOptionsViewModelTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: loading, cancellation, retry, empty, failure, sorting, and sheet
tests pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Browse \
  AppTemplateTests/Features/Browse \
  AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "feat: add browse options sheet"
```

### Task 6: Browse related-content push hierarchy

**Files:**

- Create all five scaffold files for `Browse/Screens/RelatedItems`
- Create all five scaffold files for `Browse/Screens/RelatedItemDetail`
- Modify: `AppTemplate/Features/Browse/Screens/Browse/View/BrowseView.swift`
- Modify: `AppTemplate/Features/Browse/Screens/BrowseDetail/Navigation/BrowseDetailRoute.swift`
- Modify: `AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift`
- Modify: `AppTemplate/Features/Browse/Screens/BrowseDetail/ViewModel/BrowseDetailViewModel.swift`
- Create the two corresponding test files listed in the File Map.
- Modify: `AppTemplateTests/Features/Browse/Screens/BrowseDetail/BrowseDetailViewModelTests.swift`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**

- Produces: `BrowseDetailRoute.relatedItems(itemID:)` and
  `RelatedItemsRoute.item(id:)`.
- Consumes: the existing `BrowseDependencies` service and same Browse Router.
- Produces: `BrowseDetailViewModel.init(id:dependencies:router:)` and
  `openRelatedItems()`; `RelatedItemsViewModel.init(sourceItemID:dependencies:router:)`,
  `load() async`, `retry()`, `cancel()`, and `openItem(id:)`; and
  `RelatedItemDetailViewModel.init(id:dependencies:)`, `load() async`,
  `retry()`, and `cancel()`.

- [ ] **Step 1: Write failing related-route tests**

```swift
@MainActor
@Test
func detailAndRelatedItemsPushTheirOwnRoutes() async {
    let source = BrowseItem(id: "source", title: "Source", summary: "")
    let other = BrowseItem(id: "other", title: "Other", summary: "")
    let router = FlowRouter()
    let dependencies = BrowseDependencies(
        service: BrowseService(items: [source, other])
    )
    let details = BrowseDetailViewModel(
        id: source.id,
        dependencies: dependencies,
        router: router
    )

    details.openRelatedItems()
    #expect(router.path.count == 1)

    router.popToRoot()
    let related = RelatedItemsViewModel(
        sourceItemID: source.id,
        dependencies: dependencies,
        router: router
    )
    await related.load()
    #expect(related.state == .content([other]))

    related.openItem(id: other.id)
    #expect(router.path.count == 1)
}

@MainActor
@Test
func missingRelatedItemProducesEmptyState() async {
    let viewModel = RelatedItemDetailViewModel(
        id: "missing",
        dependencies: BrowseDependencies(
            service: BrowseService(items: [])
        )
    )

    await viewModel.load()

    #expect(viewModel.state == .empty)
}
```

In `RelatedItemsViewModelTests`, also mirror the existing Browse List
replacement-load, explicit-cancel, retry-cancel, and service-failure tests.
Assert stale/cancelled responses do not replace `.idle` or the latest content.
In `RelatedItemDetailViewModelTests`, mirror the existing Browse Detail
replacement-load, explicit-cancel, retry-cancel, and service-failure tests.
Extend `ProjectConfigurationTests` to construct Related Items and Related
Item Detail using explicit Browse dependencies and the shared Browse Router.

- [ ] **Step 2: Run focused Browse detail/related tests and verify RED**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/BrowseDetailViewModelTests \
  -only-testing:AppTemplateTests/RelatedItemsViewModelTests \
  -only-testing:AppTemplateTests/RelatedItemDetailViewModelTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: missing route cases, Router injection, and related screen types.

- [ ] **Step 3: Implement the hierarchy**

Use:

```swift
nonisolated
enum BrowseDetailRoute: NavigationRoute {
    case relatedItems(itemID: BrowseItem.ID)
}

nonisolated
enum RelatedItemsRoute: NavigationRoute {
    case item(id: BrowseItem.ID)
}

nonisolated
enum RelatedItemDetailRoute {}
```

Use `RelatedItemsState = LoadableState<[BrowseItem], BrowseFailure>` and
`RelatedItemDetailState = LoadableState<BrowseItem, BrowseFailure>`.
Pass the concrete Browse Router from Browse View to Browse Detail. Browse
Detail ViewModel receives `any IFlowRouter` and owns `openRelatedItems()`.
Related Items loads through `IBrowseService`, excludes `sourceItemID`, retains
the same cancellation/error rules, and owns its item destination mapping.
Related Item Detail loads one item by ID and renders loading/content/empty/error
states.

- [ ] **Step 4: Run every Browse test**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/BrowseListViewModelTests \
  -only-testing:AppTemplateTests/BrowseDetailViewModelTests \
  -only-testing:AppTemplateTests/BrowseOptionsViewModelTests \
  -only-testing:AppTemplateTests/RelatedItemsViewModelTests \
  -only-testing:AppTemplateTests/RelatedItemDetailViewModelTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: all existing and new Browse tests pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Browse \
  AppTemplateTests/Features/Browse \
  AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "feat: add browse related navigation"
```

### Task 7: Settings push and session sheet

**Files:**

- Create all five scaffold files for `Settings/Screens/PlatformDetails`
- Create all five scaffold files for `Settings/Screens/SessionInfo`
- Modify: `AppTemplate/Features/Settings/Screens/Settings/Navigation/SettingsRoute.swift`
- Modify: `AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift`
- Modify: `AppTemplate/Features/Settings/Screens/Settings/ViewModel/SettingsViewModel.swift`
- Modify: `AppTemplate/Features/Settings/Screens/About/Navigation/AboutRoute.swift`
- Modify: `AppTemplate/Features/Settings/Screens/About/View/AboutView.swift`
- Modify: `AppTemplate/Features/Settings/Screens/About/ViewModel/AboutViewModel.swift`
- Create the two corresponding test files listed in the File Map.
- Modify existing Settings and About ViewModel tests.

**Interfaces:**

- Produces: `AboutRoute.platform(name:)` and
  `SettingsSheetRoute.sessionInfo`.
- Consumes: the same Settings Router and existing `SessionStore`.
- Produces: `AboutViewModel.init(router:)` and `openPlatform(name:)`;
  `SettingsViewModel.openSessionInfo()` and `dismissSheet()`; and
  `SessionInfoViewModel.init(sessionStore:)`.

- [ ] **Step 1: Write failing push and sheet tests**

```swift
@MainActor
@Test
func aboutPushesPlatformDetails() {
    let router = FlowRouter()
    let viewModel = AboutViewModel(router: router)
    viewModel.openPlatform(name: "iOS 26")
    #expect(router.path.count == 1)
}

@MainActor
@Test
func settingsOwnsSessionInfoSheet() {
    let viewModel = makeSettingsViewModel()
    viewModel.openSessionInfo()
    #expect(viewModel.sheet == .sessionInfo)
    viewModel.dismissSheet()
    #expect(viewModel.sheet == nil)
}
```

Extend `ProjectConfigurationTests` to construct Platform Details and Session
Info with explicit Router and SessionStore arguments.

- [ ] **Step 2: Run Settings tests and verify RED**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/SettingsViewModelTests \
  -only-testing:AppTemplateTests/AboutViewModelTests \
  -only-testing:AppTemplateTests/PlatformDetailsViewModelTests \
  -only-testing:AppTemplateTests/SessionInfoViewModelTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: missing Router injection, routes, sheet state, and screens.

- [ ] **Step 3: Implement Platform Details and Session Info**

```swift
nonisolated
enum AboutRoute: NavigationRoute {
    case platform(name: String)
}

nonisolated
enum SettingsSheetRoute: String, Identifiable, Hashable, Sendable {
    case sessionInfo
    var id: Self { self }
}
```

Settings View passes the concrete Router to About and presents Session Info
with `.sheet(item:)`. About owns its platform destination mapping. Session Info
ViewModel receives `SessionStore`, exposes phase-specific display values, and
its View dismisses itself without a NavigationStack.

- [ ] **Step 4: Run all Settings and construction tests**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/SettingsViewModelTests \
  -only-testing:AppTemplateTests/AboutViewModelTests \
  -only-testing:AppTemplateTests/PlatformDetailsViewModelTests \
  -only-testing:AppTemplateTests/SessionInfoViewModelTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: all selected tests pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Settings \
  AppTemplateTests/Features/Settings \
  AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "feat: expand settings navigation and sheets"
```

### Task 8: Snapshot schema 3 and schema-2 migration

**Files:**

- Modify: `AppTemplate/App/Navigation/Snapshots/NavigationSnapshot.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- Modify: `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`
- Modify: `AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift`
- Modify: `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`

**Interfaces:**

- Produces: schema 3 with `projectsPath`.
- Produces: `NavigationRestorationResult.migrated(from:)`.
- Produces: `NavigationSnapshot.init(selectedSection:homePath:browsePath:projectsPath:settingsPath:)`.
- Preserves: affected-flow-only recovery and schema-1/future-schema rejection.

- [ ] **Step 1: Write failing schema-3 and migration tests**

Add tests proving:

```swift
source.projects.push(ProjectsRoute.project(id: "project-1"))
source.projects.push(
    ProjectDetailsRoute.task(projectID: "project-1", taskID: "task-1")
)
let data = try NavigationSnapshotCodec.encode(source.snapshot)
let restored = AppRouter()

#expect(restored.restore(from: data) == .restored)
#expect(restored.projects.path.count == 2)
```

Create a real schema-2 fixture with Home/Browse/Settings
`FlowPathSnapshot` fields and assert:

```swift
#expect(restored.restore(from: legacyData) == .migrated(from: 2))
#expect(restored.home.path.count == 1)
#expect(restored.projects.path.isEmpty)
```

Add a corrupt Projects path test that preserves all other valid histories.
Encode a snapshot and assert its JSON contains `projectsPath` but none of the
transient sheet-route names (`quickStart`, `options`, `sessionInfo`,
`createProject`, or `projectInfo`) and no create-draft field names.

In `AppSceneNavigationLifecycleTests`, create two AppRouters with different
Projects paths, encode and restore each scene independently, then assert each
restored Router keeps only its own project IDs/path count. Add a migration
lifecycle test asserting a schema-2 payload returns schema-3 replacement data
whose header is `3`.

- [ ] **Step 2: Run snapshot/lifecycle tests and verify RED**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/NavigationSnapshotTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests \
  -only-testing:AppTemplateTests/AppRouterTests
```

Expected: schema is still 2, Projects is absent from the snapshot, and no
migration result exists.

- [ ] **Step 3: Implement schema 3 and migration**

Set `currentSchemaVersion = 3`, add `projectsPath`, and include it in equality
and encoding.

Add a private schema-2 payload:

```swift
private
nonisolated
struct NavigationSnapshotV2: Decodable {
    let schemaVersion: Int
    let selectedSection: AppSection
    let homePath: FlowPathSnapshot
    let browsePath: FlowPathSnapshot
    let settingsPath: FlowPathSnapshot
}
```

Add:

```swift
case migrated(from: Int)
```

to `NavigationRestorationResult`.

AppRouter restoration switches on the decoded header:

- schema 3: decode all four paths and recover each independently;
- schema 2: decode the legacy payload, restore its three paths, empty Projects,
  and return `.migrated(from: 2)`;
- every other version: reset as unsupported.

Lifecycle treats `.migrated` like `.recovered` and returns the current snapshot
for immediate SceneStorage replacement.

- [ ] **Step 4: Run snapshot, lifecycle, and AppRouter tests**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/NavigationSnapshotTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests \
  -only-testing:AppTemplateTests/AppRouterTests
```

Expected: all pass, including existing schema-1 and corrupt-data coverage.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Navigation/Snapshots/NavigationSnapshot.swift \
  AppTemplate/App/Navigation/Routing/AppRouter.swift \
  AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift \
  AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift \
  AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift
git commit -m "feat: migrate navigation snapshots to schema three"
```

### Task 9: Projects deep links and adoption documentation

**Files:**

- Modify: `AppTemplate/App/Navigation/Routing/NavigationIntent.swift`
- Modify: `AppTemplate/App/Navigation/DeepLinks/DeepLinkParser.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- Modify: `AppTemplateTests/App/Navigation/DeepLinks/DeepLinkParserTests.swift`
- Modify: `AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift`
- Modify: `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
- Modify: `README.md`

**Interfaces:**

- Produces: `NavigationIntent.project(id:)` and
  `NavigationIntent.projectTask(projectID:taskID:)`.
- Produces canonical Projects paths from three documented URL forms.
- Preserves: `DeepLinkParser.parse(_:) -> Result<NavigationIntent, DeepLinkError>`
  and `AppRouter.handle(_:) -> NavigationOutcome`.

- [ ] **Step 1: Write failing parser and AppRouter tests**

Add parser cases:

```swift
("apptemplate://projects", .selectSection(.projects))
("apptemplate://projects/project/project-1", .project(id: "project-1"))
(
    "apptemplate://projects/project/project-1/task/task-1",
    .projectTask(projectID: "project-1", taskID: "task-1")
)
```

AppRouter tests assert project intent creates one Projects path element and
task intent creates two, resets only Projects, selects Projects, and preserves
Home/Browse/Settings histories.

Add parser failures for:

```swift
[
    "apptemplate://projects/project",
    "apptemplate://projects/project/",
    "apptemplate://projects/project/project-1/task",
    "apptemplate://projects/project/project-1/task/",
    "apptemplate://projects/project/project-1/task/task-1/extra"
]
```

- [ ] **Step 2: Run parser, Router, and lifecycle tests and verify RED**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/DeepLinkParserTests \
  -only-testing:AppTemplateTests/AppRouterTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests
```

Expected: missing intents and unsupported Projects URL parsing.

- [ ] **Step 3: Implement canonical deep-link handling**

Add:

```swift
case project(id: ProjectItem.ID)
case projectTask(
    projectID: ProjectItem.ID,
    taskID: ProjectTaskItem.ID
)
```

Parser accepts only the three approved Projects shapes and continues rejecting
empty segments or extra path components. AppRouter selects Projects, clears
only `projects.path`, and pushes the exact screen-owned route sequence.

Update README with:

- the Projects feature/tab;
- simple screen-owned sheet ownership;
- independent modal-flow ownership;
- the three Projects deep links;
- schema-3 migration from schema 2.

- [ ] **Step 4: Run all app navigation tests**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/DeepLinkParserTests \
  -only-testing:AppTemplateTests/AppRouterTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests \
  -only-testing:AppTemplateTests/NavigationSnapshotTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Expected: all selected tests pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Navigation \
  AppTemplateTests/App/Navigation \
  README.md
git commit -m "feat: add projects deep links"
```

### Task 10: Structural audit and cross-platform verification

**Files:**

- Modify only files required by failures found in this task.

**Interfaces:**

- Consumes: all prior tasks.
- Produces: a reviewed, buildable, cross-platform final result.

- [ ] **Step 1: Run structural ownership guards**

```bash
test "$(rg -l 'NavigationStack' AppTemplate/Features | sort | wc -l | tr -d ' ')" -eq 6
rg -n 'NavigationStack' AppTemplate/Features
rg -n '\\.navigationDestination' AppTemplate/Features
rg -n '\\.sheet\\(item:' AppTemplate/Features
! rg -n 'NavigationLink|AnyView|fatalError|HomeRouter|BrowseRouter|SettingsRouter|ProjectsRouter' AppTemplate
! rg -n 'onSave:|onCancel:|onNavigate:|navigateTo' AppTemplate/Features
```

Expected NavigationStacks:

- Authentication Flow;
- Home Flow;
- Browse Flow;
- Projects Flow;
- Settings Flow;
- Create Project Flow.

Every destination and sheet mapping must appear on its initiating screen.

- [ ] **Step 2: Run whitespace and repository-scope checks**

```bash
git diff --check
git status --short
git diff --stat f5844fb..HEAD
```

Expected: no whitespace errors and no unrelated files in the implementation
range.

- [ ] **Step 3: Run the complete macOS test suite**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-expanded-navigation-macos
```

Expected: exit 0, zero failed tests.

- [ ] **Step 4: Run the complete iPhone test suite**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/AppTemplate-expanded-navigation-iphone
```

Expected: exit 0, zero failed tests.

- [ ] **Step 5: Run the complete iPad test suite**

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  -derivedDataPath /tmp/AppTemplate-expanded-navigation-ipad
```

Expected: exit 0, zero failed tests.

- [ ] **Step 6: Run Simulator UI smoke checks**

Using XcodeBuildMCP, verify:

1. Authentication Help opens and native back returns.
2. Home Guide Topic opens; Quick Start sheet opens and dismisses.
3. Browse Options changes order.
4. Browse Detail → Related Items → Related Item Detail works.
5. Settings About → Platform Details works; Session Info opens and dismisses.
6. Projects → Project Details → Task Details works.
7. Create Project advances Basics → Options → Review, saves, dismisses, and
   exposes the created project in Projects.
8. Tab switching preserves the Home, Browse, and Projects paths.
9. Native back and edge-swipe update the bound path.

- [ ] **Step 7: Request final code review**

Review the complete implementation range against:

- `docs/superpowers/specs/2026-07-29-expanded-navigation-and-sheets-design.md`;
- this plan;
- the Global Constraints.

Fix every Critical and Important finding, rerun the affected red/green test,
then repeat Steps 1–6.

- [ ] **Step 8: Commit verification-only fixes if any**

If review changes source, rerun `git status --short`, explicitly enumerate
only those reviewed source/test paths in `git add`, then commit:

```bash
git commit -m "fix: address expanded navigation review"
```

If review produces no source changes, do not stage files or create an empty
commit.
