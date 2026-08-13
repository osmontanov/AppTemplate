# Connected Mini Store Phase 5: Protected Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add scene-local protected Favorites and Account actions plus Authentication while Main, products, cart, checkout, public Profile, Preferences, About, and Services remain available to Guests.

**Architecture:** The app-owned phase-3 `SessionController` is the only session publisher. Each `StoreRouter` owns one pending protected action, Authentication presentation, Profile subsection, and safe Account cache. A monotonic reconciler consumes an action only on a non-authenticated → Authenticated transition and prunes only protected scene state on Guest/unavailable/identity change.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation, Swift Testing, XCTest/XCUITest, iOS/iPadOS/macOS 26.0, Xcode 26.6

**Normative design:** `docs/superpowers/specs/2026-08-13-connected-mini-store-design.md` at commit `e372913a20bcebd09675fe3f7cf965d2cd40a11d`.

## Global Constraints

- Complete phases 1–4. Consume `SessionController`, `SessionPresentation`, phase-2 `IFavoritesRepository`, and phase-4 routes/presentations; never create a scene-owned session controller.
- Authentication is an item-driven scene modal with a nested `NavigationStack`; it is not an `AppFlow` root and is never persisted.
- One scene holds at most one pending action; newer replaces older. Cancel clears only its origin. Remove an action before executing it; show an execution failure once and never auto-replay it.
- Each scene applies a newer process-local session revision once. A login dismisses Authentication in all windows; each still-pending origin scene may consume its own action once.
- Guest, unavailable, Sign Out, or authenticated identity change removes Favorites destinations, action/Auth state, Account selection, and Account cache. Product, reviews, cart, checkout, public Profile, Preferences, About, and Services survive.
- Same-user availability/validation revisions neither prune nor consume. Identity change prunes but does not execute a stale action.
- Sign Out `.deletionFailed` preserves authenticated Account. Only a committed Guest revision prunes.
- Persistence failure retains username/action/token but clears password; retry uses the opaque token without a second login. Models and diagnostics redact passwords.
- Follow RED → intended RED → minimal GREEN → focused regression → commit. Every task compiles all platforms.
- Do not modify `AppTemplate.xcodeproj/project.pbxproj`, `AppTemplate/Resources/Localizable.xcstrings`, or `graphify-out/`. Stage only listed paths.

---

### Task 1: Scene-owned Protected Policy and Monotonic Reconciliation

**Create**

- `AppTemplate/Features/Store/Navigation/ProtectedStoreAction.swift`

**Modify**

- `AppTemplate/Features/Store/Navigation/StorePresentation.swift`
- `AppTemplate/Features/Store/Routing/StoreRouter.swift`
- `AppTemplate/Features/Store/Screens/Profile/Model/ProfileModel.swift`
- `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`
- `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- `AppTemplate/App/Navigation/Snapshots/NavigationSnapshot.swift`
- `AppTemplate/App/Navigation/Scene/SceneNavigationPresentation.swift`

**Test**

- `AppTemplateTests/App/Navigation/Routing/StoreRouterTests.swift`
- `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
- `AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift`

**Consumes**

```swift
nonisolated struct SessionPresentation: Equatable, Sendable { let state: SessionState; let revision: UInt64 }
@MainActor protocol ISessionActions: AnyObject { var status: SessionStatusPresentation { get }; var presentation: SessionPresentation { get }; func bootstrap() async; func retryBootstrap() async; func login(username: String, password: String) async -> SessionLoginResult; func retryPersistence(_ token: SessionPersistenceRetryToken) async -> SessionPersistenceRetryResult; func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async; func validateSession() async -> SessionValidationResult; func refreshSession() async -> SessionValidationResult; func signOut() async -> SessionSignOutResult }
nonisolated enum ProfileSection: Equatable, Sendable { case overview, preferences, about, account }
nonisolated enum StorePresentation: Identifiable, Hashable, Sendable { case filters, authentication, checkout, reminder(Int); var id: String { get } }
```

**Produces**

```swift
nonisolated enum ProtectedStoreAction: Hashable, Sendable { case favorite(Product.ID), openFavorites, openAccount }
nonisolated enum ProtectedActionResolution: Equatable, Sendable { case execute(ProtectedStoreAction), presentAuthentication, blocked(SessionUnavailableReason) }
nonisolated struct ProfileAccountPresentation: Equatable, Sendable { let userID: Int; let displayName: String; let availability: SessionAvailability }
@MainActor @Observable final class StoreRouter {
    var path: [StoreRoute]
    var presentation: StorePresentation?
    private(set) var pendingProtectedAction: ProtectedStoreAction?
    private(set) var lastAppliedSessionRevision: UInt64?
    private(set) var profileSection: ProfileSection
    private(set) var cachedAccountPresentation: ProfileAccountPresentation?
    func requestProtected(_ action: ProtectedStoreAction, session: SessionState) -> ProtectedActionResolution
    func cancelAuthentication()
    func selectProfileSection(_ section: ProfileSection, session: SessionState) -> ProtectedActionResolution?
    func cacheAccountPresentation(_ value: ProfileAccountPresentation)
    func resetAccountPresentation()
    func reconcile(_ presentation: SessionPresentation) -> ProtectedStoreAction?
    func reset()
}
```

`SceneNavigationPresentation.hasPendingProtectedAction` now reflects this router. Snapshot coding proves presentation, action, profile subsection/cache, and revision are absent. Startup remains restore → root transition → first non-restoring reconciliation → ready → latest valid deferred link.

- [ ] **RED:** test one-time consumption, same-user no-op, identity pruning, public Profile preservation, and two-scene isolation.

```swift
@MainActor @Test func sameUserRevisionDoesNotConsumeAgainOrPrune() {
    let router = StoreRouter(path: [.profile, .favorites, .product(7)])
    _ = router.reconcile(.init(state: .authenticated(.fixture(id: 1), availability: .online), revision: 2))
    router.cacheAccountPresentation(.fixture(userID: 1))
    #expect(router.reconcile(.init(state: .authenticated(.fixture(id: 1), availability: .offline(.transport)), revision: 3)) == nil)
    #expect(router.path == [.profile, .favorites, .product(7)])
    #expect(router.cachedAccountPresentation?.userID == 1)
}
@MainActor @Test func identityChangePrunesWithoutExecutingStaleAction() {
    let router = StoreRouter(path: [.profile, .favorites])
    _ = router.reconcile(.init(state: .authenticated(.fixture(id: 1), availability: .online), revision: 1))
    _ = router.requestProtected(.favorite(7), session: .guest)
    #expect(router.reconcile(.init(state: .authenticated(.fixture(id: 2), availability: .online), revision: 2)) == nil)
    #expect(router.path == [.profile]); #expect(router.pendingProtectedAction == nil)
}
@MainActor @Test func sceneResetDiscardsProtectedPresentationAndFutureResume() {
    let lifecycle = AppSceneNavigationLifecycle.mainFixture(session: .guest)
    _ = lifecycle.router.requestProtected(.favorite(7), session: .guest)
    lifecycle.router.cacheAccountPresentation(.fixture(userID: 1))
    lifecycle.resetNavigationInCurrentScene()
    #expect(lifecycle.presentation().storePath.isEmpty)
    #expect(lifecycle.router.presentation == nil)
    #expect(lifecycle.router.pendingProtectedAction == nil)
    #expect(lifecycle.router.profileSection == .overview)
    #expect(lifecycle.router.cachedAccountPresentation == nil)
    #expect(lifecycle.reconcile(.authenticatedFixture(userID: 1, revision: 2)) == nil)
}
```

- [ ] **RED command:** expect nonzero because protected APIs/reconciler do not exist.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/StoreRouterTests -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests -only-testing:AppTemplateTests/NavigationSnapshotTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

- [ ] **GREEN:** keep a private identity (`unknown`, `notAuthenticated`, `authenticated(Int)`). Reject duplicate/older revisions. Guest/unavailable sets `notAuthenticated` and prunes. Authenticated after `notAuthenticated` dismisses Auth, removes then returns the pending action. Same ID returns nil without mutation. Different ID prunes, records the new ID, and returns nil. Restoring records no identity transition. `resetAccountPresentation()` selects `.overview` and clears cache; pruning filters only `.favorites`. Phase-4 `resetNavigationInCurrentScene()` remains scene-local: the lifecycle clears its deferred intent/deep-link failure, resets both section paths, and calls the phase-5 `StoreRouter.reset()`. That reset clears Store path, sheet/presentation, pending protected action, and Profile subsection/cache while preserving the already-observed session identity/revision. A later login therefore cannot revive an action discarded by Reset; the other scene is untouched.

```swift
case let (.notAuthenticated, .authenticated(profile, _)):
    lastIdentity = .authenticated(profile.id)
    if self.presentation == .authentication { self.presentation = nil }
    let action = pendingProtectedAction
    pendingProtectedAction = nil
    return action
case let (.authenticated(oldID), .authenticated(profile, _)) where oldID != profile.id:
    pruneProtectedState(); lastIdentity = .authenticated(profile.id); return nil
```

- [ ] **PASS:** run focused tests; expect exit 0, then commit. Every Authentication UI journey also ends on `ui-test.script-status.exhausted`; pending/failed/timeout is failure.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/StoreRouterTests -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests -only-testing:AppTemplateTests/NavigationSnapshotTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
git add AppTemplate/Features/Store/Navigation/ProtectedStoreAction.swift AppTemplate/Features/Store/Navigation/StorePresentation.swift AppTemplate/Features/Store/Routing/StoreRouter.swift AppTemplate/Features/Store/Screens/Profile/Model/ProfileModel.swift AppTemplate/App/Navigation/Routing/AppRouter.swift AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift AppTemplate/App/Navigation/Containers/AppSceneView.swift AppTemplate/App/Navigation/Snapshots/NavigationSnapshot.swift AppTemplate/App/Navigation/Scene/SceneNavigationPresentation.swift AppTemplateTests/App/Navigation
git commit -m "feat: reconcile protected store navigation"
```

---

### Task 2: Authentication Modal with Durable-persistence Retry

**Modify**

- `AppTemplate/Features/Authentication/Dependencies/AuthenticationDependencies.swift`
- `AppTemplate/Features/Authentication/Flow/AuthenticationFlowView.swift`
- `AppTemplate/Features/Authentication/Screens/Authentication/Model/AuthenticationModel.swift`
- `AppTemplate/Features/Authentication/Screens/Authentication/State/AuthenticationState.swift`
- `AppTemplate/Features/Authentication/Screens/Authentication/ViewModel/AuthenticationViewModel.swift`
- `AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift`
- `AppTemplate/Features/Authentication/Screens/AuthenticationHelp/View/AuthenticationHelpView.swift`
- `AppTemplate/Features/Store/Flow/StoreFlowView.swift`
- `AppTemplate/Features/Store/Routing/StoreRouter.swift`
- `AppTemplate/Features/Store/Dependencies/StoreDependencies.swift`
- `AppTemplate/App/AppDependencies/AppDependencies.swift`
- `AppTemplate/App/Entry/AppTemplateApp.swift`
- `AppTemplate/App/PreviewSupport/PreviewFixtures.swift`

**Delete**

- `AppTemplate/Features/Authentication/Dependencies/DisabledLegacyAuthenticationActions.swift`

**Test**

- `AppTemplateTests/Features/Authentication/Screens/Authentication/AuthenticationViewModelTests.swift`
- `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Consumes**

```swift
nonisolated enum SessionLoginFailure: Equatable, Sendable { case invalidCredentials, transport, serverUnavailable, rateLimited, responseInvalid, persistenceFailed(SessionPersistenceRetryToken), concurrentAttempt }
nonisolated enum SessionLoginResult: Equatable, Sendable { case authenticated(SessionRepositorySnapshot), failure(SessionLoginFailure), cancelled }
nonisolated enum SessionPersistenceRetryResult: Equatable, Sendable { case committed(SessionRepositorySnapshot), failed(SessionPersistenceRetryToken, retained: SessionRepositorySnapshot), invalidToken, cancelled }
nonisolated enum SessionSignOutResult: Equatable, Sendable { case guest, deletionFailed, cancelled }
nonisolated enum SessionValidationResult: Equatable, Sendable { case committed(SessionPresentation), persistenceFailed(SessionPersistenceRetryToken, retained: SessionPresentation), unchanged, failed(SessionPresentationError), cancelled }
@MainActor protocol ISessionActions: AnyObject { var status: SessionStatusPresentation { get }; var presentation: SessionPresentation { get }; func bootstrap() async; func retryBootstrap() async; func login(username: String, password: String) async -> SessionLoginResult; func retryPersistence(_ token: SessionPersistenceRetryToken) async -> SessionPersistenceRetryResult; func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async; func validateSession() async -> SessionValidationResult; func refreshSession() async -> SessionValidationResult; func signOut() async -> SessionSignOutResult }
```

**Produces**

```swift
nonisolated struct AuthenticationModel: Equatable, Sendable, CustomStringConvertible { var username: String; var password: String; var description: String { get } }
nonisolated struct AuthenticationRetryContext: Equatable, Sendable { let username: String; let token: SessionPersistenceRetryToken }
nonisolated enum AuthenticationState: Equatable, Sendable, CustomStringConvertible { case editing(AuthenticationModel), submitting(username: String), invalidCredentials(AuthenticationModel), persistenceFailed(AuthenticationRetryContext), failed(username: String, failure: SessionLoginFailure); var description: String { get } }
@MainActor protocol IAuthenticationCancellation: AnyObject { func cancelAuthentication() }
@MainActor @Observable final class AuthenticationViewModel { init(session: any ISessionActions, cancellation: any IAuthenticationCancellation); private(set) var state: AuthenticationState; var username: String { get set }; var password: String { get set }; func fillDemoCredentials(); func submit() async; func retryPersistence() async; func cancel() async }
@MainActor struct StoreDependencies: Sendable { let products: any IProductRepository; let session: any ISessionActions; let cart: any ICartRepository; let preferences: any IStorePreferencesRepository; let appInfo: any IAppInfoService }
```

- [ ] **RED:** prove failure clears secrets and token retry performs no second login.

```swift
@MainActor @Test func persistenceRetryKeepsUsernameButNotPassword() async {
    let token = SessionPersistenceRetryToken.fixture
    let session = SessionActionsSpy(loginResults: [.failure(.persistenceFailed(token))], retryResults: [.committed(.fixture(state: .authenticated(.fixture(id: 1), availability: .online), expiry: .fixture))])
    let viewModel = AuthenticationViewModel(session: session, cancellation: .spy)
    viewModel.username = "emilys"; viewModel.password = "emilyspass"; await viewModel.submit()
    #expect(viewModel.state == .persistenceFailed(.init(username: "emilys", token: token)))
    #expect(viewModel.password.isEmpty); #expect(!String(describing: viewModel.state).contains("emilyspass"))
    await viewModel.retryPersistence(); #expect(session.loginCalls.count == 1); #expect(session.retryCalls == [token])
}
```

Also cover blank validation, demo fill, invalid credentials, concurrent submit suppression, `.cancelled`, all non-persistence failures, new retry token, invalid token, and Cancel awaiting discard.

- [ ] **RED command:** expect nonzero because credential/retry states are absent.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/AuthenticationViewModelTests -only-testing:AppTemplateTests/AppDependenciesTests -only-testing:AppTemplateTests/ProjectConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

- [ ] **GREEN:** switch exact phase-3 results. `.failure(.persistenceFailed(token))` clears `password` before storing only username/token. Retry handles `.committed(snapshot)`, `.failed(newToken, retained:)`, `.invalidToken`, `.cancelled`; it never calls login, reads no expiry itself, and relies on the controller's atomic status publication. Cancel discards a retained token before `router.cancelAuthentication()`. Both descriptions always print `password: <redacted>`. Present `.authentication` via `.sheet(item:)`; its nested stack owns Cancel. Delete the temporary disabled legacy actions and assert `! rg -n 'IAuthenticationActions|DisabledLegacyAuthenticationActions' AppTemplate/Features/Authentication`. Task-1 shared revision dismissal remains the only cross-window behavior.

`AppDependencies` adds `@MainActor func makeStoreDependencies(session: any ISessionActions) -> StoreDependencies`; `AppTemplateApp` invokes it once with its app-owned `SessionController` and passes the returned slice through the existing phase-4 chain. Preview fixtures and every direct constructor in `ProjectConfigurationTests` inject a fresh isolated `ISessionActions` spy/controller and call the same factory; no nonlive graph evaluates the live controller. The factory reuses the exact products/cart/preferences/AppInfo instances and composition tests route calls through the injected session spy; it never constructs a second controller.

```swift
case let .failure(.persistenceFailed(token)):
    model.password = ""
    state = .persistenceFailed(.init(username: submitted.username, token: token))
case .authenticated:
    return
case .cancelled:
    state = .editing(submitted)
case .failure(.invalidCredentials):
    state = .invalidCredentials(submitted)
case let .failure(failure):
    model.password = ""
    state = .failed(username: submitted.username, failure: failure)
```

- [ ] **PASS:** run tests and iOS build; expect exit 0, then commit.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/AuthenticationViewModelTests -only-testing:AppTemplateTests/AppDependenciesTests -only-testing:AppTemplateTests/ProjectConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
git add -A AppTemplate/Features/Authentication AppTemplate/Features/Store/Flow/StoreFlowView.swift AppTemplate/Features/Store/Routing/StoreRouter.swift AppTemplate/Features/Store/Dependencies/StoreDependencies.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplate/App/Entry/AppTemplateApp.swift AppTemplate/App/PreviewSupport/PreviewFixtures.swift AppTemplateTests/Features/Authentication AppTemplateTests/App/Composition/AppDependenciesTests.swift AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "feat: add durable authentication modal"
```

---

### Task 3: Favorites, Public Profile Account Gate, Sign Out, and Protected Links

**Create**

- `AppTemplate/Features/Store/Screens/Favorites/Model/FavoritesModel.swift`
- `AppTemplate/Features/Store/Screens/Favorites/State/FavoritesState.swift`
- `AppTemplate/Features/Store/Screens/Favorites/ViewModel/FavoritesViewModel.swift`
- `AppTemplate/Features/Store/Screens/Favorites/View/FavoritesView.swift`
- `AppTemplate/Features/Store/Navigation/ProtectedStoreActionExecutor.swift`
- `AppTemplate/Features/Store/Screens/SessionRecovery/SessionRecoveryViewModel.swift`
- `AppTemplate/Features/Store/Screens/SessionRecovery/SessionRecoveryView.swift`

**Modify**

- `AppTemplate/Features/Store/Screens/Profile/Model/ProfileModel.swift`
- `AppTemplate/Features/Store/Screens/Profile/State/ProfileState.swift`
- `AppTemplate/Features/Store/Screens/Profile/ViewModel/ProfileViewModel.swift`
- `AppTemplate/Features/Store/Screens/Profile/View/ProfileView.swift`
- `AppTemplate/Features/Store/Flow/StoreFlowView.swift`
- `AppTemplate/Features/Store/Navigation/StorePresentation.swift`
- `AppTemplate/Features/Store/Dependencies/StoreDependencies.swift`
- `AppTemplate/App/AppDependencies/AppDependencies.swift`
- `AppTemplate/App/Navigation/Routing/NavigationIntent.swift`
- `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- `AppTemplate/App/Navigation/DeepLinks/DeepLinkParser.swift`
- `AppTemplate/App/Entry/AppLaunchConfiguration.swift`
- `AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift`
- `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`

**Test**

- `AppTemplateTests/Features/Store/Screens/Favorites/FavoritesViewModelTests.swift`
- `AppTemplateTests/Features/Store/Screens/Profile/ProfileViewModelTests.swift`
- `AppTemplateTests/Features/Store/Navigation/ProtectedStoreActionExecutorTests.swift`
- `AppTemplateTests/Features/Store/Screens/SessionRecovery/SessionRecoveryViewModelTests.swift`
- `AppTemplateTests/App/Navigation/DeepLinks/DeepLinkParserTests.swift`
- `AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift`
- `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift`
- `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
- `AppTemplateUITests/Flows/AuthenticationUITests.swift`
- `AppTemplateUITests/TestSupport/StoreRobot.swift`

**Consumes**

```swift
nonisolated protocol IFavoritesRepository: Sendable { func favorites(userID: Int) async throws -> [FavoriteProductSnapshot]; func contains(userID: Int, productID: Int) async throws -> Bool; @discardableResult func ensureFavorite(_ product: ProductSnapshot, userID: Int) async throws -> Bool; @discardableResult func removeFavorite(userID: Int, productID: Int) async throws -> Bool; @discardableResult func toggle(_ product: ProductSnapshot, userID: Int) async throws -> Bool }
nonisolated protocol IProductRepository: Sendable { func categories() async throws -> [ProductCategory]; func page(_ query: ProductQuery) async throws -> ProductPage; func product(id: Product.ID) async throws -> Product; func related(to product: Product, limit: Int) async throws -> [Product] }
nonisolated enum SessionSignOutResult: Equatable, Sendable { case guest, deletionFailed, cancelled }
@MainActor protocol ISessionActions: AnyObject { var status: SessionStatusPresentation { get }; var presentation: SessionPresentation { get }; func bootstrap() async; func retryBootstrap() async; func login(username: String, password: String) async -> SessionLoginResult; func retryPersistence(_ token: SessionPersistenceRetryToken) async -> SessionPersistenceRetryResult; func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async; func validateSession() async -> SessionValidationResult; func refreshSession() async -> SessionValidationResult; func signOut() async -> SessionSignOutResult }
```

**Produces**

```swift
@MainActor @Observable final class FavoritesViewModel { init(repository: any IFavoritesRepository); private(set) var state: FavoritesState; func load(userID: Int) async; func remove(productID: Product.ID, userID: Int) async }
nonisolated enum ProfileError: Equatable, Sendable { case signOutDeletionFailed }
@MainActor @Observable final class ProfileViewModel { init(router: StoreRouter, session: any ISessionActions, appInfo: any IAppInfoService); var selectedSection: ProfileSection { get }; private(set) var error: ProfileError?; func select(_ section: ProfileSection, session: SessionState) -> ProtectedActionResolution?; func signOut() async }
nonisolated enum ProtectedStoreActionExecutionError: Equatable, Sendable { case productLoadFailed, favoriteReadFailed, favoriteWriteFailed }
nonisolated enum StorePresentation: Identifiable, Hashable, Sendable { case filters, authentication, checkout, reminder(Int), sessionRecovery(SessionUnavailableReason); var id: String { get } }
@MainActor @Observable final class SessionRecoveryViewModel { init(reason: SessionUnavailableReason, session: any ISessionActions, onResolved: @escaping () -> Void); private(set) var isRetrying: Bool; private(set) var reason: SessionUnavailableReason; func retry() async; func sessionDidChange(_ status: SessionStatusPresentation) }
@MainActor @Observable final class ProtectedStoreActionExecutor { init(router: StoreRouter, products: any IProductRepository, favorites: any IFavoritesRepository, session: any ISessionActions); private(set) var error: ProtectedStoreActionExecutionError?; func activateHeart(for product: Product, session: SessionState) async; func execute(_ action: ProtectedStoreAction, expectedUserID: Int) async; func sessionDidChange(_ presentation: SessionPresentation) }
@MainActor struct StoreDependencies: Sendable { let products: any IProductRepository; let session: any ISessionActions; let favorites: any IFavoritesRepository; let cart: any ICartRepository; let preferences: any IStorePreferencesRepository; let appInfo: any IAppInfoService }
```

- [ ] **RED:** prove Account is a protected subsection and failed Sign Out retains it.

```swift
@MainActor @Test func failedSignOutKeepsAuthenticatedAccount() async {
    let router = StoreRouter.fixture(account: .fixture(userID: 1))
    let viewModel = ProfileViewModel(router: router, session: .spy(signOutResult: .deletionFailed), appInfo: .fixture)
    await viewModel.signOut()
    #expect(router.profileSection == .account); #expect(router.cachedAccountPresentation?.userID == 1)
    #expect(viewModel.error != nil)
}
```

Also test user-scoped reads/removes, write failure, Guest Account retaining `.profile`, protected `store/favorites`, public Profile links, Auth cancel, and committed Guest preserving Main/product/profile. A pending or notification `.favorite(id)` always executes idempotent `ensureFavorite`. An authenticated in-app heart first awaits `contains`, then `removeFavorite` or `ensureFavorite`; a Guest heart becomes a pending ensure and unavailable returns `.blocked(reason)`, which presents scene-local Session Recovery with the exact safe reason and Retry calling only `retryBootstrap()`. Read/cleanup recovery dismisses only after status is no longer unavailable; failure remains visible and no Authentication/favorite/navigation action is falsely run. Saved UI changes only after the repository succeeds; write failure or identity-invalidating session change shows no optimistic success. A suspended product/favorite race proves same-user validating→online/offline revisions do not cancel or drop the consumed local action, while Guest, unavailable, or a different authenticated user cancels it before write/navigation. A lifecycle test proves each newer shared presentation is reconciled once, hands the removed action and authenticated user ID to only that scene's executor, and two scenes may independently consume their own pending action.

- [ ] **RED command:** expect nonzero because Favorites and protected Account behavior are absent.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/FavoritesViewModelTests -only-testing:AppTemplateTests/ProfileViewModelTests -only-testing:AppTemplateTests/SessionRecoveryViewModelTests -only-testing:AppTemplateTests/ProtectedStoreActionExecutorTests -only-testing:AppTemplateTests/DeepLinkParserTests -only-testing:AppTemplateTests/AppRouterTests -only-testing:AppTemplateTests/AppLaunchConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

- [ ] **GREEN:** Profile reads/writes router-owned subsection; no second owner exists. Taps and links call `requestProtected`; `.blocked(reason)` presents `.sessionRecovery(reason)` and its ViewModel invokes only app-owned `retryBootstrap()`. Favorite resolution fetches the product and awaits `ensureFavorite(product.snapshot, userID:)`; Open Favorites replaces its path; Open Account calls `selectProfileSection`. Remove the action before this executor. Sign Out `.deletionFailed` keeps Account/cache, `.cancelled` is silent, and `.guest` waits for the Guest revision to prune. Extend only `AppDependencies.makeStoreDependencies(session:)` with the one app-scoped phase-2 favorites repository and prove Store receives that exact writer actor. `AppSceneView` owns one executor beside its lifecycle. Its session observer first calls `sessionDidChange`, then `lifecycle.reconcile(_:)`; if an action is returned with an authenticated presentation, it starts `execute(_:expectedUserID:)`. The executor cancels its previous generation only for Guest/unavailable/different user and rechecks that same authenticated user ID after product/favorite reads and immediately before each write/navigation effect; same-user availability/revision changes remain valid and later identity-invalidating changes suppress stale UI success.

```swift
case let .favorite(id):
    guard case let .authenticated(profile, _) = session.presentation.state,
          profile.id == expectedUserID else { return }
    let product: Product
    do { product = try await products.product(id: id) }
    catch is CancellationError { return }
    catch { error = .productLoadFailed; return }
    guard case let .authenticated(current, _) = session.presentation.state,
          current.id == expectedUserID else { return }
    do { _ = try await favorites.ensureFavorite(product.snapshot, userID: profile.id) }
    catch is CancellationError { return }
    catch { error = .favoriteWriteFailed }
case .openFavorites: router.replace(with: .favorites)
case .openAccount: _ = router.selectProfileSection(.account, session: session.presentation.state)
```

- [ ] **PASS:** run unit and representative UI tests; expect exit 0. UI resumes one favorite, then Sign Out remains in Main/public Profile.

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/FavoritesViewModelTests -only-testing:AppTemplateTests/ProfileViewModelTests -only-testing:AppTemplateTests/SessionRecoveryViewModelTests -only-testing:AppTemplateTests/ProtectedStoreActionExecutorTests -only-testing:AppTemplateTests/DeepLinkParserTests -only-testing:AppTemplateTests/AppRouterTests -only-testing:AppTemplateTests/AppLaunchConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:AppTemplateUITests/AuthenticationUITests/testFavoriteLoginResumeAndSignOut SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
git add AppTemplate/Features/Store/Screens/Favorites AppTemplate/Features/Store/Screens/Profile AppTemplate/Features/Store/Screens/SessionRecovery AppTemplate/Features/Store/Navigation/ProtectedStoreActionExecutor.swift AppTemplate/Features/Store/Navigation/StorePresentation.swift AppTemplate/Features/Store/Flow/StoreFlowView.swift AppTemplate/Features/Store/Dependencies/StoreDependencies.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplate/App/Navigation/Routing/NavigationIntent.swift AppTemplate/App/Navigation/Routing/AppRouter.swift AppTemplate/App/Navigation/DeepLinks/DeepLinkParser.swift AppTemplate/App/Navigation/Containers/AppSceneView.swift AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift AppTemplate/App/Entry/AppLaunchConfiguration.swift AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift AppTemplateTests/Features/Store AppTemplateTests/App/Navigation AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift AppTemplateTests/App/Composition/AppDependenciesTests.swift AppTemplateUITests/Flows/AuthenticationUITests.swift AppTemplateUITests/TestSupport/StoreRobot.swift
git commit -m "feat: add protected favorites and account"
```

## Phase 5 Exit Gate

Run roadmap boundary commands and verify `! rg -n 'case authentication' AppTemplate/App/Navigation/Routing/AppFlow.swift`. Phase 6 consumes protected action delivery, scene readiness, product metadata, and shared session policy.
