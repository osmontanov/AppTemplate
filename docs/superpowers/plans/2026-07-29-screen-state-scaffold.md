# Screen State And Model Scaffold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every screen both screen-owned `State` and `Model` scaffolds while preserving presentation `Item` ownership.

**Architecture:** Screen render state lives under each screen's `State` folder. Screen presentation/data mapping scaffolds live under each screen's `Model` folder. Feature-scoped shared state lives under `Features/<Feature>/State`. Generic reusable state remains in `App/Models/State`.

**Tech Stack:** Swift, SwiftUI, Observation, Testing, Xcode synchronized groups, iOS 26, iPadOS 26, macOS 26.

## Global Constraints

- Do not move `NavigationGuideItem` out of `NavigationGuide/Model`.
- Do not move `BrowseItem` or `UserSession` out of `App/Models/Domain`.
- Keep state scaffolds inert and compile-safe.
- Keep model scaffolds inert and compile-safe even when unused.
- Keep `LoadableState` and `SessionState` in `App/Models/State`.
- Verify with macOS and iOS simulator test runs.

---

### Task 1: Screen State And Model Scaffolds

**Files:**
- Create: `AppTemplate/Features/Authentication/Screens/Authentication/State/AuthenticationState.swift`
- Create: `AppTemplate/Features/Authentication/Screens/Authentication/Model/AuthenticationModel.swift`
- Create: `AppTemplate/Features/Browse/Screens/Browse/Model/BrowseModel.swift`
- Create: `AppTemplate/Features/Browse/Screens/BrowseDetail/Model/BrowseDetailModel.swift`
- Create: `AppTemplate/Features/Home/Screens/Home/State/HomeState.swift`
- Create: `AppTemplate/Features/Home/Screens/Home/Model/HomeModel.swift`
- Create: `AppTemplate/Features/Home/Screens/HomeDetails/State/HomeDetailsState.swift`
- Create: `AppTemplate/Features/Home/Screens/HomeDetails/Model/HomeDetailsModel.swift`
- Create: `AppTemplate/Features/Home/Screens/NavigationGuide/State/NavigationGuideState.swift`
- Create: `AppTemplate/Features/Home/Screens/NavigationGuide/Model/NavigationGuideModel.swift`
- Create: `AppTemplate/Features/Settings/Screens/About/State/AboutState.swift`
- Create: `AppTemplate/Features/Settings/Screens/About/Model/AboutModel.swift`
- Create: `AppTemplate/Features/Settings/Screens/Settings/State/SettingsState.swift`
- Create: `AppTemplate/Features/Settings/Screens/Settings/Model/SettingsModel.swift`

**Interfaces:**
- Produces: empty `nonisolated struct <Screen>State: Equatable, Sendable`.
- Produces: empty `nonisolated struct <Screen>Model: Equatable, Sendable`.

- [ ] **Step 1: Add empty screen state structs**

Use this shape for each inert scaffold:

```swift
nonisolated struct HomeState:
    Equatable,
    Sendable {
}
```

- [ ] **Step 2: Add empty screen model structs**

Use this shape for each inert scaffold:

```swift
nonisolated struct HomeModel:
    Equatable,
    Sendable {
}
```

Keep real presentation models such as `NavigationGuideItem` in `Model`.

- [ ] **Step 3: Verify files**

Run:

```bash
find AppTemplate/Features -path '*/Screens/*/State/*.swift' -type f | sort
find AppTemplate/Features -path '*/Screens/*/Model/*.swift' -type f | sort
```

Expected: all screens have `State` and `Model`; `NavigationGuideItem.swift`
remains under the NavigationGuide screen `Model` folder.

### Task 2: Browse State Ownership

**Files:**
- Delete: `AppTemplate/App/Models/State/BrowseState.swift`
- Create: `AppTemplate/Features/Browse/State/BrowseFailure.swift`
- Create: `AppTemplate/Features/Browse/Screens/Browse/State/BrowseListState.swift`
- Create: `AppTemplate/Features/Browse/Screens/BrowseDetail/State/BrowseDetailState.swift`
- Modify: `AppTemplateTests/App/Models/State/LoadableStateTests.swift`

**Interfaces:**
- Produces: `BrowseFailure`, `BrowseListState`, and `BrowseDetailState`.
- Preserves: `BrowseListViewModel.state` and `BrowseDetailViewModel.state` behavior.

- [ ] **Step 1: Move Browse failure to feature state**

Create:

```swift
nonisolated enum BrowseFailure: Equatable, Sendable {
    case load

    var message: String {
        "Browse content could not be loaded."
    }
}
```

- [ ] **Step 2: Move Browse screen state aliases**

Create `BrowseListState`:

```swift
typealias BrowseListState = LoadableState<
    [BrowseItem],
    BrowseFailure
>
```

Create `BrowseDetailState`:

```swift
typealias BrowseDetailState = LoadableState<
    BrowseItem,
    BrowseFailure
>
```

- [ ] **Step 3: Decouple generic state tests from Browse**

Use a test-local failure enum in `LoadableStateTests`.

- [ ] **Step 4: Verify references**

Run:

```bash
rg -n 'BrowseFailure|BrowseListState|BrowseDetailState' AppTemplate AppTemplateTests
```

Expected: Browse screen ViewModels consume the moved aliases; generic state
tests use their own local failure type.

### Task 3: Documentation And Verification

**Files:**
- Modify: `README.md`

**Interfaces:**
- Produces: documented ownership rules for app, feature, screen state, and
  presentation models.

- [ ] **Step 1: Update README ownership rules**

Document:

```text
App/Models/State = shared app state and generic reusable state containers
Features/<Feature>/State = feature-scoped state shared by multiple screens
Screens/<Screen>/State = render state for one screen ViewModel
Screens/<Screen>/Model = screen model scaffold and presentation models such as rows/cards/items
```

- [ ] **Step 2: Run macOS tests**

Run:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS' -derivedDataPath /tmp/AppTemplate-screen-state-scaffold-macos
```

Expected: exit code 0.

- [ ] **Step 3: Run iOS simulator tests**

Run:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/AppTemplate-screen-state-scaffold-ios
```

Expected: exit code 0.
