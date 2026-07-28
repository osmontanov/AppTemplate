# Feature-Scoped ViewModel Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every full user-facing screen a concrete Observation-based ViewModel while integrating feature-scoped DI, scene-scoped navigation, app-wide session state, and async services without introducing a service locator or base ViewModel framework.

**Architecture:** `AppDependencies` composes immutable `BrowseDependencies` and `SessionDependencies`. Routers remain scene-scoped and own all navigation state; Views bind routers and own one screen ViewModel through `@State`; ViewModels receive only their feature dependency scope, shared store, or router when actually needed. Network and future local-database details remain behind repository/service protocols.

**Tech Stack:** Swift 5 language mode with Xcode 26 approachable concurrency, SwiftUI, Observation (`@Observable`, `@State`, `@Bindable`), Swift Concurrency (`async`/`await`, actors, `Sendable`), Swift Testing, XcodeBuild.

## Global Constraints

- Deployment targets remain exactly iOS 26.0, iPadOS 26.0, and macOS 26.0.
- The project remains dependency-free; add no third-party framework.
- Every full user-facing screen gets one concrete `@MainActor @Observable final class` ViewModel.
- `AppSceneView`, `AppRootView`, `AppShellView`, routers, lifecycle objects, and small stateless subviews do not get artificial ViewModels.
- An owning View stores its non-optional ViewModel in private `@State`.
- No ViewModel receives `AppDependencies` or performs a SwiftUI Environment lookup.
- Routers remain scene-scoped and remain the only owners of typed navigation paths and presentations.
- Deep links and snapshots remain independent of ViewModels and domain-data availability.
- Browse cancellation, retry, and stale-response protections must remain behaviorally unchanged.
- `SessionStore` remains app-wide and retains startup coalescing and command-version safeguards.
- Use test-first RED/GREEN cycles for every production behavior change.
- The Xcode project uses file-system-synchronized groups, so new Swift files require no manual `project.pbxproj` entries.

## File Structure

### Dependency scopes

- Create `AppTemplate/Features/Browse/Domain/BrowseDependencies.swift`: immutable Browse service scope.
- Create `AppTemplate/Core/Session/SessionDependencies.swift`: immutable Session service scope.
- Modify `AppTemplate/App/Dependencies/AppDependencies.swift`: compose the two feature scopes.

### Browse

- Rename `AppTemplate/Features/Browse/Presentation/BrowseListStore.swift` to `BrowseListViewModel.swift`.
- Rename `AppTemplate/Features/Browse/Presentation/BrowseDetailStore.swift` to `BrowseDetailViewModel.swift`.
- Rename `AppTemplate/Features/Browse/BrowseView.swift` to `BrowseNavigationView.swift`.
- Create `AppTemplate/Features/Browse/BrowseDetailView.swift`: detail-screen layout and lifecycle.
- Rename `AppTemplateTests/BrowseStoreTests.swift` to `BrowseViewModelTests.swift`.

### Home

- Create `AppTemplate/Features/Home/Presentation/HomeViewModel.swift`.
- Create `AppTemplate/Features/Home/Presentation/HomeDetailsViewModel.swift`.
- Create `AppTemplate/Features/Home/Presentation/NavigationGuideViewModel.swift`.
- Create `AppTemplate/Features/Home/HomeDetailsView.swift`.
- Create `AppTemplate/Features/Home/NavigationGuideView.swift`.
- Modify `AppTemplate/Features/Home/HomeView.swift`: retain only `HomeNavigationView`.
- Create `AppTemplateTests/HomeViewModelTests.swift`.

### Authentication

- Create `AppTemplate/App/Authentication/AuthenticationViewModel.swift`.
- Create `AppTemplate/App/Authentication/AuthenticationView.swift`.
- Modify `AppTemplate/App/Navigation/AppRootView.swift`: compose `AuthenticationView`.
- Create `AppTemplateTests/AuthenticationViewModelTests.swift`.

### Settings

- Create `AppTemplate/Features/Settings/Presentation/SettingsViewModel.swift`.
- Create `AppTemplate/Features/Settings/Presentation/AboutViewModel.swift`.
- Create `AppTemplate/Features/Settings/AboutView.swift`.
- Modify `AppTemplate/Features/Settings/SettingsView.swift`: retain only `SettingsNavigationView`.
- Modify `AppTemplate/App/Navigation/AppShellView.swift`: pass shared session state explicitly.
- Create `AppTemplateTests/SettingsViewModelTests.swift`.

### Integration and documentation

- Modify `AppTemplate/AppTemplateApp.swift`.
- Modify `AppTemplate/ContentView.swift`.
- Modify `AppTemplateTests/AppDependenciesTests.swift`.
- Modify `AppTemplateTests/ProjectConfigurationTests.swift`.
- Modify `README.md`.

---

### Task 1: Introduce Feature-Scoped Dependency Values

**Files:**
- Create: `AppTemplate/Features/Browse/Domain/BrowseDependencies.swift`
- Create: `AppTemplate/Core/Session/SessionDependencies.swift`
- Modify: `AppTemplate/App/Dependencies/AppDependencies.swift`
- Modify: `AppTemplate/AppTemplateApp.swift`
- Modify: `AppTemplate/ContentView.swift`
- Modify: `AppTemplate/App/Navigation/AppShellView.swift`
- Modify: `AppTemplateTests/AppDependenciesTests.swift`
- Modify: `AppTemplateTests/ProjectConfigurationTests.swift`

**Interfaces:**
- Produces: `BrowseDependencies.init(repository:)`
- Produces: `SessionDependencies.init(service:)`
- Produces: `AppDependencies.browse: BrowseDependencies`
- Produces: `AppDependencies.session: SessionDependencies`
- Preserves: `AppDependencies.live()`, `preview(browseItems:session:)`, and `test(browseRepository:sessionService:)`

- [ ] **Step 1: Change dependency tests to require scoped access**

Update the three tests in `AppDependenciesTests.swift` so all service access goes through the feature scopes:

```swift
let items = try await dependencies.browse.repository.items()
let session = try await dependencies.session.service.currentSession()

#expect(dependencies.browse.repository is InMemoryBrowseRepository)
#expect(dependencies.session.service is InMemorySessionService)
```

In the injected-service test, use:

```swift
let resolvedRepository = try #require(
    dependencies.browse.repository as? InjectedBrowseRepository
)
let resolvedService = try #require(
    dependencies.session.service as? InjectedSessionService
)
```

- [ ] **Step 2: Run the scoped dependency tests and verify RED**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `AppDependencies` has no `browse` or `session` scoped properties.

- [ ] **Step 3: Add the minimal scoped dependency types**

Create `BrowseDependencies.swift`:

```swift
nonisolated struct BrowseDependencies: Sendable {
    let repository: any BrowseRepository

    init(repository: any BrowseRepository) {
        self.repository = repository
    }
}
```

Create `SessionDependencies.swift`:

```swift
nonisolated struct SessionDependencies: Sendable {
    let service: any SessionService

    init(service: any SessionService) {
        self.service = service
    }
}
```

Replace `AppDependencies` fields and initializer with:

```swift
nonisolated struct AppDependencies: Sendable {
    let browse: BrowseDependencies
    let session: SessionDependencies

    init(
        browse: BrowseDependencies,
        session: SessionDependencies
    ) {
        self.browse = browse
        self.session = session
    }
}
```

Keep the public factory signatures stable and build the scopes inside them:

```swift
static func live() -> AppDependencies {
    AppDependencies(
        browse: BrowseDependencies(
            repository: InMemoryBrowseRepository.live()
        ),
        session: SessionDependencies(
            service: InMemorySessionService(initialSession: nil)
        )
    )
}
```

Implement the remaining factories explicitly:

```swift
static func preview(
    browseItems: [BrowseItem],
    session: UserSession?
) -> AppDependencies {
    AppDependencies(
        browse: BrowseDependencies(
            repository: InMemoryBrowseRepository(items: browseItems)
        ),
        session: SessionDependencies(
            service: InMemorySessionService(initialSession: session)
        )
    )
}

static func test(
    browseRepository: any BrowseRepository,
    sessionService: any SessionService
) -> AppDependencies {
    AppDependencies(
        browse: BrowseDependencies(
            repository: browseRepository
        ),
        session: SessionDependencies(
            service: sessionService
        )
    )
}
```

Update application call sites:

```swift
SessionStore(service: dependencies.session.service)
```

Until Task 2 changes the Browse View initializer, keep `AppShellView` compiling with:

```swift
BrowseNavigationView(
    router: router.browse,
    repository: dependencies.browse.repository
)
```

Update `ProjectConfigurationTests` to use `dependencies.session.service` and `dependencies.browse.repository`.

- [ ] **Step 4: Run scoped DI tests and the existing suite**

Run the targeted macOS test command from Step 2.

Expected: `AppDependenciesTests` passes.

Then run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all existing tests pass.

- [ ] **Step 5: Commit the scoped DI foundation**

```bash
git add \
  AppTemplate/App/Dependencies/AppDependencies.swift \
  AppTemplate/AppTemplateApp.swift \
  AppTemplate/ContentView.swift \
  AppTemplate/App/Navigation/AppShellView.swift \
  AppTemplate/Core/Session/SessionDependencies.swift \
  AppTemplate/Features/Browse/Domain/BrowseDependencies.swift \
  AppTemplateTests/AppDependenciesTests.swift \
  AppTemplateTests/ProjectConfigurationTests.swift
git commit -m "refactor: scope application dependencies by feature"
```

### Task 2: Convert Browse Stores into Screen ViewModels

**Files:**
- Rename: `AppTemplate/Features/Browse/Presentation/BrowseListStore.swift` → `AppTemplate/Features/Browse/Presentation/BrowseListViewModel.swift`
- Rename: `AppTemplate/Features/Browse/Presentation/BrowseDetailStore.swift` → `AppTemplate/Features/Browse/Presentation/BrowseDetailViewModel.swift`
- Rename: `AppTemplate/Features/Browse/BrowseView.swift` → `AppTemplate/Features/Browse/BrowseNavigationView.swift`
- Create: `AppTemplate/Features/Browse/BrowseDetailView.swift`
- Modify: `AppTemplate/App/Navigation/AppShellView.swift`
- Rename: `AppTemplateTests/BrowseStoreTests.swift` → `AppTemplateTests/BrowseViewModelTests.swift`
- Modify: `AppTemplateTests/ProjectConfigurationTests.swift`

**Interfaces:**
- Consumes: `BrowseDependencies`
- Produces: `BrowseListViewModel.init(dependencies:)`
- Produces: `BrowseDetailViewModel.init(id:dependencies:)`
- Produces: `BrowseNavigationView.init(router:dependencies:)`
- Produces: `BrowseDetailView.init(id:dependencies:)`
- Preserves: `BrowseListState`, `BrowseDetailState`, `load()`, `retry()`, and `cancel()`

- [ ] **Step 1: Rename the Browse test file and require the new API**

Rename the test file and suite:

```text
BrowseStoreTests.swift       → BrowseViewModelTests.swift
BrowseStoreTests             → BrowseViewModelTests
BrowseListStore              → BrowseListViewModel
BrowseDetailStore            → BrowseDetailViewModel
```

Wrap every test repository in `BrowseDependencies`:

```swift
let viewModel = BrowseListViewModel(
    dependencies: BrowseDependencies(
        repository: InMemoryBrowseRepository(items: [item])
    )
)
```

Use the name `viewModel` instead of `store` throughout the renamed test suite.

Add a screen-construction test:

```swift
@Test
func browseScreensUseScopedDependencies() {
    let dependencies = BrowseDependencies(
        repository: InMemoryBrowseRepository(items: [])
    )

    _ = BrowseNavigationView(
        router: BrowseRouter(),
        dependencies: dependencies
    )
    _ = BrowseDetailView(
        id: "swiftui",
        dependencies: dependencies
    )
}
```

- [ ] **Step 2: Run Browse tests and verify RED**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/BrowseViewModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because the ViewModel types and scoped View initializers do not exist.

- [ ] **Step 3: Rename the production types without changing async behavior**

Rename the two production files and classes:

```text
BrowseListStore       → BrowseListViewModel
BrowseDetailStore     → BrowseDetailViewModel
```

Replace each stored repository with:

```swift
private let dependencies: BrowseDependencies
```

Use these initializers:

```swift
init(dependencies: BrowseDependencies) {
    self.dependencies = dependencies
}
```

```swift
init(
    id: BrowseItem.ID,
    dependencies: BrowseDependencies
) {
    self.id = id
    self.dependencies = dependencies
}
```

At task creation, capture the exact repository:

```swift
let repository = dependencies.repository
```

Do not change request-version checks, cancellation handlers, task ownership, state transitions, or error mapping.

- [ ] **Step 4: Split and wire the Browse Views**

Rename `BrowseView.swift` to `BrowseNavigationView.swift`.

The list screen owns its ViewModel:

```swift
struct BrowseNavigationView: View {
    @Bindable var router: BrowseRouter
    @State private var viewModel: BrowseListViewModel
    private let dependencies: BrowseDependencies

    init(
        router: BrowseRouter,
        dependencies: BrowseDependencies
    ) {
        self.router = router
        self.dependencies = dependencies
        _viewModel = State(
            initialValue: BrowseListViewModel(
                dependencies: dependencies
            )
        )
    }
}
```

Replace all list `store` reads and actions with `viewModel`.

Keep:

```swift
.task {
    await viewModel.load()
}
.onDisappear {
    viewModel.cancel()
}
```

Move `BrowseDetailView` into its own internal file and give it:

```swift
struct BrowseDetailView: View {
    @State private var viewModel: BrowseDetailViewModel

    init(
        id: BrowseItem.ID,
        dependencies: BrowseDependencies
    ) {
        _viewModel = State(
            initialValue: BrowseDetailViewModel(
                id: id,
                dependencies: dependencies
            )
        )
    }
}
```

The destination mapping becomes:

```swift
BrowseDetailView(
    id: id,
    dependencies: dependencies
)
```

Update `AppShellView`:

```swift
BrowseNavigationView(
    router: router.browse,
    dependencies: dependencies.browse
)
```

Update `ProjectConfigurationTests` to construct Browse with `dependencies.browse`.

- [ ] **Step 5: Run Browse tests and the full macOS suite**

Run the targeted command from Step 2.

Expected: all Browse ViewModel tests pass with the same concurrency coverage as before.

Then run the full macOS test command from Task 1.

Expected: all tests pass.

- [ ] **Step 6: Commit the Browse ViewModel conversion**

```bash
git add -A \
  AppTemplate/Features/Browse \
  AppTemplate/App/Navigation/AppShellView.swift \
  AppTemplateTests/BrowseViewModelTests.swift \
  AppTemplateTests/ProjectConfigurationTests.swift
git commit -m "refactor: model browse screens with view models"
```

### Task 3: Add ViewModels for Every Home Screen

**Files:**
- Create: `AppTemplate/Features/Home/Presentation/HomeViewModel.swift`
- Create: `AppTemplate/Features/Home/Presentation/HomeDetailsViewModel.swift`
- Create: `AppTemplate/Features/Home/Presentation/NavigationGuideViewModel.swift`
- Create: `AppTemplate/Features/Home/HomeDetailsView.swift`
- Create: `AppTemplate/Features/Home/NavigationGuideView.swift`
- Modify: `AppTemplate/Features/Home/HomeView.swift`
- Create: `AppTemplateTests/HomeViewModelTests.swift`

**Interfaces:**
- Produces: `HomeViewModel.init(router:)`
- Produces: Home navigation, sheet, alert, and reset intent methods
- Produces: `HomeDetailsViewModel.init()`
- Produces: `NavigationGuideViewModel.init()`
- Produces: internal constructible `HomeDetailsView` and `NavigationGuideView`

- [ ] **Step 1: Write failing Home ViewModel tests**

Create `HomeViewModelTests.swift`:

```swift
import Testing
@testable import AppTemplate

@MainActor
struct HomeViewModelTests {
    @Test
    func userIntentsDriveTheHomeRouter() {
        let router = HomeRouter()
        let viewModel = HomeViewModel(router: router)

        viewModel.openDetails()
        #expect(router.path == [.details])

        viewModel.openNavigationGuide()
        #expect(router.sheet == .navigationGuide)

        viewModel.requestNavigationReset()
        #expect(router.alert == .resetNavigation)
        #expect(viewModel.isResetAlertPresented)

        viewModel.cancelNavigationReset()
        #expect(router.alert == nil)
    }

    @Test
    func confirmedResetClearsOnlyHomePresentationState() {
        let router = HomeRouter(
            path: [.details],
            sheet: .navigationGuide,
            alert: .resetNavigation
        )
        let viewModel = HomeViewModel(router: router)

        viewModel.confirmNavigationReset()

        #expect(router.path.isEmpty)
        #expect(router.alert == nil)
        #expect(router.sheet == .navigationGuide)
    }

    @Test
    func dismissingResetBindingClearsTheAlert() {
        let router = HomeRouter(alert: .resetNavigation)
        let viewModel = HomeViewModel(router: router)

        viewModel.isResetAlertPresented = false

        #expect(router.alert == nil)
    }

    @Test
    func staticHomeScreensExposePresentationModels() {
        let details = HomeDetailsViewModel()
        let guide = NavigationGuideViewModel()

        #expect(details.title == "Typed Destination")
        #expect(details.message == "HomeRoute.details produced this screen.")
        #expect(guide.items.map(\.title) == [
            "Typed paths",
            "Independent tabs",
            "Scene restoration"
        ])
    }

    @Test
    func everyHomeScreenCanBeConstructed() {
        _ = HomeNavigationView(router: HomeRouter())
        _ = HomeDetailsView()
        _ = NavigationGuideView()
    }
}
```

- [ ] **Step 2: Run Home tests and verify RED**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/HomeViewModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because the three ViewModels and two internal screen types do not exist.

- [ ] **Step 3: Implement the Home ViewModels**

Create `HomeViewModel.swift`:

```swift
import Observation

@MainActor
@Observable
final class HomeViewModel {
    let router: HomeRouter

    var isResetAlertPresented: Bool {
        get { router.alert != nil }
        set {
            if !newValue {
                router.alert = nil
            }
        }
    }

    init(router: HomeRouter) {
        self.router = router
    }

    func openDetails() {
        router.push(.details)
    }

    func openNavigationGuide() {
        router.sheet = .navigationGuide
    }

    func requestNavigationReset() {
        router.alert = .resetNavigation
    }

    func confirmNavigationReset() {
        router.popToRoot()
        router.alert = nil
    }

    func cancelNavigationReset() {
        router.alert = nil
    }
}
```

Create `HomeDetailsViewModel.swift`:

```swift
import Observation

@MainActor
@Observable
final class HomeDetailsViewModel {
    let title = "Typed Destination"
    let systemImage = "point.topleft.down.to.point.bottomright.curvepath"
    let message = "HomeRoute.details produced this screen."
}
```

Create `NavigationGuideViewModel.swift`:

```swift
import Observation

nonisolated struct NavigationGuideItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemImage: String
}

@MainActor
@Observable
final class NavigationGuideViewModel {
    let title = "Navigation Guide"
    let items = [
        NavigationGuideItem(
            id: "typed-paths",
            title: "Typed paths",
            systemImage: "list.bullet.rectangle"
        ),
        NavigationGuideItem(
            id: "independent-tabs",
            title: "Independent tabs",
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

- [ ] **Step 4: Refactor Home Views to own the ViewModels**

`HomeNavigationView` owns:

```swift
@State private var viewModel: HomeViewModel

init(router: HomeRouter) {
    _viewModel = State(
        initialValue: HomeViewModel(router: router)
    )
}
```

At the start of `body`, create bindings:

```swift
@Bindable var router = viewModel.router
@Bindable var bindableViewModel = viewModel
```

Route every button through the named ViewModel methods. Bind the alert with:

```swift
.alert(
    "Reset Home navigation?",
    isPresented: $bindableViewModel.isResetAlertPresented
)
```

Use `viewModel.confirmNavigationReset()` and `viewModel.cancelNavigationReset()` in alert actions.

Move the details and guide screens to their new files. Each owns a non-optional `@State` ViewModel initialized synchronously:

```swift
@State private var viewModel: HomeDetailsViewModel

init() {
    _viewModel = State(
        initialValue: HomeDetailsViewModel()
    )
}
```

```swift
@State private var viewModel: NavigationGuideViewModel

init() {
    _viewModel = State(
        initialValue: NavigationGuideViewModel()
    )
}
```

Render the current strings and symbols from the ViewModels. Keep `@Environment(\.dismiss)` in `NavigationGuideView`.

- [ ] **Step 5: Run Home tests and the full macOS suite**

Run the targeted command from Step 2, then the full macOS command from Task 1.

Expected: all Home tests and all existing tests pass.

- [ ] **Step 6: Commit the Home ViewModels**

```bash
git add \
  AppTemplate/Features/Home \
  AppTemplateTests/HomeViewModelTests.swift
git commit -m "feat: add view models for home screens"
```

### Task 4: Add Authentication ViewModel and Screen

**Files:**
- Create: `AppTemplate/App/Authentication/AuthenticationViewModel.swift`
- Create: `AppTemplate/App/Authentication/AuthenticationView.swift`
- Modify: `AppTemplate/App/Navigation/AppRootView.swift`
- Create: `AppTemplateTests/AuthenticationViewModelTests.swift`

**Interfaces:**
- Consumes: shared `SessionStore`
- Consumes: scene `AppRouter`
- Produces: `AuthenticationViewModel.init(sessionStore:router:)`
- Produces: `signIn() async`, `retryRestoration() async`, and `cancelAuthentication()`
- Produces: `AuthenticationView.init(sessionStore:router:)`

- [ ] **Step 1: Write failing Authentication ViewModel tests**

Create `AuthenticationViewModelTests.swift`:

```swift
import Testing
@testable import AppTemplate

@MainActor
struct AuthenticationViewModelTests {
    @Test
    func signInUpdatesTheSharedSessionStore() async {
        let session = UserSession(id: "user", displayName: "User")
        let store = SessionStore(
            service: AuthenticationSessionService(
                restoredSession: nil,
                signedInSession: session,
                restorationFails: false
            )
        )
        let viewModel = AuthenticationViewModel(
            sessionStore: store,
            router: AppRouter(flow: .authentication)
        )

        await viewModel.signIn()

        #expect(store.phase == .authenticated(session))
        #expect(viewModel.failureMessage == nil)
    }

    @Test
    func cancellationClearsTheScenePendingIntent() {
        let store = SessionStore(
            service: InMemorySessionService(initialSession: nil)
        )
        let router = AppRouter(flow: .authentication)
        _ = router.handle(.browseItem(id: "swiftui"))
        let viewModel = AuthenticationViewModel(
            sessionStore: store,
            router: router
        )

        viewModel.cancelAuthentication()

        #expect(router.pendingIntent == nil)
        #expect(router.flow == .authentication)
    }

    @Test
    func restorationFailureIsDisplaySafeAndRetryable() async {
        let store = SessionStore(
            service: AuthenticationSessionService(
                restoredSession: nil,
                signedInSession: UserSession(
                    id: "user",
                    displayName: "User"
                ),
                restorationFails: true
            )
        )
        let viewModel = AuthenticationViewModel(
            sessionStore: store,
            router: AppRouter(flow: .launching)
        )

        await store.start()

        #expect(viewModel.canRetryRestoration)
        #expect(
            viewModel.failureMessage
                == "The previous session could not be restored."
        )
    }

    @Test
    func retryRestorationDelegatesToTheSharedSessionStore() async {
        let service = RetryingAuthenticationSessionService()
        let store = SessionStore(service: service)
        let viewModel = AuthenticationViewModel(
            sessionStore: store,
            router: AppRouter(flow: .launching)
        )
        await store.start()
        #expect(store.failure == .restoration)

        await viewModel.retryRestoration()
        let attempts = await service.restorationAttempts()

        #expect(attempts == 2)
        #expect(store.phase == .unauthenticated)
        #expect(store.failure == nil)
    }

    @Test
    func authenticationScreenCanBeConstructed() {
        let store = SessionStore(
            service: InMemorySessionService(initialSession: nil)
        )

        _ = AuthenticationView(
            sessionStore: store,
            router: AppRouter(flow: .authentication)
        )
    }
}

private nonisolated enum AuthenticationTestError: Error {
    case restoration
}

private nonisolated struct AuthenticationSessionService: SessionService {
    let restoredSession: UserSession?
    let signedInSession: UserSession
    let restorationFails: Bool

    func currentSession() throws -> UserSession? {
        if restorationFails {
            throw AuthenticationTestError.restoration
        }
        return restoredSession
    }

    func signIn() -> UserSession {
        signedInSession
    }

    func signOut() {
    }
}

private actor RetryingAuthenticationSessionService: SessionService {
    private var attempts = 0

    func currentSession() throws -> UserSession? {
        attempts += 1
        if attempts == 1 {
            throw AuthenticationTestError.restoration
        }
        return nil
    }

    func signIn() -> UserSession {
        UserSession(id: "user", displayName: "User")
    }

    func signOut() {
    }

    func restorationAttempts() -> Int {
        attempts
    }
}
```

- [ ] **Step 2: Run Authentication tests and verify RED**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AuthenticationViewModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `AuthenticationViewModel` and `AuthenticationView` do not exist.

- [ ] **Step 3: Implement AuthenticationViewModel**

Create:

```swift
import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
    private let sessionStore: SessionStore
    private let router: AppRouter

    var failureMessage: String? {
        sessionStore.failure?.message
    }

    var canRetryRestoration: Bool {
        sessionStore.failure == .restoration
    }

    init(
        sessionStore: SessionStore,
        router: AppRouter
    ) {
        self.sessionStore = sessionStore
        self.router = router
    }

    func signIn() async {
        await sessionStore.signIn()
    }

    func retryRestoration() async {
        await sessionStore.retryStart()
    }

    func cancelAuthentication() {
        _ = router.completeAuthentication(succeeded: false)
    }
}
```

- [ ] **Step 4: Extract AuthenticationView and compose it from AppRootView**

Move the existing authentication layout into an internal `AuthenticationView`.

It owns:

```swift
@State private var viewModel: AuthenticationViewModel

init(
    sessionStore: SessionStore,
    router: AppRouter
) {
    _viewModel = State(
        initialValue: AuthenticationViewModel(
            sessionStore: sessionStore,
            router: router
        )
    )
}
```

Replace callback properties with direct ViewModel calls. Async button actions use:

```swift
Task {
    await viewModel.signIn()
}
```

and:

```swift
Task {
    await viewModel.retryRestoration()
}
```

Keep the existing text, button roles, and conditional Retry presentation.

In `AppRootView`, replace `AuthenticationPlaceholderView` with:

```swift
AuthenticationView(
    sessionStore: sessionStore,
    router: router
)
```

Delete the old private placeholder type.

- [ ] **Step 5: Run Authentication tests and the full macOS suite**

Run the targeted command from Step 2, then the full macOS command from Task 1.

Expected: all Authentication and existing tests pass.

- [ ] **Step 6: Commit Authentication MVVM**

```bash
git add \
  AppTemplate/App/Authentication \
  AppTemplate/App/Navigation/AppRootView.swift \
  AppTemplateTests/AuthenticationViewModelTests.swift
git commit -m "feat: add authentication screen view model"
```

### Task 5: Add Settings and About ViewModels

**Files:**
- Create: `AppTemplate/Features/Settings/Presentation/SettingsViewModel.swift`
- Create: `AppTemplate/Features/Settings/Presentation/AboutViewModel.swift`
- Create: `AppTemplate/Features/Settings/AboutView.swift`
- Modify: `AppTemplate/Features/Settings/SettingsView.swift`
- Modify: `AppTemplate/App/Navigation/AppShellView.swift`
- Create: `AppTemplateTests/SettingsViewModelTests.swift`

**Interfaces:**
- Consumes: shared `SessionStore`
- Produces: `SettingsViewModel.init(sessionStore:)`
- Produces: `phase`, `failureMessage`, and `signOut() async`
- Produces: `AboutViewModel.init()` and immutable presentation data
- Produces: `SettingsNavigationView.init(router:sessionStore:)`

- [ ] **Step 1: Write failing Settings and About tests**

Create `SettingsViewModelTests.swift`:

```swift
import Testing
@testable import AppTemplate

@MainActor
struct SettingsViewModelTests {
    @Test
    func settingsReflectsAndMutatesTheSharedSession() async {
        let session = UserSession(id: "user", displayName: "User")
        let store = SessionStore(
            service: InMemorySessionService(initialSession: session)
        )
        await store.start()
        let viewModel = SettingsViewModel(sessionStore: store)

        #expect(viewModel.phase == .authenticated(session))

        await viewModel.signOut()

        #expect(viewModel.phase == .unauthenticated)
        #expect(viewModel.failureMessage == nil)
    }

    @Test
    func aboutProvidesSupportedPlatformPresentation() {
        let viewModel = AboutViewModel()

        #expect(viewModel.supportedPlatforms == [
            "iOS 26",
            "iPadOS 26",
            "macOS 26"
        ])
        #expect(
            viewModel.exampleDescription
                == "Home, Browse, and Settings are replaceable feature examples."
        )
    }

    @Test
    func failedSignOutExposesSafeFailureAndKeepsTheSession() async {
        let session = UserSession(id: "user", displayName: "User")
        let store = SessionStore(
            service: FailingSettingsSessionService(session: session)
        )
        await store.start()
        let viewModel = SettingsViewModel(sessionStore: store)

        await viewModel.signOut()

        #expect(viewModel.phase == .authenticated(session))
        #expect(
            viewModel.failureMessage
                == "Sign out could not be completed."
        )
    }

    @Test
    func everySettingsScreenCanBeConstructed() {
        let store = SessionStore(
            service: InMemorySessionService(initialSession: nil)
        )

        _ = SettingsNavigationView(
            router: SettingsRouter(),
            sessionStore: store
        )
        _ = AboutView()
    }
}

private nonisolated enum SettingsViewModelTestError: Error {
    case signOut
}

private nonisolated struct FailingSettingsSessionService: SessionService {
    let session: UserSession

    func currentSession() -> UserSession? {
        session
    }

    func signIn() -> UserSession {
        session
    }

    func signOut() throws {
        throw SettingsViewModelTestError.signOut
    }
}
```

- [ ] **Step 2: Run Settings tests and verify RED**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/SettingsViewModelTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because the two ViewModels, `AboutView`, and the explicit Settings initializer do not exist.

- [ ] **Step 3: Implement SettingsViewModel and AboutViewModel**

Create `SettingsViewModel.swift`:

```swift
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let sessionStore: SessionStore

    var phase: SessionPhase {
        sessionStore.phase
    }

    var failureMessage: String? {
        sessionStore.failure?.message
    }

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    func signOut() async {
        await sessionStore.signOut()
    }
}
```

Create `AboutViewModel.swift`:

```swift
import Observation

@MainActor
@Observable
final class AboutViewModel {
    let supportedPlatforms = [
        "iOS 26",
        "iPadOS 26",
        "macOS 26"
    ]
    let exampleDescription =
        "Home, Browse, and Settings are replaceable feature examples."
}
```

- [ ] **Step 4: Refactor Settings and About Views**

Remove `@Environment(SessionStore.self)` from `SettingsNavigationView`.

Give it:

```swift
@Bindable var router: SettingsRouter
@State private var viewModel: SettingsViewModel

init(
    router: SettingsRouter,
    sessionStore: SessionStore
) {
    self.router = router
    _viewModel = State(
        initialValue: SettingsViewModel(
            sessionStore: sessionStore
        )
    )
}
```

Read `viewModel.phase` and `viewModel.failureMessage`. Keep the declarative:

```swift
NavigationLink(
    "About this template",
    value: SettingsRoute.about
)
```

Call sign-out with:

```swift
Task {
    await viewModel.signOut()
}
```

Move About into an internal `AboutView` that owns:

```swift
@State private var viewModel: AboutViewModel

init() {
    _viewModel = State(
        initialValue: AboutViewModel()
    )
}
```

Render the platform list with `ForEach(viewModel.supportedPlatforms, id: \.self)` and preserve the existing copy.

Update `AppShellView`:

```swift
@Environment(SessionStore.self) private var sessionStore
```

and:

```swift
SettingsNavigationView(
    router: router.settings,
    sessionStore: sessionStore
)
```

- [ ] **Step 5: Run Settings tests and the full macOS suite**

Run the targeted command from Step 2, then the full macOS command from Task 1.

Expected: all Settings and existing tests pass.

- [ ] **Step 6: Commit Settings MVVM**

```bash
git add \
  AppTemplate/App/Navigation/AppShellView.swift \
  AppTemplate/Features/Settings \
  AppTemplateTests/SettingsViewModelTests.swift
git commit -m "feat: add view models for settings screens"
```

### Task 6: Complete Construction Coverage, Documentation, and Cross-Platform Verification

**Files:**
- Modify: `AppTemplateTests/ProjectConfigurationTests.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: all ViewModel and screen APIs from Tasks 1–5
- Produces: documented feature-scoped MVVM usage contract
- Verifies: complete iOS/iPadOS and macOS build/test compatibility

- [ ] **Step 1: Expand the root construction test**

Update `navigationRootCanBeConstructed()` to use scoped dependencies:

```swift
let sessionStore = SessionStore(
    service: dependencies.session.service
)

_ = AppSceneView(dependencies: dependencies)
    .environment(sessionStore)
_ = AppRootView(
    router: router,
    dependencies: dependencies
)
.environment(sessionStore)
_ = AppShellView(
    router: router,
    dependencies: dependencies
)
.environment(sessionStore)
_ = HomeNavigationView(router: router.home)
_ = BrowseNavigationView(
    router: router.browse,
    dependencies: dependencies.browse
)
_ = SettingsNavigationView(
    router: router.settings,
    sessionStore: sessionStore
)
```

- [ ] **Step 2: Run the construction test**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/ProjectConfigurationTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all project-configuration and construction tests pass.

- [ ] **Step 3: Document the final usage pattern**

Add this section to `README.md` after Dependency Injection:

````markdown
## Views and ViewModels

Every full user-facing screen owns one concrete `@MainActor @Observable`
ViewModel in private `@State`. Infrastructure containers and small stateless
subviews remain plain SwiftUI Views.

`AppDependencies` exposes immutable feature scopes such as
`BrowseDependencies`. A screen initializer receives its feature scope, shared
store, and router only when needed. No ViewModel receives the whole application
container or reads SwiftUI Environment.

Routers remain scene-scoped and own typed navigation state. ViewModels own
presentation state and async screen behavior. Repositories and services own
domain and infrastructure work.

Example:

```swift
BrowseNavigationView(
    router: router.browse,
    dependencies: dependencies.browse
)
```
````

Update the existing DI description to name `dependencies.browse.repository` and `dependencies.session.service`.

- [ ] **Step 4: Run architectural static checks**

Run:

```bash
rg -n 'ObservableObject|@Published|@StateObject|BaseViewModel|resolve\(' \
  AppTemplate
```

Expected: no matches.

Run:

```bash
rg -n 'AppDependencies' AppTemplate -g '*ViewModel.swift'
```

Expected: no matches.

Run:

```bash
rg -n 'Browse(List|Detail)Store' AppTemplate AppTemplateTests
```

Expected: no matches.

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 5: Run the complete iOS test suite**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all tests pass with zero failures.

- [ ] **Step 6: Run the complete macOS test suite**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all tests pass with zero failures.

- [ ] **Step 7: Build Release for iOS/iPadOS and macOS**

Run:

```bash
xcodebuild build -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds for the universal iPhone/iPad target.

Run:

```bash
xcodebuild build -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds for macOS.

- [ ] **Step 8: Commit integration documentation**

```bash
git add \
  AppTemplateTests/ProjectConfigurationTests.swift \
  README.md
git commit -m "docs: explain feature-scoped view models"
```

- [ ] **Step 9: Inspect the completed branch**

Run:

```bash
git status --short --branch
git log --oneline --decorate -10
```

Expected: clean working tree containing the six focused implementation commits after the design and plan commits.
