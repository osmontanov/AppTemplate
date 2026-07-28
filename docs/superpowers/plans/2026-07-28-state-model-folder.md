# State Model Folder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable typed loading state and centralize shared Browse and Session state models under `App/Models/State`.

**Architecture:** `LoadableState<Content, Failure>` represents the common idle/loading/content/empty/failure lifecycle without UI copy or feature behavior. Browse keeps readable feature-specific type aliases, while Session retains its dedicated business-state enum. Mutable stores and view models remain main-actor isolated.

**Tech Stack:** Swift, Swift Concurrency, SwiftUI, Observation, Swift Testing, Xcode 26, synchronized filesystem groups.

## Global Constraints

- Support iOS 26, iPadOS 26, and macOS 26.
- Add no external dependencies.
- Keep `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- Keep plain state values `nonisolated`, `Equatable`, and `Sendable`.
- Name the generic type `LoadableState`, not `State`, to avoid confusion with SwiftUI `@State`.
- Keep `SessionPhase` as a dedicated business-state enum.
- Keep `NavigationRestorationFailure` in `App/Navigation/Snapshots`.
- Keep UI strings and feature behavior out of `LoadableState`.
- Use the Xcode project's synchronized filesystem groups; do not manually add file references to `project.pbxproj`.

## File Structure

Create:

- `AppTemplate/App/Models/State/LoadableState.swift`: generic loading lifecycle.
- `AppTemplate/App/Models/State/BrowseState.swift`: Browse failure and readable state aliases.
- `AppTemplate/App/Models/State/SessionState.swift`: Session phase and failure values.
- `AppTemplateTests/App/Models/State/LoadableStateTests.swift`: generic state contract.

Modify:

- `AppTemplate/App/Services/Session/SessionStore.swift`: remove state declarations that move to `SessionState.swift`.
- `AppTemplate/Features/Browse/Screens/Browse/ViewModel/BrowseListViewModel.swift`: publish `.empty` for an empty collection.
- `AppTemplate/Features/Browse/Screens/BrowseDetail/ViewModel/BrowseDetailViewModel.swift`: publish `.empty` for a missing item.
- `AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift`: render the list empty state.
- `AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift`: render `.empty` as the existing unavailable-item UI.
- `AppTemplateTests/Features/Browse/Screens/Browse/BrowseListViewModelTests.swift`: cover an empty list.
- `AppTemplateTests/Features/Browse/Screens/BrowseDetail/BrowseDetailViewModelTests.swift`: expect `.empty` for a missing item.

Delete after migration:

- `AppTemplate/App/Models/Domain/BrowseStoreState.swift`

---

### Task 1: Add the Generic Loadable State

**Files:**

- Create: `AppTemplateTests/App/Models/State/LoadableStateTests.swift`
- Create: `AppTemplate/App/Models/State/LoadableState.swift`

**Interfaces:**

- Consumes: `BrowseItem` and `BrowseFailure` as existing `Equatable & Sendable` test specializations.
- Produces: `nonisolated enum LoadableState<Content, Failure>: Equatable, Sendable`, where both generic arguments require `Equatable & Sendable`.

- [ ] **Step 1: Write the failing generic-state test**

Create `AppTemplateTests/App/Models/State/LoadableStateTests.swift`:

```swift
import Testing
@testable import AppTemplate

struct LoadableStateTests {
    @Test
    func representsTheCompleteLoadingLifecycle() {
        let item = BrowseItem(
            id: "one",
            title: "One",
            summary: "First"
        )
        typealias State = LoadableState<[BrowseItem], BrowseFailure>

        #expect(State.idle == .idle)
        #expect(State.loading == .loading)
        #expect(State.content([item]) == .content([item]))
        #expect(State.empty == .empty)
        #expect(State.failed(.load) == .failed(.load))
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/LoadableStateTests
```

Expected: compilation fails because `LoadableState` does not exist.

- [ ] **Step 3: Add the minimal generic implementation**

Create `AppTemplate/App/Models/State/LoadableState.swift`:

```swift
nonisolated enum LoadableState<
    Content: Equatable & Sendable,
    Failure: Equatable & Sendable
>: Equatable, Sendable {
    case idle
    case loading
    case content(Content)
    case empty
    case failed(Failure)
}
```

Do not add computed properties, transformations, UI strings, or default
failure types.

- [ ] **Step 4: Run the test and verify GREEN**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/LoadableStateTests
```

Expected: exit 0.

- [ ] **Step 5: Commit the generic state**

```bash
git add \
  AppTemplate/App/Models/State/LoadableState.swift \
  AppTemplateTests/App/Models/State/LoadableStateTests.swift
git commit -m "feat: add generic loadable state"
```

---

### Task 2: Migrate Browse and Session State Models

**Files:**

- Create: `AppTemplate/App/Models/State/BrowseState.swift`
- Create: `AppTemplate/App/Models/State/SessionState.swift`
- Modify: `AppTemplate/App/Services/Session/SessionStore.swift:1-24`
- Modify: `AppTemplate/Features/Browse/Screens/Browse/ViewModel/BrowseListViewModel.swift:66-72`
- Modify: `AppTemplate/Features/Browse/Screens/BrowseDetail/ViewModel/BrowseDetailViewModel.swift:70-77`
- Modify: `AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift:22-49`
- Modify: `AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift:21-43`
- Modify: `AppTemplateTests/Features/Browse/Screens/Browse/BrowseListViewModelTests.swift`
- Modify: `AppTemplateTests/Features/Browse/Screens/BrowseDetail/BrowseDetailViewModelTests.swift:20-34`
- Delete: `AppTemplate/App/Models/Domain/BrowseStoreState.swift`

**Interfaces:**

- Consumes: `LoadableState<Content, Failure>` from Task 1.
- Produces: `BrowseListState`, `BrowseDetailState`, `BrowseFailure`, `SessionPhase`, and `SessionFailure` at their existing module access level.
- Behavior: empty list and missing detail both publish `.empty`; feature views choose their own empty-state copy.

- [ ] **Step 1: Add the failing empty-list expectation**

Add this test to `BrowseListViewModelTests` after
`listLoadsServiceItems()`:

```swift
@Test
func emptyListProducesEmptyState() async {
    let viewModel = BrowseListViewModel(
        dependencies: BrowseDependencies(
            service: BrowseService(items: [])
        )
    )

    await viewModel.load()

    #expect(viewModel.state == .empty)
}
```

Change the existing detail test to:

```swift
@Test
func missingDetailProducesEmptyState() async {
    let viewModel = BrowseDetailViewModel(
        id: "missing",
        dependencies: BrowseDependencies(
            service: BrowseService(items: [])
        )
    )

    await viewModel.load()

    #expect(viewModel.state == .empty)
}
```

- [ ] **Step 2: Run the Browse suites and verify RED**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/BrowseListViewModelTests \
  -only-testing:AppTemplateTests/BrowseDetailViewModelTests
```

Expected: compilation fails because the existing concrete Browse state enums
do not define `.empty`.

- [ ] **Step 3: Create the Browse state aliases**

Create `AppTemplate/App/Models/State/BrowseState.swift`:

```swift
nonisolated enum BrowseFailure: Equatable, Sendable {
    case load

    var message: String {
        "Browse content could not be loaded."
    }
}

typealias BrowseListState = LoadableState<
    [BrowseItem],
    BrowseFailure
>

typealias BrowseDetailState = LoadableState<
    BrowseItem,
    BrowseFailure
>
```

Do not apply `nonisolated` to either type alias; Swift does not allow that
modifier on a type-alias declaration. The aliased `LoadableState` type is
already nonisolated.

Delete `AppTemplate/App/Models/Domain/BrowseStoreState.swift` after the new
file contains the failure declaration and both aliases.

- [ ] **Step 4: Extract the Session state values**

Create `AppTemplate/App/Models/State/SessionState.swift`:

```swift
nonisolated enum SessionPhase: Equatable, Sendable {
    case idle
    case loading
    case unauthenticated
    case authenticated(UserSession)
}

nonisolated enum SessionFailure: Equatable, Sendable {
    case restoration
    case signIn
    case signOut

    var message: String {
        switch self {
        case .restoration:
            "The previous session could not be restored."
        case .signIn:
            "Sign in could not be completed."
        case .signOut:
            "Sign out could not be completed."
        }
    }
}
```

Remove only the `SessionPhase` and `SessionFailure` declarations from
`SessionStore.swift`. Keep `import Observation`, `SessionStore`,
`ActiveRestoration`, and `RestorationOutcome` in place.

- [ ] **Step 5: Publish the generic empty state from Browse view models**

In `BrowseListViewModel.finish(_:version:)`, replace the final assignment
with:

```swift
state = items.isEmpty ? .empty : .content(items)
```

In `BrowseDetailViewModel.finish(_:version:)`, replace the final assignment
with:

```swift
state = item.map(BrowseDetailState.content) ?? .empty
```

Do not change cancellation, stale-response rejection, retry, or failure
behavior.

- [ ] **Step 6: Render `.empty` in both Browse views**

In `BrowseNavigationView`, add this switch case between `.loading` and
`.content`:

```swift
case .empty:
    ContentUnavailableView(
        "No Browse Items",
        systemImage: "tray",
        description: Text("There are no Browse items yet.")
    )
```

In `BrowseDetailView`, replace `case .notFound:` with:

```swift
case .empty:
```

Keep the existing `"Item Unavailable"` content, icon, and description
unchanged.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/LoadableStateTests \
  -only-testing:AppTemplateTests/BrowseListViewModelTests \
  -only-testing:AppTemplateTests/BrowseDetailViewModelTests \
  -only-testing:AppTemplateTests/SessionStoreTests \
  -only-testing:AppTemplateTests/SettingsViewModelTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests
```

Expected: exit 0.

- [ ] **Step 8: Verify the file ownership guard**

Run:

```bash
test -f AppTemplate/App/Models/State/LoadableState.swift
test -f AppTemplate/App/Models/State/BrowseState.swift
test -f AppTemplate/App/Models/State/SessionState.swift
test ! -e AppTemplate/App/Models/Domain/BrowseStoreState.swift

test "$(rg -l '^nonisolated enum BrowseFailure' AppTemplate --glob '*.swift' | wc -l | tr -d ' ')" = "1"
test "$(rg -l '^nonisolated enum SessionPhase' AppTemplate --glob '*.swift' | wc -l | tr -d ' ')" = "1"
test "$(rg -l '^nonisolated enum SessionFailure' AppTemplate --glob '*.swift' | wc -l | tr -d ' ')" = "1"

if rg -n 'case notFound|BrowseDetailState\\.notFound' \
  AppTemplate AppTemplateTests --glob '*.swift'; then
  exit 1
fi

git diff --check
```

Expected: every command exits 0 and the `rg` guard prints no matches.

- [ ] **Step 9: Commit the state migration**

```bash
git add \
  AppTemplate/App/Models \
  AppTemplate/App/Services/Session/SessionStore.swift \
  AppTemplate/Features/Browse \
  AppTemplateTests/Features/Browse
git commit -m "refactor: centralize shared state models"
```

---

### Task 3: Verify Every Supported Platform

**Files:**

- Verify only; no production or test files should change.

**Interfaces:**

- Consumes: the complete Task 1 and Task 2 implementation.
- Produces: fresh macOS and iOS test evidence plus Release build evidence.

- [ ] **Step 1: Run the complete macOS test suite**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS'
```

Expected: exit 0.

- [ ] **Step 2: Resolve the installed iOS 26 simulator**

```bash
xcodebuild -showdestinations \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate
```

Select an available iPhone simulator running iOS 26. The current verified
destination is `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5`.

- [ ] **Step 3: Run the complete iOS 26 test suite**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: exit 0. Because the same iOS application target supports both
iPhone and iPad, this validates shared iOS/iPadOS code; no device-specific
state implementation exists.

- [ ] **Step 4: Run macOS and iOS Simulator Release builds**

```bash
xcodebuild build -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Release \
  -destination 'generic/platform=macOS'

xcodebuild build -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator'
```

Expected: both commands exit 0.

- [ ] **Step 5: Confirm the worktree is clean**

```bash
git status --short
```

Expected: no output.
