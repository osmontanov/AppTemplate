# Purpose-Driven Folder Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the boilerplate into a predictable purpose-driven, feature-first folder structure with identical compile-safe extension points for Authentication, Home, Browse, and Settings.

**Architecture:** `App` owns entry, composition, navigation infrastructure, and app-wide services. Each feature owns the same Screens, ViewModels, Navigation, Dependencies, Domain, Data, Services, and UI scaffold; existing runtime types occupy their real roles and unused roles receive inert compile-safe extension points. Tests mirror production ownership, while `Resources` owns the asset catalog and Info.plist.

**Tech Stack:** Swift 5 language mode with Xcode 26 approachable concurrency, SwiftUI, Observation, Swift Concurrency, Swift Testing, file-system-synchronized Xcode groups, and XcodeBuild.

## Global Constraints

- Deployment targets remain exactly iOS 26.0, iPadOS 26.0, and macOS 26.0.
- Add no third-party dependencies.
- Preserve all existing runtime type names and behavior.
- Preserve scene-scoped routers, app-wide `SessionStore`, screen-owned ViewModels, feature-scoped dependencies, and all async cancellation/version safeguards.
- `App/Navigation` owns application navigation infrastructure; feature routers and routes remain feature-owned.
- `App/Services/Session` owns all Session models, protocols, implementations, dependencies, and shared store.
- Every feature gets the same folder scaffold and compile-safe extension points for roles without real implementations.
- Empty extension points are never registered in `AppDependencies`, injected into a screen, or instantiated at runtime.
- `Shared` contains only cross-feature UI, extensions, and utilities; do not create speculative shared visual components.
- Move files with Git history preserved.
- Use file-system-synchronized groups; do not add individual Swift file references to `project.pbxproj`.
- Use test-first RED/GREEN for any behavior change. This refactor intentionally changes no runtime behavior, so do not manufacture RED by breaking production code or add tautological tests for empty constructors and source paths.

## Target Production Structure

```text
AppTemplate/
├── App/
│   ├── Entry/
│   ├── Composition/
│   ├── Navigation/
│   │   ├── Containers/
│   │   ├── Core/
│   │   ├── DeepLinks/
│   │   ├── Diagnostics/
│   │   ├── Lifecycle/
│   │   ├── Routing/
│   │   └── Snapshots/
│   └── Services/
│       └── Session/
│           ├── Dependencies/
│           ├── Implementations/
│           ├── Models/
│           ├── Protocols/
│           └── Store/
├── Features/
│   ├── Authentication/
│   ├── Home/
│   ├── Browse/
│   └── Settings/
├── Shared/
│   ├── UI/
│   ├── Extensions/
│   └── Utilities/
└── Resources/
```

Every feature uses:

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

## Target Test Structure

```text
AppTemplateTests/
├── App/
│   ├── Composition/
│   ├── Navigation/
│   └── Services/Session/
├── Features/
│   ├── Authentication/
│   ├── Home/
│   ├── Browse/
│   └── Settings/
└── Project/
```

---

### Task 1: Organize App Entry, Composition, and Navigation

**Files:**
- Move: `AppTemplate/AppTemplateApp.swift` → `AppTemplate/App/Entry/AppTemplateApp.swift`
- Move: `AppTemplate/ContentView.swift` → `AppTemplate/App/Entry/ContentView.swift`
- Move: `AppTemplate/App/Dependencies/AppDependencies.swift` → `AppTemplate/App/Composition/AppDependencies.swift`
- Move: `AppTemplate/App/Navigation/AppSceneView.swift` → `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- Move: `AppTemplate/App/Navigation/AppRootView.swift` → `AppTemplate/App/Navigation/Containers/AppRootView.swift`
- Move: `AppTemplate/App/Navigation/AppShellView.swift` → `AppTemplate/App/Navigation/Containers/AppShellView.swift`
- Move: `AppTemplate/Core/Navigation/StackRouting.swift` → `AppTemplate/App/Navigation/Core/StackRouting.swift`
- Move: `AppTemplate/App/Navigation/DeepLinkParser.swift` → `AppTemplate/App/Navigation/DeepLinks/DeepLinkParser.swift`
- Move: `AppTemplate/App/Navigation/NavigationLogger.swift` → `AppTemplate/App/Navigation/Diagnostics/NavigationLogger.swift`
- Move: `AppTemplate/App/Navigation/AppSceneNavigationLifecycle.swift` → `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`
- Move: `AppTemplate/App/Navigation/AppFlow.swift` → `AppTemplate/App/Navigation/Routing/AppFlow.swift`
- Move: `AppTemplate/App/Navigation/AppSection.swift` → `AppTemplate/App/Navigation/Routing/AppSection.swift`
- Move: `AppTemplate/App/Navigation/NavigationIntent.swift` → `AppTemplate/App/Navigation/Routing/NavigationIntent.swift`
- Move: `AppTemplate/App/Navigation/AppRouter.swift` → `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- Move: `AppTemplate/App/Navigation/NavigationSnapshot.swift` → `AppTemplate/App/Navigation/Snapshots/NavigationSnapshot.swift`
- Move: `AppTemplateTests/AppDependenciesTests.swift` → `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- Move: `AppTemplateTests/StackRoutingTests.swift` → `AppTemplateTests/App/Navigation/Core/StackRoutingTests.swift`
- Move: `AppTemplateTests/DeepLinkParserTests.swift` → `AppTemplateTests/App/Navigation/DeepLinks/DeepLinkParserTests.swift`
- Move: `AppTemplateTests/AppSceneNavigationLifecycleTests.swift` → `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
- Move: `AppTemplateTests/AppRouterTests.swift` → `AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift`
- Move: `AppTemplateTests/NavigationSnapshotTests.swift` → `AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift`

**Interfaces:**
- Preserves: `AppTemplateApp`, `ContentView`, `AppDependencies`, `AppRouter`, `StackRouting`, `DeepLinkParser`, `NavigationSnapshot`, and all navigation APIs unchanged.
- Produces: final `App/Entry`, `App/Composition`, and `App/Navigation` ownership used by every later task.

- [ ] **Step 1: Create exact destination directories**

```bash
mkdir -p \
  AppTemplate/App/Entry \
  AppTemplate/App/Composition \
  AppTemplate/App/Navigation/Containers \
  AppTemplate/App/Navigation/Core \
  AppTemplate/App/Navigation/DeepLinks \
  AppTemplate/App/Navigation/Diagnostics \
  AppTemplate/App/Navigation/Lifecycle \
  AppTemplate/App/Navigation/Routing \
  AppTemplate/App/Navigation/Snapshots \
  AppTemplateTests/App/Composition \
  AppTemplateTests/App/Navigation/Core \
  AppTemplateTests/App/Navigation/DeepLinks \
  AppTemplateTests/App/Navigation/Lifecycle \
  AppTemplateTests/App/Navigation/Routing \
  AppTemplateTests/App/Navigation/Snapshots
```

- [ ] **Step 2: Move App entry and composition files**

```bash
git mv AppTemplate/AppTemplateApp.swift AppTemplate/App/Entry/AppTemplateApp.swift
git mv AppTemplate/ContentView.swift AppTemplate/App/Entry/ContentView.swift
git mv AppTemplate/App/Dependencies/AppDependencies.swift AppTemplate/App/Composition/AppDependencies.swift
```

- [ ] **Step 3: Move navigation source files**

```bash
git mv AppTemplate/App/Navigation/AppSceneView.swift AppTemplate/App/Navigation/Containers/AppSceneView.swift
git mv AppTemplate/App/Navigation/AppRootView.swift AppTemplate/App/Navigation/Containers/AppRootView.swift
git mv AppTemplate/App/Navigation/AppShellView.swift AppTemplate/App/Navigation/Containers/AppShellView.swift
git mv AppTemplate/Core/Navigation/StackRouting.swift AppTemplate/App/Navigation/Core/StackRouting.swift
git mv AppTemplate/App/Navigation/DeepLinkParser.swift AppTemplate/App/Navigation/DeepLinks/DeepLinkParser.swift
git mv AppTemplate/App/Navigation/NavigationLogger.swift AppTemplate/App/Navigation/Diagnostics/NavigationLogger.swift
git mv AppTemplate/App/Navigation/AppSceneNavigationLifecycle.swift AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift
git mv AppTemplate/App/Navigation/AppFlow.swift AppTemplate/App/Navigation/Routing/AppFlow.swift
git mv AppTemplate/App/Navigation/AppSection.swift AppTemplate/App/Navigation/Routing/AppSection.swift
git mv AppTemplate/App/Navigation/NavigationIntent.swift AppTemplate/App/Navigation/Routing/NavigationIntent.swift
git mv AppTemplate/App/Navigation/AppRouter.swift AppTemplate/App/Navigation/Routing/AppRouter.swift
git mv AppTemplate/App/Navigation/NavigationSnapshot.swift AppTemplate/App/Navigation/Snapshots/NavigationSnapshot.swift
```

- [ ] **Step 4: Move navigation and composition tests**

```bash
git mv AppTemplateTests/AppDependenciesTests.swift AppTemplateTests/App/Composition/AppDependenciesTests.swift
git mv AppTemplateTests/StackRoutingTests.swift AppTemplateTests/App/Navigation/Core/StackRoutingTests.swift
git mv AppTemplateTests/DeepLinkParserTests.swift AppTemplateTests/App/Navigation/DeepLinks/DeepLinkParserTests.swift
git mv AppTemplateTests/AppSceneNavigationLifecycleTests.swift AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift
git mv AppTemplateTests/AppRouterTests.swift AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift
git mv AppTemplateTests/NavigationSnapshotTests.swift AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift
```

- [ ] **Step 5: Run focused navigation and composition regression tests**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -only-testing:AppTemplateTests/StackRoutingTests \
  -only-testing:AppTemplateTests/DeepLinkParserTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests \
  -only-testing:AppTemplateTests/AppRouterTests \
  -only-testing:AppTemplateTests/NavigationSnapshotTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all selected suites pass; file-system-synchronized groups discover every moved source and test file.

- [ ] **Step 6: Verify obsolete source directories are empty**

```bash
find AppTemplate/App/Dependencies AppTemplate/Core/Navigation -type f -print 2>/dev/null
find AppTemplate/App/Navigation -maxdepth 1 -type f -print
```

Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate AppTemplateTests
git commit -m "refactor: organize app entry and navigation"
```

---

### Task 2: Move Session into App Services

**Files:**
- Move: `AppTemplate/App/Session/SessionStore.swift` → `AppTemplate/App/Services/Session/Store/SessionStore.swift`
- Move: `AppTemplate/Core/Session/SessionDependencies.swift` → `AppTemplate/App/Services/Session/Dependencies/SessionDependencies.swift`
- Move: `AppTemplate/Core/Session/InMemorySessionService.swift` → `AppTemplate/App/Services/Session/Implementations/InMemorySessionService.swift`
- Move: `AppTemplate/Core/Session/UserSession.swift` → `AppTemplate/App/Services/Session/Models/UserSession.swift`
- Move: `AppTemplate/Core/Session/SessionService.swift` → `AppTemplate/App/Services/Session/Protocols/SessionService.swift`
- Move: `AppTemplateTests/SessionStoreTests.swift` → `AppTemplateTests/App/Services/Session/SessionStoreTests.swift`

**Interfaces:**
- Preserves: `SessionDependencies`, `SessionService`, `InMemorySessionService`, `UserSession`, and `SessionStore` unchanged.
- Preserves: app-wide `SessionStore` ownership and all startup coalescing/command-version behavior.
- Produces: `App/Services/Session` module layout used by App composition and feature screens.

- [ ] **Step 1: Create the Session service directories**

```bash
mkdir -p \
  AppTemplate/App/Services/Session/Dependencies \
  AppTemplate/App/Services/Session/Implementations \
  AppTemplate/App/Services/Session/Models \
  AppTemplate/App/Services/Session/Protocols \
  AppTemplate/App/Services/Session/Store \
  AppTemplateTests/App/Services/Session
```

- [ ] **Step 2: Move Session production files**

```bash
git mv AppTemplate/Core/Session/SessionDependencies.swift AppTemplate/App/Services/Session/Dependencies/SessionDependencies.swift
git mv AppTemplate/Core/Session/InMemorySessionService.swift AppTemplate/App/Services/Session/Implementations/InMemorySessionService.swift
git mv AppTemplate/Core/Session/UserSession.swift AppTemplate/App/Services/Session/Models/UserSession.swift
git mv AppTemplate/Core/Session/SessionService.swift AppTemplate/App/Services/Session/Protocols/SessionService.swift
git mv AppTemplate/App/Session/SessionStore.swift AppTemplate/App/Services/Session/Store/SessionStore.swift
```

- [ ] **Step 3: Move Session tests**

```bash
git mv AppTemplateTests/SessionStoreTests.swift AppTemplateTests/App/Services/Session/SessionStoreTests.swift
```

- [ ] **Step 4: Run Session and composition regression tests**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/SessionStoreTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all selected tests pass with existing concurrency safeguards unchanged.

- [ ] **Step 5: Verify obsolete Session directories contain no files**

```bash
find AppTemplate/Core/Session AppTemplate/App/Session -type f -print 2>/dev/null
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate AppTemplateTests
git commit -m "refactor: organize session as an app service"
```

---

### Task 3: Apply the Uniform Authentication Feature Scaffold

**Files:**
- Move: `AppTemplate/App/Authentication/AuthenticationView.swift` → `AppTemplate/Features/Authentication/Screens/AuthenticationView.swift`
- Move: `AppTemplate/App/Authentication/AuthenticationViewModel.swift` → `AppTemplate/Features/Authentication/ViewModels/AuthenticationViewModel.swift`
- Create: `AppTemplate/Features/Authentication/Navigation/AuthenticationNavigation.swift`
- Create: `AppTemplate/Features/Authentication/Dependencies/AuthenticationDependencies.swift`
- Create: `AppTemplate/Features/Authentication/Domain/Models/AuthenticationModel.swift`
- Create: `AppTemplate/Features/Authentication/Domain/Repositories/AuthenticationRepository.swift`
- Create: `AppTemplate/Features/Authentication/Data/Repositories/InMemoryAuthenticationRepository.swift`
- Create: `AppTemplate/Features/Authentication/Services/AuthenticationService.swift`
- Create: `AppTemplate/Features/Authentication/UI/Components/AuthenticationComponents.swift`
- Move: `AppTemplateTests/AuthenticationViewModelTests.swift` → `AppTemplateTests/Features/Authentication/AuthenticationViewModelTests.swift`

**Interfaces:**
- Preserves: `AuthenticationView` and `AuthenticationViewModel`.
- Produces: inert `AuthenticationNavigation`, `AuthenticationDependencies`, `AuthenticationModel`, `AuthenticationRepository`, `InMemoryAuthenticationRepository`, `AuthenticationService`, and `AuthenticationComponents`.
- Does not produce: a second router, a runtime repository graph, or a new service registration.

- [ ] **Step 1: Create the complete Authentication scaffold**

```bash
mkdir -p \
  AppTemplate/Features/Authentication/Screens \
  AppTemplate/Features/Authentication/ViewModels \
  AppTemplate/Features/Authentication/Navigation \
  AppTemplate/Features/Authentication/Dependencies \
  AppTemplate/Features/Authentication/Domain/Models \
  AppTemplate/Features/Authentication/Domain/Repositories \
  AppTemplate/Features/Authentication/Data/Repositories \
  AppTemplate/Features/Authentication/Services \
  AppTemplate/Features/Authentication/UI/Components \
  AppTemplateTests/Features/Authentication
```

- [ ] **Step 2: Move the real Authentication screen, ViewModel, and tests**

```bash
git mv AppTemplate/App/Authentication/AuthenticationView.swift AppTemplate/Features/Authentication/Screens/AuthenticationView.swift
git mv AppTemplate/App/Authentication/AuthenticationViewModel.swift AppTemplate/Features/Authentication/ViewModels/AuthenticationViewModel.swift
git mv AppTemplateTests/AuthenticationViewModelTests.swift AppTemplateTests/Features/Authentication/AuthenticationViewModelTests.swift
```

- [ ] **Step 3: Add Authentication extension points**

Create `AuthenticationNavigation.swift`:

```swift
nonisolated struct AuthenticationNavigation: Sendable {
    init() {}
}
```

Create `AuthenticationDependencies.swift`:

```swift
nonisolated struct AuthenticationDependencies: Sendable {
    init() {}
}
```

Create `AuthenticationModel.swift`:

```swift
nonisolated struct AuthenticationModel: Sendable {
    init() {}
}
```

Create `AuthenticationRepository.swift`:

```swift
nonisolated protocol AuthenticationRepository: Sendable {}
```

Create `InMemoryAuthenticationRepository.swift`:

```swift
nonisolated struct InMemoryAuthenticationRepository: AuthenticationRepository {
    init() {}
}
```

Create `AuthenticationService.swift`:

```swift
nonisolated protocol AuthenticationService: Sendable {}
```

Create `AuthenticationComponents.swift`:

```swift
nonisolated struct AuthenticationComponents: Sendable {
    init() {}
}
```

- [ ] **Step 4: Run Authentication regression tests**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AuthenticationViewModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all Authentication tests pass; the moved screen still composes the real `SessionStore` and `AppRouter`.

- [ ] **Step 5: Verify inert extension points are not consumed**

```bash
rg -n \
  'Authentication(Navigation|Dependencies|Model|Repository|Service|Components)' \
  AppTemplate \
  -g '*.swift'
```

Expected: each placeholder name appears only in its own declaration file, except `AuthenticationRepository` also appears in `InMemoryAuthenticationRepository.swift` for conformance.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/Features/Authentication AppTemplateTests/Features/Authentication
git commit -m "refactor: organize authentication feature"
```

---

### Task 4: Apply the Uniform Home Feature Scaffold

**Files:**
- Move: Home screens → `AppTemplate/Features/Home/Screens/`
- Move: Home ViewModels → `AppTemplate/Features/Home/ViewModels/`
- Move: `HomeRoute` and `HomeRouter` → `AppTemplate/Features/Home/Navigation/`
- Create: `AppTemplate/Features/Home/Dependencies/HomeDependencies.swift`
- Create: `AppTemplate/Features/Home/Domain/Models/HomeModel.swift`
- Create: `AppTemplate/Features/Home/Domain/Repositories/HomeRepository.swift`
- Create: `AppTemplate/Features/Home/Data/Repositories/InMemoryHomeRepository.swift`
- Create: `AppTemplate/Features/Home/Services/HomeService.swift`
- Create: `AppTemplate/Features/Home/UI/Components/HomeComponents.swift`
- Move: `AppTemplateTests/HomeViewModelTests.swift` → `AppTemplateTests/Features/Home/HomeViewModelTests.swift`

**Interfaces:**
- Preserves: `HomeView`, `HomeDetailsView`, `NavigationGuideView`, their ViewModels, `HomeRoute`, and `HomeRouter`.
- Produces: inert Home Dependencies, Domain, Data, Services, and UI extension points.
- Preserves: `HomeRouter` as the only owner of Home navigation state.

- [ ] **Step 1: Create the complete Home scaffold**

```bash
mkdir -p \
  AppTemplate/Features/Home/Screens \
  AppTemplate/Features/Home/ViewModels \
  AppTemplate/Features/Home/Navigation \
  AppTemplate/Features/Home/Dependencies \
  AppTemplate/Features/Home/Domain/Models \
  AppTemplate/Features/Home/Domain/Repositories \
  AppTemplate/Features/Home/Data/Repositories \
  AppTemplate/Features/Home/Services \
  AppTemplate/Features/Home/UI/Components \
  AppTemplateTests/Features/Home
```

- [ ] **Step 2: Move real Home types and tests**

```bash
git mv AppTemplate/Features/Home/HomeView.swift AppTemplate/Features/Home/Screens/HomeView.swift
git mv AppTemplate/Features/Home/HomeDetailsView.swift AppTemplate/Features/Home/Screens/HomeDetailsView.swift
git mv AppTemplate/Features/Home/NavigationGuideView.swift AppTemplate/Features/Home/Screens/NavigationGuideView.swift
git mv AppTemplate/Features/Home/Presentation/HomeViewModel.swift AppTemplate/Features/Home/ViewModels/HomeViewModel.swift
git mv AppTemplate/Features/Home/Presentation/HomeDetailsViewModel.swift AppTemplate/Features/Home/ViewModels/HomeDetailsViewModel.swift
git mv AppTemplate/Features/Home/Presentation/NavigationGuideViewModel.swift AppTemplate/Features/Home/ViewModels/NavigationGuideViewModel.swift
git mv AppTemplate/Features/Home/HomeRoute.swift AppTemplate/Features/Home/Navigation/HomeRoute.swift
git mv AppTemplate/Features/Home/HomeRouter.swift AppTemplate/Features/Home/Navigation/HomeRouter.swift
git mv AppTemplateTests/HomeViewModelTests.swift AppTemplateTests/Features/Home/HomeViewModelTests.swift
```

- [ ] **Step 3: Add Home extension points**

Create `HomeDependencies.swift`:

```swift
nonisolated struct HomeDependencies: Sendable {
    init() {}
}
```

Create `HomeModel.swift`:

```swift
nonisolated struct HomeModel: Sendable {
    init() {}
}
```

Create `HomeRepository.swift`:

```swift
nonisolated protocol HomeRepository: Sendable {}
```

Create `InMemoryHomeRepository.swift`:

```swift
nonisolated struct InMemoryHomeRepository: HomeRepository {
    init() {}
}
```

Create `HomeService.swift`:

```swift
nonisolated protocol HomeService: Sendable {}
```

Create `HomeComponents.swift`:

```swift
nonisolated struct HomeComponents: Sendable {
    init() {}
}
```

- [ ] **Step 4: Run Home regression tests**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/HomeViewModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all Home tests pass with router ownership unchanged.

- [ ] **Step 5: Verify the Home root contains only scaffold directories**

```bash
find AppTemplate/Features/Home -maxdepth 1 -type f -print
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/Features/Home AppTemplateTests/Features/Home
git commit -m "refactor: organize home feature"
```

---

### Task 5: Apply the Uniform Browse Feature Scaffold

**Files:**
- Move: Browse screens → `AppTemplate/Features/Browse/Screens/`
- Move: Browse ViewModels and state → `AppTemplate/Features/Browse/ViewModels/`
- Move: `BrowseRoute` and `BrowseRouter` → `AppTemplate/Features/Browse/Navigation/`
- Move: `BrowseDependencies` → `AppTemplate/Features/Browse/Dependencies/`
- Move: `BrowseItem` → `AppTemplate/Features/Browse/Domain/Models/`
- Move: `BrowseRepository` → `AppTemplate/Features/Browse/Domain/Repositories/`
- Move: `InMemoryBrowseRepository` → `AppTemplate/Features/Browse/Data/Repositories/`
- Create: `AppTemplate/Features/Browse/Services/BrowseService.swift`
- Create: `AppTemplate/Features/Browse/UI/Components/BrowseComponents.swift`
- Move: `AppTemplateTests/BrowseViewModelTests.swift` → `AppTemplateTests/Features/Browse/BrowseViewModelTests.swift`

**Interfaces:**
- Preserves: every Browse runtime type and initializer.
- Preserves: cancellation, retry, request ownership, and stale-response rejection.
- Produces: inert `BrowseService` and `BrowseComponents` extension points only where Browse has no current real type.

- [ ] **Step 1: Create the complete Browse scaffold**

```bash
mkdir -p \
  AppTemplate/Features/Browse/Screens \
  AppTemplate/Features/Browse/ViewModels \
  AppTemplate/Features/Browse/Navigation \
  AppTemplate/Features/Browse/Dependencies \
  AppTemplate/Features/Browse/Domain/Models \
  AppTemplate/Features/Browse/Domain/Repositories \
  AppTemplate/Features/Browse/Data/Repositories \
  AppTemplate/Features/Browse/Services \
  AppTemplate/Features/Browse/UI/Components \
  AppTemplateTests/Features/Browse
```

- [ ] **Step 2: Move real Browse types and tests**

```bash
git mv AppTemplate/Features/Browse/BrowseNavigationView.swift AppTemplate/Features/Browse/Screens/BrowseNavigationView.swift
git mv AppTemplate/Features/Browse/BrowseDetailView.swift AppTemplate/Features/Browse/Screens/BrowseDetailView.swift
git mv AppTemplate/Features/Browse/Presentation/BrowseListViewModel.swift AppTemplate/Features/Browse/ViewModels/BrowseListViewModel.swift
git mv AppTemplate/Features/Browse/Presentation/BrowseDetailViewModel.swift AppTemplate/Features/Browse/ViewModels/BrowseDetailViewModel.swift
git mv AppTemplate/Features/Browse/Presentation/BrowseStoreState.swift AppTemplate/Features/Browse/ViewModels/BrowseStoreState.swift
git mv AppTemplate/Features/Browse/BrowseRoute.swift AppTemplate/Features/Browse/Navigation/BrowseRoute.swift
git mv AppTemplate/Features/Browse/BrowseRouter.swift AppTemplate/Features/Browse/Navigation/BrowseRouter.swift
git mv AppTemplate/Features/Browse/Domain/BrowseDependencies.swift AppTemplate/Features/Browse/Dependencies/BrowseDependencies.swift
git mv AppTemplate/Features/Browse/BrowseItem.swift AppTemplate/Features/Browse/Domain/Models/BrowseItem.swift
git mv AppTemplate/Features/Browse/Domain/BrowseRepository.swift AppTemplate/Features/Browse/Domain/Repositories/BrowseRepository.swift
git mv AppTemplate/Features/Browse/Data/InMemoryBrowseRepository.swift AppTemplate/Features/Browse/Data/Repositories/InMemoryBrowseRepository.swift
git mv AppTemplateTests/BrowseViewModelTests.swift AppTemplateTests/Features/Browse/BrowseViewModelTests.swift
```

- [ ] **Step 3: Add the missing Browse extension points**

Create `BrowseService.swift`:

```swift
nonisolated protocol BrowseService: Sendable {}
```

Create `BrowseComponents.swift`:

```swift
nonisolated struct BrowseComponents: Sendable {
    init() {}
}
```

- [ ] **Step 4: Run Browse regression tests**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/BrowseViewModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all Browse tests pass, including cancellation and stale-response cases.

- [ ] **Step 5: Verify obsolete Browse layout directories contain no files**

```bash
find \
  AppTemplate/Features/Browse/Presentation \
  AppTemplate/Features/Browse/Domain \
  AppTemplate/Features/Browse/Data \
  -maxdepth 1 -type f -print 2>/dev/null
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/Features/Browse AppTemplateTests/Features/Browse
git commit -m "refactor: organize browse feature"
```

---

### Task 6: Apply the Uniform Settings Feature Scaffold

**Files:**
- Move: Settings screens → `AppTemplate/Features/Settings/Screens/`
- Move: Settings ViewModels → `AppTemplate/Features/Settings/ViewModels/`
- Move: `SettingsRoute` and `SettingsRouter` → `AppTemplate/Features/Settings/Navigation/`
- Create: `AppTemplate/Features/Settings/Dependencies/SettingsDependencies.swift`
- Create: `AppTemplate/Features/Settings/Domain/Models/SettingsModel.swift`
- Create: `AppTemplate/Features/Settings/Domain/Repositories/SettingsRepository.swift`
- Create: `AppTemplate/Features/Settings/Data/Repositories/InMemorySettingsRepository.swift`
- Create: `AppTemplate/Features/Settings/Services/SettingsService.swift`
- Create: `AppTemplate/Features/Settings/UI/Components/SettingsComponents.swift`
- Move: `AppTemplateTests/SettingsViewModelTests.swift` → `AppTemplateTests/Features/Settings/SettingsViewModelTests.swift`

**Interfaces:**
- Preserves: all Settings and About screens/ViewModels, `SettingsRoute`, and `SettingsRouter`.
- Produces: inert Settings Dependencies, Domain, Data, Services, and UI extension points.
- Preserves: app-wide `SessionStore` for sign-out and `SettingsRouter` for navigation.

- [ ] **Step 1: Create the complete Settings scaffold**

```bash
mkdir -p \
  AppTemplate/Features/Settings/Screens \
  AppTemplate/Features/Settings/ViewModels \
  AppTemplate/Features/Settings/Navigation \
  AppTemplate/Features/Settings/Dependencies \
  AppTemplate/Features/Settings/Domain/Models \
  AppTemplate/Features/Settings/Domain/Repositories \
  AppTemplate/Features/Settings/Data/Repositories \
  AppTemplate/Features/Settings/Services \
  AppTemplate/Features/Settings/UI/Components \
  AppTemplateTests/Features/Settings
```

- [ ] **Step 2: Move real Settings types and tests**

```bash
git mv AppTemplate/Features/Settings/SettingsView.swift AppTemplate/Features/Settings/Screens/SettingsView.swift
git mv AppTemplate/Features/Settings/AboutView.swift AppTemplate/Features/Settings/Screens/AboutView.swift
git mv AppTemplate/Features/Settings/Presentation/SettingsViewModel.swift AppTemplate/Features/Settings/ViewModels/SettingsViewModel.swift
git mv AppTemplate/Features/Settings/Presentation/AboutViewModel.swift AppTemplate/Features/Settings/ViewModels/AboutViewModel.swift
git mv AppTemplate/Features/Settings/SettingsRoute.swift AppTemplate/Features/Settings/Navigation/SettingsRoute.swift
git mv AppTemplate/Features/Settings/SettingsRouter.swift AppTemplate/Features/Settings/Navigation/SettingsRouter.swift
git mv AppTemplateTests/SettingsViewModelTests.swift AppTemplateTests/Features/Settings/SettingsViewModelTests.swift
```

- [ ] **Step 3: Add Settings extension points**

Create `SettingsDependencies.swift`:

```swift
nonisolated struct SettingsDependencies: Sendable {
    init() {}
}
```

Create `SettingsModel.swift`:

```swift
nonisolated struct SettingsModel: Sendable {
    init() {}
}
```

Create `SettingsRepository.swift`:

```swift
nonisolated protocol SettingsRepository: Sendable {}
```

Create `InMemorySettingsRepository.swift`:

```swift
nonisolated struct InMemorySettingsRepository: SettingsRepository {
    init() {}
}
```

Create `SettingsService.swift`:

```swift
nonisolated protocol SettingsService: Sendable {}
```

Create `SettingsComponents.swift`:

```swift
nonisolated struct SettingsComponents: Sendable {
    init() {}
}
```

- [ ] **Step 4: Run Settings regression tests**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/SettingsViewModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all Settings tests pass, including failed sign-out retaining the existing session.

- [ ] **Step 5: Verify the Settings root contains only scaffold directories**

```bash
find AppTemplate/Features/Settings -maxdepth 1 -type f -print
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/Features/Settings AppTemplateTests/Features/Settings
git commit -m "refactor: organize settings feature"
```

---

### Task 7: Move Resources and Project Configuration Tests

**Files:**
- Move: `AppTemplate/Assets.xcassets` → `AppTemplate/Resources/Assets.xcassets`
- Move: `AppTemplate/Info.plist` → `AppTemplate/Resources/Info.plist`
- Modify: `AppTemplate.xcodeproj/project.pbxproj`
- Move: `AppTemplateTests/ProjectConfigurationTests.swift` → `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**
- Preserves: application icon, accent color, custom `apptemplate` URL scheme, bundle identity, and construction coverage.
- Produces: `Resources` as the sole application resource owner.
- Produces: updated `INFOPLIST_FILE = AppTemplate/Resources/Info.plist` for Debug and Release.

- [ ] **Step 1: Create resource and project-test directories**

```bash
mkdir -p AppTemplate/Resources AppTemplateTests/Project
```

- [ ] **Step 2: Move resources and configuration tests**

```bash
git mv AppTemplate/Assets.xcassets AppTemplate/Resources/Assets.xcassets
git mv AppTemplate/Info.plist AppTemplate/Resources/Info.plist
git mv AppTemplateTests/ProjectConfigurationTests.swift AppTemplateTests/Project/ProjectConfigurationTests.swift
```

- [ ] **Step 3: Update synchronized-group membership exception**

In `AppTemplate.xcodeproj/project.pbxproj`, change:

```text
Info.plist,
```

to:

```text
Resources/Info.plist,
```

This prevents the moved Info.plist from also entering the Resources build
phase through the synchronized root.

- [ ] **Step 4: Update both application build configurations**

Change both occurrences of:

```text
INFOPLIST_FILE = AppTemplate/Info.plist;
```

to:

```text
INFOPLIST_FILE = AppTemplate/Resources/Info.plist;
```

Do not change the test-target generated Info.plist settings.

- [ ] **Step 5: Run project configuration tests**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ProjectConfigurationTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: module loading, URL scheme registration, and all navigation-root construction tests pass.

- [ ] **Step 6: Build generic iOS to validate the asset catalog**

```bash
xcodebuild build -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds without duplicate Info.plist commands or missing asset-catalog errors.

- [ ] **Step 7: Verify build settings reference only the moved Info.plist**

```bash
rg -n 'INFOPLIST_FILE|membershipExceptions|Resources/Info.plist|AppTemplate/Info.plist' \
  AppTemplate.xcodeproj/project.pbxproj
```

Expected: the exception and both app configurations reference `Resources/Info.plist`; no `AppTemplate/Info.plist` value remains.

- [ ] **Step 8: Commit**

```bash
git add AppTemplate/Resources AppTemplateTests/Project AppTemplate.xcodeproj/project.pbxproj
git commit -m "refactor: organize project resources"
```

---

### Task 8: Document and Verify the Complete Architecture

**Files:**
- Modify: `README.md`

**Interfaces:**
- Documents: App ownership, uniform feature scaffold, empty extension-point rule, Shared rule, test mirroring, and future Network/Database service placement.
- Verifies: the complete refactor across iOS/iPadOS and macOS.

- [ ] **Step 1: Add a Project Structure section to README**

Add this section after the opening platform sentence and before Navigation:

```markdown
## Project Structure

- `App/Entry` owns application startup.
- `App/Composition` owns the explicit dependency graph.
- `App/Navigation` owns app-wide navigation infrastructure.
- `App/Services` owns app-wide service modules such as Session.
- `Features/<Feature>` owns Screens, ViewModels, Navigation, Dependencies,
  Domain, Data, Services, and feature UI components.
- `Shared` is reserved for genuinely cross-feature UI, extensions, and
  utilities.
- `Resources` owns the asset catalog and Info.plist.

Every feature exposes the same folder scaffold. Empty compile-safe types mark
future extension points but are not registered in DI or instantiated at
runtime. Existing real types replace placeholders for their roles.

Future shared network transports belong in `App/Services/Network`; database
engines belong in `App/Services/Database`. Feature-specific adapters, DTOs,
mappers, and repositories remain inside that feature's `Data` folder.

Tests mirror production ownership under `AppTemplateTests`.
```

- [ ] **Step 2: Verify every feature has the same directory scaffold**

```bash
for feature in Authentication Home Browse Settings; do
  for path in \
    Screens \
    ViewModels \
    Navigation \
    Dependencies \
    Domain/Models \
    Domain/Repositories \
    Data/Repositories \
    Services \
    UI/Components; do
    test -d "AppTemplate/Features/$feature/$path" || {
      echo "missing AppTemplate/Features/$feature/$path"
      exit 1
    }
  done
done
```

Expected: exit 0 with no output.

- [ ] **Step 3: Verify old production and test layouts are gone**

```bash
for path in \
  AppTemplate/Core \
  AppTemplate/App/Dependencies \
  AppTemplate/App/Authentication \
  AppTemplate/App/Session \
  AppTemplate/Features/Browse/Presentation \
  AppTemplate/Features/Home/Presentation \
  AppTemplate/Features/Settings/Presentation; do
  test ! -d "$path" || {
    remaining=$(find "$path" -type f -print)
    test -z "$remaining" || {
      echo "$remaining"
      exit 1
    }
  }
done
```

Expected: exit 0 with no file paths printed.

- [ ] **Step 4: Verify placeholders do not leak into composition or screens**

```bash
rg -n \
  '(Authentication|Home|Settings)(Navigation|Dependencies|Model|Repository|Service|Components)|Browse(Service|Components)' \
  AppTemplate/App AppTemplate/Features/*/Screens AppTemplate/Features/*/ViewModels
```

Expected: no matches.

- [ ] **Step 5: Verify existing architecture guards**

```bash
rg -n 'ObservableObject|@Published|@StateObject|BaseViewModel|resolve\(' AppTemplate
```

Expected: no matches.

Run:

```bash
rg -n 'AppDependencies' AppTemplate -g '*ViewModel.swift'
```

Expected: no matches.

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 6: Run the complete iOS test suite**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all tests pass with zero failures.

- [ ] **Step 7: Run the complete macOS test suite**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all tests pass with zero failures.

- [ ] **Step 8: Build Release for iOS/iPadOS**

```bash
xcodebuild build -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: the universal iPhone/iPad application build succeeds.

- [ ] **Step 9: Build Release for macOS**

```bash
xcodebuild build -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: the macOS application build succeeds.

- [ ] **Step 10: Commit documentation**

```bash
git add README.md
git commit -m "docs: explain purpose-driven project structure"
```

- [ ] **Step 11: Inspect the final branch**

```bash
git status --short --branch
git log --oneline --decorate -12
```

Expected: clean working tree with eight focused implementation commits after the design and plan commits.
