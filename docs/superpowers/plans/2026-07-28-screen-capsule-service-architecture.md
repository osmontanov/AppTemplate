# Screen Capsule and Service-Only Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the parallel Service/Repository scaffold with one explicit
Service boundary, centralize models and reusable UI, and place every full
screen's View and ViewModel in its own feature-owned screen capsule.

**Architecture:** `AppDependencies` composes `I<ServiceName>` interfaces and
concrete `<ServiceName>` actors. Domain, Local, and Remote models are app-owned;
Local and Remote remain reserved without fake Swift types. Feature dependency
scopes and Routers remain feature-owned, while Route definitions move beside
the navigation-owning screen.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, Xcode 26,
file-system-synchronized Xcode groups, Git.

## Global Constraints

- Keep deployment targets at iOS 26.0, iPadOS 26.0, and macOS 26.0.
- Add no third-party dependencies.
- Keep `AppRouter` scene-scoped and `SessionStore` app-scoped.
- Keep every full screen's ViewModel private, non-optional, and owned by its
  View through SwiftUI `@State`.
- Do not inject the complete `AppDependencies` container into a ViewModel.
- Remove the Repository layer and every production/test type whose name ends
  in `Repository`.
- Service protocols use `I<ServiceName>`; concrete implementations use
  `<ServiceName>`.
- Do not create Local or Remote Service variants without a real database or
  API implementation.
- Preserve navigation, deep-link, snapshot, session, error, and async
  cancellation behavior.
- Preserve Git history for pure moves.
- Do not manually add Swift file references to
  `AppTemplate.xcodeproj/project.pbxproj`; synchronized groups discover them.

## Final File Map

### App-owned code

- `AppTemplate/App/Models/Domain/BrowseItem.swift`: shared Browse domain model.
- `AppTemplate/App/Models/Domain/UserSession.swift`: shared Session domain model.
- `AppTemplate/App/Models/Domain/BrowseStoreState.swift`: Browse presentation
  state types used by two screens.
- `AppTemplate/App/Models/Domain/NavigationGuideItem.swift`: Home guide item.
- `AppTemplate/App/Models/Domain/AuthenticationModel.swift`: template model
  extension point.
- `AppTemplate/App/Models/Domain/HomeModel.swift`: template model extension point.
- `AppTemplate/App/Models/Domain/SettingsModel.swift`: template model extension
  point.
- `AppTemplate/App/Models/Local/.gitkeep`: reserves database model ownership.
- `AppTemplate/App/Models/Remote/.gitkeep`: reserves API DTO ownership.
- `AppTemplate/App/Services/Browse/IBrowseService.swift`: Browse data/operation
  interface.
- `AppTemplate/App/Services/Browse/BrowseService.swift`: deterministic example
  actor implementing `IBrowseService`.
- `AppTemplate/App/Services/Session/ISessionService.swift`: Session operation
  interface.
- `AppTemplate/App/Services/Session/SessionService.swift`: example actor
  implementing `ISessionService`.
- `AppTemplate/App/Services/Session/SessionDependencies.swift`: immutable Session
  service scope.
- `AppTemplate/App/Services/Session/SessionStore.swift`: app-scoped observable
  Session state.
- `AppTemplate/App/Services/LocalDatabase/ILocalDatabaseService.swift`: inert
  local-database interface example.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift`: inert
  concrete example, absent from runtime DI.

### Feature-owned code

- `AppTemplate/Features/Authentication/Dependencies/AuthenticationDependencies.swift`
- `AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift`
- `AppTemplate/Features/Authentication/Screens/Authentication/ViewModel/AuthenticationViewModel.swift`
- `AppTemplate/Features/Browse/Dependencies/BrowseDependencies.swift`
- `AppTemplate/Features/Browse/Navigation/BrowseRouter.swift`
- `AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift`
- `AppTemplate/Features/Browse/Screens/Browse/ViewModel/BrowseListViewModel.swift`
- `AppTemplate/Features/Browse/Screens/Browse/Navigation/BrowseRoute.swift`
- `AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift`
- `AppTemplate/Features/Browse/Screens/BrowseDetail/ViewModel/BrowseDetailViewModel.swift`
- `AppTemplate/Features/Home/Dependencies/HomeDependencies.swift`
- `AppTemplate/Features/Home/Navigation/HomeRouter.swift`
- `AppTemplate/Features/Home/Screens/Home/View/HomeView.swift`
- `AppTemplate/Features/Home/Screens/Home/ViewModel/HomeViewModel.swift`
- `AppTemplate/Features/Home/Screens/Home/Navigation/HomeRoute.swift`
- `AppTemplate/Features/Home/Screens/HomeDetails/View/HomeDetailsView.swift`
- `AppTemplate/Features/Home/Screens/HomeDetails/ViewModel/HomeDetailsViewModel.swift`
- `AppTemplate/Features/Home/Screens/NavigationGuide/View/NavigationGuideView.swift`
- `AppTemplate/Features/Home/Screens/NavigationGuide/ViewModel/NavigationGuideViewModel.swift`
- `AppTemplate/Features/Settings/Dependencies/SettingsDependencies.swift`
- `AppTemplate/Features/Settings/Navigation/SettingsRouter.swift`
- `AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift`
- `AppTemplate/Features/Settings/Screens/Settings/ViewModel/SettingsViewModel.swift`
- `AppTemplate/Features/Settings/Screens/Settings/Navigation/SettingsRoute.swift`
- `AppTemplate/Features/Settings/Screens/About/View/AboutView.swift`
- `AppTemplate/Features/Settings/Screens/About/ViewModel/AboutViewModel.swift`

### Reusable UI and tests

- `AppTemplate/Utilities/UIComponents/*.swift`: all four existing component
  extension points, with no screen dependencies.
- `AppTemplateTests/App/Services/Browse/BrowseServiceTests.swift`
- `AppTemplateTests/App/Services/Session/SessionServiceTests.swift`
- `AppTemplateTests/App/Services/Session/SessionStoreTests.swift`
- `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift`
- `AppTemplateTests/Features/<Feature>/Screens/<Screen>/*Tests.swift`: screen
  behavior and construction tests.
- `AppTemplateTests/Features/Browse/TestSupport/BrowseServiceDoubles.swift`:
  doubles shared by Browse list/detail test suites.

---

### Task 1: Replace Browse Repository With the Browse Service Boundary

**Files:**
- Create: `AppTemplateTests/App/Services/Browse/BrowseServiceTests.swift`
- Move and rewrite:
  `AppTemplate/Features/Browse/Domain/Repositories/BrowseRepository.swift` →
  `AppTemplate/App/Services/Browse/IBrowseService.swift`
- Move and rewrite:
  `AppTemplate/Features/Browse/Data/Repositories/InMemoryBrowseRepository.swift`
  → `AppTemplate/App/Services/Browse/BrowseService.swift`
- Modify: `AppTemplate/Features/Browse/Dependencies/BrowseDependencies.swift`
- Modify: `AppTemplate/Features/Browse/ViewModels/BrowseListViewModel.swift`
- Modify: `AppTemplate/Features/Browse/ViewModels/BrowseDetailViewModel.swift`
- Modify: `AppTemplate/App/Composition/AppDependencies.swift`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- Modify: `AppTemplateTests/Features/Browse/BrowseViewModelTests.swift`
- Delete: `AppTemplate/Features/Browse/Services/BrowseService.swift`
- Delete:
  `AppTemplate/Features/Authentication/Domain/Repositories/AuthenticationRepository.swift`
- Delete:
  `AppTemplate/Features/Authentication/Data/Repositories/InMemoryAuthenticationRepository.swift`
- Delete:
  `AppTemplate/Features/Home/Domain/Repositories/HomeRepository.swift`
- Delete:
  `AppTemplate/Features/Home/Data/Repositories/InMemoryHomeRepository.swift`
- Delete:
  `AppTemplate/Features/Settings/Domain/Repositories/SettingsRepository.swift`
- Delete:
  `AppTemplate/Features/Settings/Data/Repositories/InMemorySettingsRepository.swift`

**Interfaces:**
- Produces:
  `nonisolated protocol IBrowseService: Sendable`
- Produces:
  `IBrowseService.items() async throws -> [BrowseItem]`
- Produces:
  `IBrowseService.item(id:) async throws -> BrowseItem?`
- Produces:
  `actor BrowseService: IBrowseService`
- Produces:
  `BrowseDependencies.init(service: any IBrowseService)`
- Preserves: list ordering, stable-ID lookup, async cancellation, stale-response
  rejection, failure presentation, and `notFound`.

- [ ] **Step 1: Write the failing Browse Service contract test**

Create `BrowseServiceTests.swift`:

```swift
import Testing
@testable import AppTemplate

struct BrowseServiceTests {
    @Test
    func itemsPreserveInputOrderAndLookupUsesStableID() async throws {
        let first = BrowseItem(id: "first", title: "First", summary: "One")
        let second = BrowseItem(id: "second", title: "Second", summary: "Two")
        let service: any IBrowseService = BrowseService(
            items: [first, second]
        )

        let items = try await service.items()
        let item = try await service.item(id: second.id)

        #expect(items == [first, second])
        #expect(item == second)
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/BrowseServiceTests
```

Expected: compilation fails because `IBrowseService` and the concrete
`BrowseService(items:)` do not exist.

- [ ] **Step 3: Move and implement the Browse Service types**

Create `IBrowseService.swift` from the old Repository contract:

```swift
nonisolated protocol IBrowseService: Sendable {
    func items() async throws -> [BrowseItem]
    func item(id: BrowseItem.ID) async throws -> BrowseItem?
}
```

Create `BrowseService.swift` by preserving the old actor implementation and
renaming only the abstraction:

```swift
actor BrowseService: IBrowseService {
    private var orderedIDs: [BrowseItem.ID]
    private var itemsByID: [BrowseItem.ID: BrowseItem]

    init(items: [BrowseItem]) {
        orderedIDs = items.map(\.id)
        itemsByID = Dictionary(
            uniqueKeysWithValues: items.map { ($0.id, $0) }
        )
    }

    func items() -> [BrowseItem] {
        orderedIDs.compactMap { itemsByID[$0] }
    }

    func item(id: BrowseItem.ID) -> BrowseItem? {
        itemsByID[id]
    }

    nonisolated static func live() -> BrowseService {
        BrowseService(items: [
            BrowseItem(
                id: "swiftui",
                title: "SwiftUI",
                summary: "Adaptive native interfaces."
            ),
            BrowseItem(
                id: "observation",
                title: "Observation",
                summary: "Focused state tracking."
            ),
            BrowseItem(
                id: "routing",
                title: "Typed Routing",
                summary: "Navigation represented as data."
            )
        ])
    }
}
```

Rewrite `BrowseDependencies`:

```swift
nonisolated struct BrowseDependencies: Sendable {
    let service: any IBrowseService

    init(service: any IBrowseService) {
        self.service = service
    }
}
```

In both Browse ViewModels, replace:

```swift
let repository = dependencies.repository
```

with:

```swift
let service = dependencies.service
```

and capture/call `service` without changing task ownership or state
transitions.

Update `AppDependencies.live/preview/test` so Browse construction is:

```swift
BrowseDependencies(service: BrowseService.live())
BrowseDependencies(service: BrowseService(items: browseItems))

static func test(
    browseService: any IBrowseService,
    sessionService: any SessionService
) -> AppDependencies
```

The Session type remains unchanged until Task 2.

Rename Browse test doubles to `InjectedBrowseService`,
`FailingBrowseService`, and `ControlledBrowseService`; make each conform to
`IBrowseService`. Replace every `repository:` argument and local variable with
`service:`.

The composition assertions become:

```swift
#expect(dependencies.browse.service is BrowseService)
let resolvedBrowseService = try #require(
    dependencies.browse.service as? InjectedBrowseService
)
#expect(resolvedBrowseService === browseService)
```

Delete the six inert Authentication/Home/Settings Repository protocol and
implementation files listed above. They have no consumers or runtime behavior.
Delete the old inert feature `BrowseService.swift` before adding the real
app-owned `BrowseService` so the target never contains duplicate type names.

- [ ] **Step 4: Run Browse and composition tests and verify GREEN**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/BrowseServiceTests \
  -only-testing:AppTemplateTests/BrowseViewModelTests \
  -only-testing:AppTemplateTests/AppDependenciesTests
```

Expected: all selected tests pass and output contains no Repository-named
Browse test double.

- [ ] **Step 5: Verify the production Repository layer is absent**

Run:

```bash
if rg -n 'Repository' AppTemplate; then
  exit 1
fi
test ! -d AppTemplate/Features/Browse/Domain/Repositories
test ! -d AppTemplate/Features/Browse/Data/Repositories
```

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate AppTemplateTests
git commit -m "refactor: replace browse repository with service"
```

---

### Task 2: Adopt `ISessionService` and a Concrete `SessionService`

**Files:**
- Create: `AppTemplateTests/App/Services/Session/SessionServiceTests.swift`
- Move and rewrite:
  `AppTemplate/App/Services/Session/Protocols/SessionService.swift` →
  `AppTemplate/App/Services/Session/ISessionService.swift`
- Move and rewrite:
  `AppTemplate/App/Services/Session/Implementations/InMemorySessionService.swift`
  → `AppTemplate/App/Services/Session/SessionService.swift`
- Move:
  `AppTemplate/App/Services/Session/Dependencies/SessionDependencies.swift` →
  `AppTemplate/App/Services/Session/SessionDependencies.swift`
- Move:
  `AppTemplate/App/Services/Session/Store/SessionStore.swift` →
  `AppTemplate/App/Services/Session/SessionStore.swift`
- Modify: `AppTemplate/App/Composition/AppDependencies.swift`
- Modify: all tests containing a Session service double.

**Interfaces:**
- Produces:
  `nonisolated protocol ISessionService: Sendable`
- Produces:
  `actor SessionService: ISessionService`
- Produces:
  `SessionDependencies.service: any ISessionService`
- Preserves: restoration, sign-in, sign-out, cancellation, command versioning,
  and stable-phase behavior.

- [ ] **Step 1: Write the failing concrete Session Service test**

Create `SessionServiceTests.swift`:

```swift
import Testing
@testable import AppTemplate

struct SessionServiceTests {
    @Test
    func sessionLifecycleUsesTheDeclaredInterface() async throws {
        let service: any ISessionService = SessionService(
            initialSession: nil
        )

        #expect(try await service.currentSession() == nil)

        let signedIn = try await service.signIn()
        #expect(signedIn.id == "template-user")
        #expect(try await service.currentSession() == signedIn)

        try await service.signOut()
        #expect(try await service.currentSession() == nil)
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/SessionServiceTests
```

Expected: compilation fails because `ISessionService` does not exist and
`SessionService` is still the protocol.

- [ ] **Step 3: Implement the Session naming and flatten its module**

Create `ISessionService.swift`:

```swift
nonisolated protocol ISessionService: Sendable {
    func currentSession() async throws -> UserSession?
    func signIn() async throws -> UserSession
    func signOut() async throws
}
```

Create `SessionService.swift` by preserving the existing actor behavior:

```swift
actor SessionService: ISessionService {
    private var session: UserSession?

    init(initialSession: UserSession?) {
        session = initialSession
    }

    func currentSession() -> UserSession? {
        session
    }

    func signIn() -> UserSession {
        let session = UserSession(
            id: "template-user",
            displayName: "Template User"
        )
        self.session = session
        return session
    }

    func signOut() {
        session = nil
    }
}
```

Rewrite `SessionDependencies`:

```swift
nonisolated struct SessionDependencies: Sendable {
    let service: any ISessionService

    init(service: any ISessionService) {
        self.service = service
    }
}
```

Change `SessionStore`'s stored property and initializer to
`any ISessionService`. Update `AppDependencies`:

```swift
SessionDependencies(service: SessionService(initialSession: nil))
SessionDependencies(service: SessionService(initialSession: session))

static func test(
    browseService: any IBrowseService,
    sessionService: any ISessionService
) -> AppDependencies
```

Make all Session test doubles conform to `ISessionService`. Replace every
production/test construction of `InMemorySessionService` with
`SessionService`.

Update composition checks without changing their lifetime assertions:

```swift
#expect(dependencies.session.service is SessionService)
let resolvedSessionService = try #require(
    dependencies.session.service as? InjectedSessionService
)
#expect(resolvedSessionService === sessionService)
```

- [ ] **Step 4: Run focused Session, feature, and composition tests**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/SessionServiceTests \
  -only-testing:AppTemplateTests/SessionStoreTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -only-testing:AppTemplateTests/AuthenticationViewModelTests \
  -only-testing:AppTemplateTests/SettingsViewModelTests
```

Expected: all selected tests pass.

- [ ] **Step 5: Verify obsolete Session names and subfolders are gone**

Run:

```bash
if rg -n 'InMemorySessionService|: SessionService\b|any SessionService\b' \
  AppTemplate AppTemplateTests; then
  exit 1
fi
test ! -d AppTemplate/App/Services/Session/Protocols
test ! -d AppTemplate/App/Services/Session/Implementations
test ! -d AppTemplate/App/Services/Session/Dependencies
test ! -d AppTemplate/App/Services/Session/Store
```

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate AppTemplateTests
git commit -m "refactor: adopt explicit session service interface"
```

---

### Task 3: Add the Inert Local Database Service Example

**Files:**
- Create:
  `AppTemplate/App/Services/LocalDatabase/ILocalDatabaseService.swift`
- Create:
  `AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift`
- Create:
  `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift`
- Verify unchanged:
  `AppTemplate/App/Composition/AppDependencies.swift`

**Interfaces:**
- Produces:
  `nonisolated protocol ILocalDatabaseService: Sendable {}`
- Produces:
  `actor LocalDatabaseService: ILocalDatabaseService`
- Does not produce: a property, registration, factory argument, or runtime
  instance in `AppDependencies`.

- [ ] **Step 1: Write the failing construction test**

Create `LocalDatabaseServiceTests.swift`:

```swift
import Testing
@testable import AppTemplate

struct LocalDatabaseServiceTests {
    @Test
    func concreteExampleSatisfiesTheEmptyInterface() {
        let service: any ILocalDatabaseService = LocalDatabaseService()

        #expect(service is LocalDatabaseService)
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
  -only-testing:AppTemplateTests/LocalDatabaseServiceTests
```

Expected: compilation fails because both LocalDatabase service types are
missing.

- [ ] **Step 3: Add the minimal compile-safe example**

Create:

```swift
nonisolated protocol ILocalDatabaseService: Sendable {}
```

and:

```swift
actor LocalDatabaseService: ILocalDatabaseService {}
```

Do not edit `AppDependencies`.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the Step 2 command again.

Expected: pass.

- [ ] **Step 5: Verify the example is absent from composition**

Run:

```bash
if rg -n 'LocalDatabase' AppTemplate/App/Composition; then
  exit 1
fi
```

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/App/Services/LocalDatabase \
  AppTemplateTests/App/Services/LocalDatabase
git commit -m "feat: add local database service template"
```

---

### Task 4: Centralize Domain Models and Reserve Local/Remote Models

**Files:**
- Move all files listed under `AppTemplate/App/Models/Domain` in the Final File
  Map.
- Extract:
  `NavigationGuideItem` from
  `AppTemplate/Features/Home/ViewModels/NavigationGuideViewModel.swift` into
  `AppTemplate/App/Models/Domain/NavigationGuideItem.swift`.
- Create: `AppTemplate/App/Models/Local/.gitkeep`
- Create: `AppTemplate/App/Models/Remote/.gitkeep`
- Modify only to remove the extracted declaration:
  `AppTemplate/Features/Home/ViewModels/NavigationGuideViewModel.swift`

**Interfaces:**
- Preserves every model type name, property, conformance, and initializer.
- Produces no Local or Remote Swift model.
- Route types are explicitly excluded from central model ownership.

- [ ] **Step 1: Run the structural guard and verify RED**

Run:

```bash
test -d AppTemplate/App/Models/Domain
test -f AppTemplate/App/Models/Domain/BrowseItem.swift
test -f AppTemplate/App/Models/Domain/UserSession.swift
test -f AppTemplate/App/Models/Domain/BrowseStoreState.swift
test -f AppTemplate/App/Models/Domain/NavigationGuideItem.swift
test -f AppTemplate/App/Models/Local/.gitkeep
test -f AppTemplate/App/Models/Remote/.gitkeep
```

Expected: non-zero because the new model ownership does not exist.

- [ ] **Step 2: Move the models without changing their declarations**

Use `git mv` for:

```text
Features/Browse/Domain/Models/BrowseItem.swift
    → App/Models/Domain/BrowseItem.swift
App/Services/Session/Models/UserSession.swift
    → App/Models/Domain/UserSession.swift
Features/Browse/ViewModels/BrowseStoreState.swift
    → App/Models/Domain/BrowseStoreState.swift
Features/Authentication/Domain/Models/AuthenticationModel.swift
    → App/Models/Domain/AuthenticationModel.swift
Features/Home/Domain/Models/HomeModel.swift
    → App/Models/Domain/HomeModel.swift
Features/Settings/Domain/Models/SettingsModel.swift
    → App/Models/Domain/SettingsModel.swift
```

Extract exactly:

```swift
nonisolated struct NavigationGuideItem:
    Identifiable,
    Equatable,
    Sendable {
    let id: String
    let title: String
    let systemImage: String
}
```

into `NavigationGuideItem.swift`, then remove that declaration from
`NavigationGuideViewModel.swift`. Add only `.gitkeep` files under Local and
Remote.

- [ ] **Step 3: Run the structural guard and focused model consumers**

Run the Step 1 guard again, then:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/BrowseViewModelTests \
  -only-testing:AppTemplateTests/HomeViewModelTests \
  -only-testing:AppTemplateTests/SessionStoreTests
```

Expected: guard exits 0 and all selected tests pass.

- [ ] **Step 4: Verify old model ownership is absent**

Run:

```bash
test ! -d AppTemplate/Features/Authentication/Domain/Models
test ! -d AppTemplate/Features/Browse/Domain/Models
test ! -d AppTemplate/Features/Home/Domain/Models
test ! -d AppTemplate/Features/Settings/Domain/Models
test ! -d AppTemplate/App/Services/Session/Models
```

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate
git commit -m "refactor: centralize application models"
```

---

### Task 5: Centralize Reusable UI Components

**Files:**
- Move:
  `AppTemplate/Features/Authentication/UI/Components/AuthenticationComponents.swift`
  → `AppTemplate/Utilities/UIComponents/AuthenticationComponents.swift`
- Move:
  `AppTemplate/Features/Browse/UI/Components/BrowseComponents.swift`
  → `AppTemplate/Utilities/UIComponents/BrowseComponents.swift`
- Move:
  `AppTemplate/Features/Home/UI/Components/HomeComponents.swift`
  → `AppTemplate/Utilities/UIComponents/HomeComponents.swift`
- Move:
  `AppTemplate/Features/Settings/UI/Components/SettingsComponents.swift`
  → `AppTemplate/Utilities/UIComponents/SettingsComponents.swift`

**Interfaces:**
- Preserves the four compile-safe component extension-point type names.
- Each type remains independent of screens, ViewModels, Routers, Routes, and
  application DI.

- [ ] **Step 1: Run the ownership guard and verify RED**

Run:

```bash
for component in Authentication Browse Home Settings; do
  test -f "AppTemplate/Utilities/UIComponents/${component}Components.swift"
done
for feature in Authentication Browse Home Settings; do
  test ! -d "AppTemplate/Features/$feature/UI"
done
```

Expected: non-zero because the files are still feature-owned.

- [ ] **Step 2: Move all component extension points**

Use `git mv` for the four paths above. Do not change their declarations.

- [ ] **Step 3: Verify ownership and independence**

Run the Step 1 guard, then:

```bash
if rg -n 'ViewModel|Router|Route|AppDependencies|Dependencies' \
  AppTemplate/Utilities/UIComponents; then
  exit 1
fi
xcodebuild build -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS'
```

Expected: guards exit 0 and Debug build passes.

- [ ] **Step 4: Commit**

```bash
git add AppTemplate
git commit -m "refactor: centralize reusable ui components"
```

---

### Task 6: Create the Authentication Screen Capsule

**Files:**
- Move:
  `AppTemplate/Features/Authentication/Screens/AuthenticationView.swift` →
  `AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift`
- Move:
  `AppTemplate/Features/Authentication/ViewModels/AuthenticationViewModel.swift`
  →
  `AppTemplate/Features/Authentication/Screens/Authentication/ViewModel/AuthenticationViewModel.swift`
- Move:
  `AppTemplateTests/Features/Authentication/AuthenticationViewModelTests.swift`
  →
  `AppTemplateTests/Features/Authentication/Screens/Authentication/AuthenticationViewModelTests.swift`
- Delete obsolete empty Authentication Repository and Service files if Task 1
  did not already remove them.

**Interfaces:**
- Preserves `AuthenticationView`, `AuthenticationViewModel`, `AppRouter`, and
  `SessionStore` behavior.
- Does not create an Authentication Router or Route.

- [ ] **Step 1: Run the capsule guard and verify RED**

Run:

```bash
test -f AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift
test -f AppTemplate/Features/Authentication/Screens/Authentication/ViewModel/AuthenticationViewModel.swift
test -f AppTemplateTests/Features/Authentication/Screens/Authentication/AuthenticationViewModelTests.swift
```

Expected: non-zero.

- [ ] **Step 2: Move production and test files**

Use the exact move map above. Do not edit Swift declarations.

- [ ] **Step 3: Run the focused behavior tests and capsule guard**

Run the Step 1 guard, then:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AuthenticationViewModelTests
```

Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add AppTemplate/Features/Authentication \
  AppTemplateTests/Features/Authentication
git commit -m "refactor: create authentication screen capsule"
```

---

### Task 7: Create Browse Screen Capsules and Split Their Tests

**Files:**
- Move Browse View, ViewModel, Route, and test files to the Final File Map.
- Keep:
  `AppTemplate/Features/Browse/Navigation/BrowseRouter.swift`
- Create:
  `AppTemplateTests/Features/Browse/Screens/Browse/BrowseListViewModelTests.swift`
- Create:
  `AppTemplateTests/Features/Browse/Screens/BrowseDetail/BrowseDetailViewModelTests.swift`
- Create:
  `AppTemplateTests/Features/Browse/TestSupport/BrowseServiceDoubles.swift`
- Delete after splitting:
  `AppTemplateTests/Features/Browse/BrowseViewModelTests.swift`

**Interfaces:**
- Browse feature Router stays feature-owned.
- `BrowseRoute` moves beside `BrowseNavigationView`.
- List and detail ViewModel types, methods, state transitions, and cancellation
  behavior remain unchanged.

- [ ] **Step 1: Run the Browse capsule guard and verify RED**

Run:

```bash
test -f AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift
test -f AppTemplate/Features/Browse/Screens/Browse/ViewModel/BrowseListViewModel.swift
test -f AppTemplate/Features/Browse/Screens/Browse/Navigation/BrowseRoute.swift
test -f AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift
test -f AppTemplate/Features/Browse/Screens/BrowseDetail/ViewModel/BrowseDetailViewModel.swift
test -f AppTemplateTests/Features/Browse/Screens/Browse/BrowseListViewModelTests.swift
test -f AppTemplateTests/Features/Browse/Screens/BrowseDetail/BrowseDetailViewModelTests.swift
```

Expected: non-zero.

- [ ] **Step 2: Move Browse production files**

Apply this exact map:

```text
Screens/BrowseNavigationView.swift
    → Screens/Browse/View/BrowseNavigationView.swift
ViewModels/BrowseListViewModel.swift
    → Screens/Browse/ViewModel/BrowseListViewModel.swift
Navigation/BrowseRoute.swift
    → Screens/Browse/Navigation/BrowseRoute.swift
Screens/BrowseDetailView.swift
    → Screens/BrowseDetail/View/BrowseDetailView.swift
ViewModels/BrowseDetailViewModel.swift
    → Screens/BrowseDetail/ViewModel/BrowseDetailViewModel.swift
```

Leave `Navigation/BrowseRouter.swift` where it is.

- [ ] **Step 3: Split tests by screen without changing assertions**

Move list tests into `BrowseListViewModelTests`:

```text
listLoadsServiceItems
listFailureProducesDisplaySafeFailure
cancelledListLoadDoesNotPublishNonCooperativeResponse
cancelledListLoadTreatsOrdinaryServiceErrorAsCancellation
replacementListLoadCancelsAndRejectsStaleResponse
browseListScreenUsesScopedDependencies
```

Move detail tests into `BrowseDetailViewModelTests`:

```text
detailLoadsByStableIdentifier
missingDetailProducesNotFound
serviceFailureProducesDisplaySafeFailure
replacementDetailLoadCancelsAndRejectsStaleResponse
cancelledDetailLoadDoesNotPublishNonCooperativeResponse
cancelledDetailLoadTreatsOrdinaryServiceErrorAsCancellation
retryThenDestinationCancellationCancelsOwnedLoad
browseDetailScreenUsesScopedDependencies
```

Move the renamed `BrowseServiceTestError`, `FailingBrowseService`, and
`ControlledBrowseService` declarations unchanged into
`BrowseServiceDoubles.swift`, removing `private` so both screen suites can use
them. Delete the old combined test file only after both new suites compile.

- [ ] **Step 4: Run both Browse suites and guard**

Run the Step 1 guard, then:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/BrowseListViewModelTests \
  -only-testing:AppTemplateTests/BrowseDetailViewModelTests \
  -only-testing:AppTemplateTests/BrowseServiceTests
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Browse AppTemplateTests/Features/Browse
git commit -m "refactor: create browse screen capsules"
```

---

### Task 8: Create Home Screen Capsules and Split Their Tests

**Files:**
- Move all Home screen files according to the Final File Map.
- Keep: `AppTemplate/Features/Home/Navigation/HomeRouter.swift`
- Create:
  `AppTemplateTests/Features/Home/Screens/Home/HomeViewModelTests.swift`
- Create:
  `AppTemplateTests/Features/Home/Screens/HomeDetails/HomeDetailsViewModelTests.swift`
- Create:
  `AppTemplateTests/Features/Home/Screens/NavigationGuide/NavigationGuideViewModelTests.swift`
- Delete after splitting:
  `AppTemplateTests/Features/Home/HomeViewModelTests.swift`

**Interfaces:**
- `HomeRouter` stays feature-owned.
- `HomeRoute`, `HomeSheet`, and `HomeAlert` move together beside the Home
  navigation screen.
- All Home ViewModel presentation and Router mutation behavior stays unchanged.

- [ ] **Step 1: Run the Home capsule guard and verify RED**

Run:

```bash
for file in \
  AppTemplate/Features/Home/Screens/Home/View/HomeView.swift \
  AppTemplate/Features/Home/Screens/Home/ViewModel/HomeViewModel.swift \
  AppTemplate/Features/Home/Screens/Home/Navigation/HomeRoute.swift \
  AppTemplate/Features/Home/Screens/HomeDetails/View/HomeDetailsView.swift \
  AppTemplate/Features/Home/Screens/HomeDetails/ViewModel/HomeDetailsViewModel.swift \
  AppTemplate/Features/Home/Screens/NavigationGuide/View/NavigationGuideView.swift \
  AppTemplate/Features/Home/Screens/NavigationGuide/ViewModel/NavigationGuideViewModel.swift; do
  test -f "$file"
done
```

Expected: non-zero.

- [ ] **Step 2: Move Home production files**

Use the exact Final File Map. Do not change type names or implementation.
Leave `HomeRouter.swift` under feature `Navigation`; move `HomeRoute.swift`
under `Screens/Home/Navigation`.

- [ ] **Step 3: Split Home tests by screen**

`HomeViewModelTests` keeps:

```text
userIntentsDriveTheHomeRouter
confirmedResetClearsOnlyHomePresentationState
dismissingResetBindingClearsTheAlert
homeScreenCanBeConstructed
```

`HomeDetailsViewModelTests` contains:

```text
detailsExposePresentationModel
homeDetailsScreenCanBeConstructed
```

The presentation test must retain:

```swift
let details = HomeDetailsViewModel()
#expect(details.title == "Typed Destination")
#expect(details.message == "HomeRoute.details produced this screen.")
```

`NavigationGuideViewModelTests` contains:

```text
guideExposesPresentationItems
navigationGuideScreenCanBeConstructed
```

The items assertion remains:

```swift
#expect(guide.items.map(\.title) == [
    "Typed paths",
    "Independent tabs",
    "Scene restoration"
])
```

- [ ] **Step 4: Run focused Home tests and guard**

Run the Step 1 guard, then:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/HomeViewModelTests \
  -only-testing:AppTemplateTests/HomeDetailsViewModelTests \
  -only-testing:AppTemplateTests/NavigationGuideViewModelTests
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Home AppTemplateTests/Features/Home
git commit -m "refactor: create home screen capsules"
```

---

### Task 9: Create Settings Screen Capsules and Split Their Tests

**Files:**
- Move all Settings screen files according to the Final File Map.
- Keep: `AppTemplate/Features/Settings/Navigation/SettingsRouter.swift`
- Create:
  `AppTemplateTests/Features/Settings/Screens/Settings/SettingsViewModelTests.swift`
- Create:
  `AppTemplateTests/Features/Settings/Screens/About/AboutViewModelTests.swift`
- Delete after splitting:
  `AppTemplateTests/Features/Settings/SettingsViewModelTests.swift`

**Interfaces:**
- `SettingsRouter` stays feature-owned.
- `SettingsRoute` moves beside `SettingsNavigationView`.
- Settings continues to observe and mutate the app-scoped `SessionStore`.
- About presentation data stays unchanged.

- [ ] **Step 1: Run the Settings capsule guard and verify RED**

Run:

```bash
for file in \
  AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift \
  AppTemplate/Features/Settings/Screens/Settings/ViewModel/SettingsViewModel.swift \
  AppTemplate/Features/Settings/Screens/Settings/Navigation/SettingsRoute.swift \
  AppTemplate/Features/Settings/Screens/About/View/AboutView.swift \
  AppTemplate/Features/Settings/Screens/About/ViewModel/AboutViewModel.swift; do
  test -f "$file"
done
```

Expected: non-zero.

- [ ] **Step 2: Move Settings production files**

Use the Final File Map. Keep `SettingsRouter.swift` feature-owned and move
`SettingsRoute.swift` under `Screens/Settings/Navigation`.

- [ ] **Step 3: Split Settings tests by screen**

`SettingsViewModelTests` keeps:

```text
settingsReflectsAndMutatesTheSharedSession
failedSignOutExposesSafeFailureAndKeepsTheSession
settingsScreenCanBeConstructed
```

Keep `SettingsViewModelTestError` and `FailingSettingsSessionService` in that
file, with the fake conforming to `ISessionService`.

`AboutViewModelTests` contains:

```text
aboutProvidesSupportedPlatformPresentation
aboutScreenCanBeConstructed
```

Preserve the exact platform array and example-description assertions.

- [ ] **Step 4: Run focused Settings tests and guard**

Run the Step 1 guard, then:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/SettingsViewModelTests \
  -only-testing:AppTemplateTests/AboutViewModelTests
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Settings AppTemplateTests/Features/Settings
git commit -m "refactor: create settings screen capsules"
```

---

### Task 10: Remove Obsolete Layers, Update Documentation, and Verify

**Files:**
- Modify: `README.md`
- Modify only if synchronized-group exceptions changed:
  `AppTemplate.xcodeproj/project.pbxproj`
- Move/update any remaining tests to match the approved production ownership.
- Remove all remaining obsolete empty feature directories.

**Interfaces:**
- Documents the Service-only DI and Screen Capsule conventions.
- Preserves resources, URL scheme, navigation snapshots, deep links, and all
  supported destinations.
- Produces a clean tree with no Repository type or obsolete loose screen file.

- [ ] **Step 1: Run the complete structural guard and verify RED before final cleanup**

Run:

```bash
set -e

for directory in \
  AppTemplate/App/Models/Domain \
  AppTemplate/App/Models/Local \
  AppTemplate/App/Models/Remote \
  AppTemplate/App/Services/Browse \
  AppTemplate/App/Services/Session \
  AppTemplate/App/Services/LocalDatabase \
  AppTemplate/Utilities/UIComponents; do
  test -d "$directory"
done

for feature in Authentication Browse Home Settings; do
  for obsolete in Data Domain Services UI ViewModels; do
    test ! -e "AppTemplate/Features/$feature/$obsolete"
  done
done

test ! -e AppTemplate/App/Repositories

if rg -n 'Repository|InMemoryBrowse|InMemorySession|any SessionService\b' \
  AppTemplate AppTemplateTests; then
  exit 1
fi
```

Expected before final cleanup: non-zero if any stale name, loose directory, or
test double remains.

- [ ] **Step 2: Remove only remaining obsolete files/directories**

Use `apply_patch` for stale file deletion and `rmdir` only for explicitly
verified empty directories. Do not delete historical design or plan documents;
they describe earlier decisions. Confirm every current production and test
source is represented in the Final File Map or existing app navigation/project
ownership.

- [ ] **Step 3: Rewrite the current README architecture sections**

Update `Project Structure` to state:

```markdown
- `App/Models/Domain` owns shared application and presentation models.
- `App/Models/Local` and `App/Models/Remote` are reserved for database records
  and API DTOs.
- `App/Services` owns `I<ServiceName>` contracts and concrete
  `<ServiceName>` implementations.
- `Features/<Feature>/Screens/<Screen>` owns each screen's View and ViewModel.
- Feature Routers remain in `Features/<Feature>/Navigation`; Routes live with
  the navigation-owning screen.
- `Utilities/UIComponents` contains reusable UI independent from screens.
- There is no Repository layer.
```

Update `Dependency Injection` examples to use:

```swift
dependencies.browse.service
any IBrowseService
any ISessionService
BrowseService
SessionService
```

Document that `ILocalDatabaseService`/`LocalDatabaseService` are inert template
examples and are not registered in production DI.

- [ ] **Step 4: Run focused project and navigation regression tests**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ProjectConfigurationTests \
  -only-testing:AppTemplateTests/AppRouterTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests \
  -only-testing:AppTemplateTests/DeepLinkParserTests \
  -only-testing:AppTemplateTests/NavigationSnapshotTests \
  -only-testing:AppTemplateTests/StackRoutingTests
```

Expected: all selected tests pass.

- [ ] **Step 5: Run final structural and text checks**

Run the Step 1 structural guard again, then:

```bash
test -f AppTemplate/Resources/Info.plist
test -d AppTemplate/Resources/Assets.xcassets

if rg -n 'ObservableObject|@Published|@StateObject|BaseViewModel|\.resolve\(' \
  AppTemplate; then
  exit 1
fi

if rg -n 'AppDependencies' AppTemplate/Features/*/Screens/*/ViewModel; then
  exit 1
fi

git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 6: Run the complete macOS test suite**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS'
```

Expected: exit 0.

- [ ] **Step 7: Run the complete iOS 26 test suite**

Resolve an installed iOS 26 Simulator using `xcodebuild -showdestinations`,
then run, substituting only the installed OS patch version:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: exit 0.

- [ ] **Step 8: Run Release builds**

Run:

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

Expected: both exit 0.

- [ ] **Step 9: Commit**

```bash
git add README.md AppTemplate AppTemplateTests AppTemplate.xcodeproj
git commit -m "docs: explain screen capsule service architecture"
```

- [ ] **Step 10: Review the complete branch**

Run:

```bash
git status --short --branch
git diff --check main...HEAD
git diff --stat main...HEAD
git log --oneline --decorate main..HEAD
```

Expected: clean feature branch containing only the approved architecture
migration and its documentation.
