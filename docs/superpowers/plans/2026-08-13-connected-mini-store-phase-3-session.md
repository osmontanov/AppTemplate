# Connected Mini Store — Phase 3: Persistent Session Subsystem

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Goal

Implement one app-owned, Keychain-backed session with bounded local restore, exact auth classification, durable writes, generation-safe login/refresh/sign-out, and guest-capable Main root flow.

## Architecture

SessionRepository alone owns bearer/refresh tokens, session generation, bootstrap candidates, PendingCredentialCandidate, and one refresh task. StoredSessionEnvelope is the single Store.AuthSession record. SessionController publishes only SessionPresentation. AppFlowPolicy reads AppState plus local-bootstrap resolution; remote validation never blocks Main.

## Tech Stack

Swift 6 actors, Observation, Keychain service, AppClock, DummyJSON remote DTOs, Swift Testing, Xcode 26.

**Normative design:** `docs/superpowers/specs/2026-08-13-connected-mini-store-design.md` at commit `e372913a20bcebd09675fe3f7cf965d2cd40a11d`.

## Global Constraints

- RED → GREEN → regression; every task compiles.
- Every repository operation captures sessionGeneration and rechecks after each suspension, before Keychain mutation, and before returning a public result.
- Only endpoint + mapped DummyJSON auth-error body permits rejection. Status alone never destroys credentials.
- Cancellation leaves public state/revision unchanged and creates no visible error.
- JWT exp is scheduling metadata, never signature verification.
- Access expiry uses the injected wall clock and a fixed 60-second refresh leeway: more than 60 seconds remaining may call `/auth/me`; 60 seconds or less joins the single refresh. Tests advance the clock and never sleep.
- Do not edit AppTemplate.xcodeproj/project.pbxproj or AppTemplate/Resources/Localizable.xcstrings; do not stage the spec, graphify-out/, or unrelated changes.

## Task 1: Define the envelope, secure-store result, and response matrix

**Create**

- AppTemplate/App/Models/Session/UserProfile.swift
- AppTemplate/App/Models/Session/SessionState.swift
- AppTemplate/App/Models/Session/StoredSessionEnvelope.swift
- AppTemplate/App/Models/Session/SessionPersistenceRetryToken.swift
- AppTemplate/App/Repositories/Session/SessionSecureStore.swift
- AppTemplate/App/Repositories/Session/JWTExpiryDecoder.swift
- AppTemplate/App/Repositories/Session/AuthenticationResponseClassifier.swift
- AppTemplateTests/App/Repositories/Session/SessionSecureStoreTests.swift
- AppTemplateTests/App/Repositories/Session/JWTExpiryDecoderTests.swift
- AppTemplateTests/App/Repositories/Session/AuthenticationResponseClassifierTests.swift

**Modify:** None.

**Test:** `AppTemplateTests/App/Repositories/Session/SessionSecureStoreTests.swift`, `AppTemplateTests/App/Repositories/Session/JWTExpiryDecoderTests.swift`, `AppTemplateTests/App/Repositories/Session/AuthenticationResponseClassifierTests.swift`.

**Consumes / Produces**

~~~swift
nonisolated struct UserProfile: Codable, Equatable, Sendable {
    let id: Int
    let username: String
    let firstName: String
    let lastName: String
    let imageURL: URL?
}
nonisolated enum SessionState: Equatable, Sendable {
    case restoring
    case guest
    case unavailable(SessionUnavailableReason)
    case authenticated(UserProfile, availability: SessionAvailability)
}
nonisolated enum SessionUnavailableReason: Hashable, Sendable {
    case secureStorageReadFailed
    case secureStorageCleanupFailed
}
nonisolated enum SessionAvailability: Equatable, Sendable {
    case validating
    case online
    case offline(SessionOfflineReason)
}
nonisolated enum SessionOfflineReason: Equatable, Sendable {
    case transport
    case serverUnavailable
    case rateLimited
    case responseInvalid
    case secureStorageWriteFailed
}
nonisolated struct StoredSessionEnvelope: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    let schemaVersion: Int
    let profile: UserProfile
    let accessToken: String
    let refreshToken: String
    let accessExpiresAt: Date?
    let refreshExpiresAt: Date?
}
nonisolated struct SessionPersistenceRetryToken: Hashable, Sendable {
    private let id: UUID
    init()
}
nonisolated enum SessionSecureStoreReadResult: Equatable, Sendable {
    case missing
    case envelope(StoredSessionEnvelope)
    case corruptEnvelope
    case unsupportedSchema(Int)
}
actor SessionSecureStore {
    init(keychain: any IKeychainService)
    func read() async throws -> SessionSecureStoreReadResult
    func write(_ envelope: StoredSessionEnvelope) async throws
    @discardableResult func remove() async throws -> Bool
}
nonisolated enum AuthEndpoint: Sendable { case login, me, refresh }
nonisolated enum AuthFailureDisposition: Equatable, Sendable {
    case invalidCredentials, refreshRequired, credentialsRejected
    case transport, serverUnavailable, rateLimited, responseInvalid, cancelled
}
nonisolated enum AuthenticationResponseClassifier {
    static func classify(_ error: RemoteServiceError, endpoint: AuthEndpoint) -> AuthFailureDisposition
}
~~~

- [ ] **RED:** Assert physical account equals Store.AuthSession, schema lives inside bytes, missing/envelope/corrupt/unsupported are distinct, and read never removes. A literal future envelope containing a readable header plus fields intentionally incompatible with the current full model must still return unsupported and preserve its exact bytes; a malformed or missing header is corrupt. Test login 400/401/403+mapped → invalidCredentials; me 401/403+mapped → refreshRequired; refresh 400/401/403+mapped → credentialsRejected; 408/5xx → serverUnavailable; 429 → rateLimited; transport/cancel; decode, unknown status, or unmapped body → responseInvalid.

~~~swift
@Test func unknownRefreshStatusCannotReject() {
    #expect(AuthenticationResponseClassifier.classify(
        .status(code: 418, authenticationError: .fixture),
        endpoint: .refresh
    ) == .responseInvalid)
}
~~~

- [ ] Run RED; expect missing session/store/classifier/JWT types.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/SessionSecureStoreTests -only-testing:AppTemplateTests/AuthenticationResponseClassifierTests -only-testing:AppTemplateTests/JWTExpiryDecoderTests
~~~

- [ ] **GREEN:** SessionSecureStore uses KeychainKey.data("Store.AuthSession"). It first decodes only a frozen `SessionEnvelopeHeader { schemaVersion }`; malformed header bytes return corruptEnvelope, a version newer than current returns unsupportedSchema without decoding current payload fields, and only the exact current version is then fully decoded and validated. Keychain system errors throw. Neither corrupt nor unsupported reads remove anything. SessionPersistenceRetryToken.init creates UUID internally; only equality is exposed. The classifier handles cancellation, transport, 408, 429, 5xx, and invalid-response classes before inspecting an optional authentication body; only the three endpoint-specific destructive rows require a nonnil mapped body.

~~~swift
switch error {
case .cancelled: return .cancelled
case .transport: return .transport
case .invalidResponse: return .responseInvalid
case let .status(code, _) where code == 408 || (500...599).contains(code):
    return .serverUnavailable
case .status(429, _):
    return .rateLimited
case let .status(code, authenticationError):
    guard authenticationError != nil else { return .responseInvalid }
    switch (endpoint, code) {
    case (.login, 400), (.login, 401), (.login, 403): return .invalidCredentials
    case (.me, 401), (.me, 403): return .refreshRequired
    case (.refresh, 400), (.refresh, 401), (.refresh, 403): return .credentialsRejected
    default: return .responseInvalid
    }
}
~~~

- [ ] Run PASS and commit.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/SessionSecureStoreTests -only-testing:AppTemplateTests/AuthenticationResponseClassifierTests -only-testing:AppTemplateTests/JWTExpiryDecoderTests
git add AppTemplate/App/Models/Session AppTemplate/App/Repositories/Session/SessionSecureStore.swift AppTemplate/App/Repositories/Session/JWTExpiryDecoder.swift AppTemplate/App/Repositories/Session/AuthenticationResponseClassifier.swift AppTemplateTests/App/Repositories/Session/SessionSecureStoreTests.swift AppTemplateTests/App/Repositories/Session/JWTExpiryDecoderTests.swift AppTemplateTests/App/Repositories/Session/AuthenticationResponseClassifierTests.swift
git commit -m "feat: define secure session boundary"
~~~

## Task 2: Implement a nonblocking exact three-second bootstrap race

**Create**

- AppTemplate/App/Repositories/Session/ISessionRepository.swift
- AppTemplate/App/Repositories/Session/SessionRepository.swift
- AppTemplate/App/Repositories/Session/SessionBootstrapResult.swift
- AppTemplate/App/Utilities/Concurrency/AsyncOneShotSignal.swift
- AppTemplate/App/Session/SessionPresentation.swift
- AppTemplate/App/Session/SessionController.swift
- AppTemplateTests/App/Repositories/Session/SessionRepositoryBootstrapTests.swift
- AppTemplateTests/App/Utilities/Concurrency/AsyncOneShotSignalTests.swift
- AppTemplateTests/App/Session/SessionControllerBootstrapTests.swift

**Modify**

- AppTemplateTests/TestSupport/Keychain/KeychainServiceSpy.swift

**Test**

- AppTemplateTests/App/Repositories/Session/SessionRepositoryBootstrapTests.swift
- AppTemplateTests/App/Utilities/Concurrency/AsyncOneShotSignalTests.swift
- AppTemplateTests/App/Session/SessionControllerBootstrapTests.swift

**Consumes / Produces**

~~~swift
nonisolated enum SessionBootstrapReadResult: Equatable, Sendable {
    case candidateReady
    case readFailed
    case staleAttempt
}
nonisolated enum SessionBootstrapRaceWinner: Equatable, Sendable {
    case read(SessionBootstrapReadResult)
    case timeout
}
nonisolated struct SessionExpiryPresentation: Equatable, Sendable {
    let accessExpiresAt: Date?
    let refreshExpiresAt: Date?
}
nonisolated struct SessionRepositorySnapshot: Equatable, Sendable {
    let state: SessionState
    let expiry: SessionExpiryPresentation?
}
nonisolated protocol ISessionRepository: Sendable {
    func beginBootstrapAttempt(_ attemptID: UInt64) async
    func readBootstrapCandidate(attemptID: UInt64) async -> SessionBootstrapReadResult
    func resolveBootstrapCandidate(attemptID: UInt64) async -> SessionRepositorySnapshot
    @discardableResult func invalidateBootstrapAttempt(_ attemptID: UInt64) async -> Bool
}
actor SessionRepository: ISessionRepository {
    init(remote: any IRemoteService, secureStore: SessionSecureStore, clock: AppClock = .live,
         refreshLeeway: TimeInterval = 60)
}
actor AsyncOneShotSignal<Value: Sendable> {
    init()
    func wait() async -> Value
    @discardableResult func resolve(_ value: Value) -> Bool
}
nonisolated struct SessionPresentation: Equatable, Sendable {
    let state: SessionState
    let revision: UInt64
}
nonisolated struct SessionStatusPresentation: Equatable, Sendable {
    let session: SessionPresentation
    let expiry: SessionExpiryPresentation?
}
@MainActor @Observable final class SessionController {
    private(set) var status: SessionStatusPresentation
    var presentation: SessionPresentation { status.session }
    private(set) var isLocalBootstrapResolved: Bool
    init(repository: any ISessionRepository, clock: AppClock = .live)
    func bootstrap() async
    func retryBootstrap() async
}
~~~

- [ ] **RED:** First Keychain read ignores cancellation. Let deadline win; assert resolved+unavailable/readFailed. Complete the late valid read; assert no publication, Keychain mutation, candidate adoption, revision, or retained controller. Retry must use a larger ID and a fresh second read. Test AsyncOneShotSignal: first resolve wins, later resolves return false, wait before/after resolution returns the same value. Also cover missing → guest with nil expiry, valid → authenticated/validating with both exact UI-safe dates, corrupt app-owned bytes → remove then guest, corrupt cleanup failure → unavailable/cleanupFailed, unsupported future envelope → unavailable/readFailed with the exact Keychain bytes preserved and zero remove/write calls, system read failure → unavailable/readFailed, and concurrent bootstrap calls joining once. A controller assertion observes one atomic `SessionStatusPresentation`; it never sees new state paired with old expiry.

~~~swift
@Test @MainActor func timeoutRejectsLateReadAndRetryReadsFresh() async {
    let h = BootstrapRaceHarness(firstReadIgnoresCancellation: true)
    async let first: Void = h.controller.bootstrap()
    await h.deadline.release()
    await first
    #expect(h.controller.presentation.state == .unavailable(.secureStorageReadFailed))
    await h.firstRead.returnEnvelope(.fixture)
    await Task.yield()
    #expect(h.controller.presentation.state == .unavailable(.secureStorageReadFailed))
    async let retry: Void = h.controller.retryBootstrap()
    await h.secondRead.returnMissing()
    await retry
    #expect(h.controller.presentation.state == .guest)
}
~~~

- [ ] Run RED; expect missing repository/controller/race types.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/SessionRepositoryBootstrapTests -only-testing:AppTemplateTests/SessionControllerBootstrapTests
~~~

- [ ] **GREEN:** readBootstrapCandidate uses the Task-1 read contract and stores only the active attempt's result.

~~~swift
func readBootstrapCandidate(attemptID: UInt64) async -> SessionBootstrapReadResult {
    do {
        let result = try await secureStore.read()
        guard activeBootstrapAttemptID == attemptID else { return .staleAttempt }
        bootstrapCandidate = result
        bootstrapCandidateAttemptID = attemptID
        activeBootstrapAttemptID = nil
        return .candidateReady
    } catch {
        guard activeBootstrapAttemptID == attemptID else { return .staleAttempt }
        bootstrapCandidateAttemptID = attemptID
        activeBootstrapAttemptID = nil
        return .readFailed
    }
}
~~~

Controller increments UInt64 attempt IDs. It launches retained unstructured read/timeout Tasks coordinated by AsyncOneShotSignal; do not use a structured task group, which waits for a noncooperative child. Both capture repository/signal/attempt, never controller. Repository actor arbitration decides the winner: a resumed read atomically stores the candidate, moves its ID from active to candidate, then returns candidateReady; the timeout task first calls invalidateBootstrapAttempt, which returns true only when it atomically clears the still-active matching ID/candidate, and only then resolves the signal as timeout. Thus a timeout winner makes a later read stale before it can store anything; a read winner makes timeout return false. On either signal winner, controller clears both task references. Timeout commits one status containing resolved+unavailable and nil expiry, best-effort cancels read, and returns without awaiting it. Retry creates a new ID/read. `resolveBootstrapCandidate` accepts only the matching candidate ID and rechecks before cleanup/result: it returns state plus UI-safe dates as one `SessionRepositorySnapshot`; corrupt bytes are app-owned and removable, while an unsupported future schema is downgrade-safe, remains untouched, and resolves to unavailable/readFailed rather than falsely publishing Guest.

- [ ] Run PASS and commit.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/AsyncOneShotSignalTests -only-testing:AppTemplateTests/SessionRepositoryBootstrapTests -only-testing:AppTemplateTests/SessionControllerBootstrapTests
git add AppTemplate/App/Repositories/Session/ISessionRepository.swift AppTemplate/App/Repositories/Session/SessionRepository.swift AppTemplate/App/Repositories/Session/SessionBootstrapResult.swift AppTemplate/App/Utilities/Concurrency/AsyncOneShotSignal.swift AppTemplate/App/Session/SessionPresentation.swift AppTemplate/App/Session/SessionController.swift AppTemplateTests/App/Repositories/Session/SessionRepositoryBootstrapTests.swift AppTemplateTests/App/Utilities/Concurrency/AsyncOneShotSignalTests.swift AppTemplateTests/App/Session/SessionControllerBootstrapTests.swift AppTemplateTests/TestSupport/Keychain/KeychainServiceSpy.swift
git commit -m "feat: add bounded session bootstrap"
~~~

## Task 3: Add generation-bound login, refresh, retry, and sign-out

**Create**

- AppTemplate/App/Models/Session/SessionOperationResult.swift
- AppTemplateTests/App/Repositories/Session/SessionRepositoryLoginTests.swift
- AppTemplateTests/App/Repositories/Session/SessionRepositoryRefreshTests.swift
- AppTemplateTests/App/Repositories/Session/SessionRepositoryGenerationTests.swift

**Modify**

- AppTemplate/App/Repositories/Session/ISessionRepository.swift
- AppTemplate/App/Repositories/Session/SessionRepository.swift
- AppTemplate/App/Session/SessionController.swift

**Private type ownership:** `PendingCredentialCandidate` is a private nested struct inside `SessionRepository` in `AppTemplate/App/Repositories/Session/SessionRepository.swift`; no standalone candidate file is created.

**Test**

- AppTemplateTests/App/Repositories/Session/SessionRepositoryLoginTests.swift
- AppTemplateTests/App/Repositories/Session/SessionRepositoryRefreshTests.swift
- AppTemplateTests/App/Repositories/Session/SessionRepositoryGenerationTests.swift

**Consumes / Produces**

~~~swift
nonisolated enum SessionLoginFailure: Equatable, Sendable {
    case invalidCredentials, transport, serverUnavailable, rateLimited, responseInvalid
    case persistenceFailed(SessionPersistenceRetryToken)
    case concurrentAttempt
}
nonisolated enum SessionLoginResult: Equatable, Sendable {
    case authenticated(SessionRepositorySnapshot)
    case failure(SessionLoginFailure)
    case cancelled
}
nonisolated enum SessionPersistenceRetryResult: Equatable, Sendable {
    case committed(SessionRepositorySnapshot)
    case failed(SessionPersistenceRetryToken, retained: SessionRepositorySnapshot)
    case invalidToken
    case cancelled
}
nonisolated enum SessionPresentationError: Equatable, Sendable {
    case transport
    case serverUnavailable
    case rateLimited
    case responseInvalid
    case secureStorageReadFailed
    case secureStorageWriteFailed
    case secureStorageCleanupFailed
}
nonisolated enum SessionRepositoryValidationResult: Equatable, Sendable {
    case snapshot(SessionRepositorySnapshot)
    case persistenceFailed(SessionRepositorySnapshot, SessionPersistenceRetryToken)
    case unchanged
    case failed(SessionPresentationError)
    case cancelled
}
nonisolated enum SessionValidationResult: Equatable, Sendable {
    case committed(SessionPresentation)
    case persistenceFailed(SessionPersistenceRetryToken, retained: SessionPresentation)
    case unchanged
    case failed(SessionPresentationError)
    case cancelled
}
nonisolated enum SessionSignOutResult: Equatable, Sendable {
    case guest, deletionFailed, cancelled
}
nonisolated protocol ISessionRepository: Sendable {
    func beginBootstrapAttempt(_ attemptID: UInt64) async
    func readBootstrapCandidate(attemptID: UInt64) async -> SessionBootstrapReadResult
    func resolveBootstrapCandidate(attemptID: UInt64) async -> SessionRepositorySnapshot
    @discardableResult func invalidateBootstrapAttempt(_ attemptID: UInt64) async -> Bool
    func login(username: String, password: String) async -> SessionLoginResult
    func retryPersistence(_ token: SessionPersistenceRetryToken) async -> SessionPersistenceRetryResult
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async
    func validateStoredSession() async -> SessionRepositoryValidationResult
    func refreshStoredSession() async -> SessionRepositoryValidationResult
    func signOut() async -> SessionSignOutResult
}
actor SessionRepository: ISessionRepository {
    init(remote: any IRemoteService, secureStore: SessionSecureStore, clock: AppClock = .live,
         refreshLeeway: TimeInterval = 60)
}
~~~

`SessionRepository.performAuthenticated` is a `private` actor-isolated helper used only by future semantic authenticated repository methods; it is not part of `ISessionRepository`, `ISessionActions`, `AppDependencies`, or any feature slice. No caller-provided closure or public API ever receives the bearer `String` outside the token-owning actor.

- [ ] **RED:** Cover every auth response row and durable boundary: login write retry without remote replay, refresh write retry/token with old stored session, rotated refresh token, authoritative cleanup/cleanup failure, failed sign-out, cancellation, concurrent login, one shared refresh, forced refresh despite unexpired access, a test-only semantic operation implemented inside `SessionRepository` proving one refresh/retry with no recursion, and stale bootstrap/login/refresh completions after sign-out/new login. Add an API-surface compile assertion that Task 3 preserves `resolveBootstrapCandidate(attemptID:) -> SessionRepositorySnapshot`, `ISessionRepository` exposes no token-bearing callback, and only the repository source can reference the private helper. With a fixed clock, assert 61 seconds remaining calls `/auth/me`, while exactly 60 seconds or less refreshes without `/auth/me`; missing `exp` remains server-validated and is never locally rejected. Assert SessionPresentationError and every result description contain no bearer/refresh sentinel.

~~~swift
@Test func retryWritesSameCandidateWithoutRemoteCall() async {
    let h = SessionHarness.loginWriteFailsOnce()
    let first = await h.repository.login(username: "emilys", password: "emilyspass")
    guard case let .failure(.persistenceFailed(token)) = first else {
        Issue.record("Expected persistence retry")
        return
    }
    _ = await h.repository.retryPersistence(token)
    #expect(await h.remote.loginCalls == 1)
    #expect(await h.keychain.writeCalls == 2)
}
~~~

- [ ] Run RED; expect missing result/candidate/repository operations.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/SessionRepositoryLoginTests -only-testing:AppTemplateTests/SessionRepositoryRefreshTests -only-testing:AppTemplateTests/SessionRepositoryGenerationTests
~~~

- [ ] **GREEN:** Declare this exact private nested candidate inside SessionRepository:

~~~swift
private struct PendingCredentialCandidate: Sendable {
    enum Source: Sendable { case login, refresh }
    let generation: UInt64
    let envelope: StoredSessionEnvelope
    let token: SessionPersistenceRetryToken
    let source: Source
}
~~~

New login replaces it. Successful write, matching discard, sign-out, authoritative rejection, or generation mismatch clears it; mismatched discard does nothing. Retry repeats only secureStore.write. Login publishes no authenticated snapshot before write. Every successful/retained repository result carries `SessionState` and its UI-safe expiry dates atomically in `SessionRepositorySnapshot`; Guest/unavailable snapshots have nil expiry. Refresh failure retains cached profile/old durable envelope and returns offline/secureStorageWriteFailed with the old dates. Repository never imports/constructs `SessionPresentation`, `SessionStatusPresentation`, or revisions.

Access valid beyond the fixed 60-second leeway calls me; access at or inside the leeway refreshes. A missing JWT `exp` calls me because local metadata never rejects credentials. Mapped me rejection joins one stored refresh Task. The private actor helper retries an internal semantic operation once and cannot recurse; no raw token crosses the actor boundary. Invalid refresh deletes before guest; failure is unavailable/cleanupFailed. Sign-out increments generation and cancels refresh before delete; failed delete retains authentication.

- [ ] Run PASS and commit.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/SessionRepositoryLoginTests -only-testing:AppTemplateTests/SessionRepositoryRefreshTests -only-testing:AppTemplateTests/SessionRepositoryGenerationTests -only-testing:AppTemplateTests/AuthenticationResponseClassifierTests
git add AppTemplate/App/Models/Session/SessionOperationResult.swift AppTemplate/App/Repositories/Session/ISessionRepository.swift AppTemplate/App/Repositories/Session/SessionRepository.swift AppTemplate/App/Session/SessionController.swift AppTemplateTests/App/Repositories/Session/SessionRepositoryLoginTests.swift AppTemplateTests/App/Repositories/Session/SessionRepositoryRefreshTests.swift AppTemplateTests/App/Repositories/Session/SessionRepositoryGenerationTests.swift
git commit -m "feat: add durable session operations"
~~~

## Task 4: Compose one controller and remove authentication from root policy

**Create**

- AppTemplate/App/Session/ISessionActions.swift
- AppTemplate/App/Session/SessionRefreshSchedulePolicy.swift
- AppTemplate/App/Session/SessionStartupValidationPolicy.swift
- AppTemplate/App/Navigation/Containers/SessionRestoringView.swift
- AppTemplate/Features/Authentication/Dependencies/DisabledLegacyAuthenticationActions.swift
- AppTemplateTests/App/Session/SessionControllerTests.swift
- AppTemplateTests/App/Session/SessionRefreshSchedulingTests.swift
- AppTemplateTests/App/Session/SessionStartupValidationTests.swift

**Modify**

- AppTemplate/App/Session/SessionController.swift
- AppTemplate/App/AppDependencies/AppDependencies.swift
- AppTemplate/App/Entry/AppTemplateApp.swift
- AppTemplate/App/Navigation/Routing/AppFlow.swift
- AppTemplate/App/Navigation/Routing/AppFlowPolicy.swift
- AppTemplate/App/Navigation/Routing/AppFlowRouter.swift
- AppTemplate/App/Navigation/Routing/AppFlowCoordinator.swift
- AppTemplate/App/Navigation/Containers/AppRootView.swift
- AppTemplate/App/Navigation/Core/FlowRouter.swift
- AppTemplate/App/Navigation/Routing/IAppFlowCoordinator.swift
- AppTemplate/App/Entry/AppLaunchConfiguration.swift
- AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift
- AppTemplate/App/PreviewSupport/PreviewFixtures.swift
- AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift
- AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift
- AppTemplateTests/App/Navigation/Routing/AppFlowPolicyTests.swift
- AppTemplateTests/App/Navigation/Routing/AppFlowCoordinatorTests.swift
- AppTemplateTests/App/Navigation/Routing/AppFlowRouterTests.swift
- AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift
- AppTemplateTests/App/Navigation/Core/FlowRouterTests.swift
- AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift
- AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift
- AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift
- AppTemplateTests/App/Entry/UITestScenarioTests.swift
- AppTemplateTests/App/Composition/AppDependenciesTests.swift
- AppTemplateTests/App/Session/SessionControllerBootstrapTests.swift
- AppTemplateTests/Features/Authentication/Screens/Authentication/AuthenticationViewModelTests.swift
- AppTemplateTests/Features/Settings/Screens/Settings/SettingsViewModelTests.swift
- AppTemplateTests/TestSupport/AppFlowCoordinatorSpy.swift

**Delete after all callers use Session in this same task**

- AppTemplate/App/Navigation/Routing/LegacyAuthenticationState.swift
- AppTemplateTests/App/Navigation/Routing/LegacyAuthenticationStateTests.swift

**Test**

- AppTemplateTests/App/Session/SessionControllerTests.swift
- AppTemplateTests/App/Session/SessionRefreshSchedulingTests.swift
- AppTemplateTests/App/Session/SessionStartupValidationTests.swift
- AppTemplateTests/App/Navigation/Routing/AppFlowPolicyTests.swift
- AppTemplateTests/App/Navigation/Routing/AppFlowCoordinatorTests.swift
- AppTemplateTests/Features/Authentication/Screens/Authentication/AuthenticationViewModelTests.swift
- AppTemplateTests/TestSupport/AppFlowCoordinatorSpy.swift

**Consumes / Produces**

~~~swift
nonisolated enum AppFlow: String, Codable, Equatable, Sendable {
    case restoring, onboarding, maintenance, main
}
nonisolated enum AppFlowPolicy {
    static func resolve(_ state: AppState, isLocalSessionBootstrapResolved: Bool) -> AppFlow
}
nonisolated enum SessionRefreshSchedulePolicy: Equatable, Sendable { case automatic, disabled }
nonisolated enum SessionStartupValidationPolicy: Equatable, Sendable { case automatic, disabled }
nonisolated enum UITestSessionValidationMode: Equatable, Sendable { case disabled, scripted }
// Task 4 replaces the Task-2 initializer with this exact explicit policy seam:
// SessionController.init(repository:clock:startupValidationPolicy:refreshSchedulePolicy:)
@MainActor protocol IAppFlowCoordinator: IOnboardingActions, IMaintenanceActions {}
@MainActor final class DisabledLegacyAuthenticationActions: IAuthenticationActions {
    func signIn() -> AppFlowActionResult { .unchanged }
    func signOut() -> AppFlowActionResult { .unchanged }
}
@MainActor final class DisabledLegacySettingsAuthenticationActions: IAuthenticationActions { // declared in SettingsView.swift and removed with legacy Settings in phase 8
    func signIn() -> AppFlowActionResult { .unchanged }
    func signOut() -> AppFlowActionResult { .unchanged }
}
@MainActor protocol ISessionActions: AnyObject {
    var status: SessionStatusPresentation { get }
    var presentation: SessionPresentation { get }
    func bootstrap() async
    func retryBootstrap() async
    func login(username: String, password: String) async -> SessionLoginResult
    func retryPersistence(_ token: SessionPersistenceRetryToken) async -> SessionPersistenceRetryResult
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async
    func validateSession() async -> SessionValidationResult
    func refreshSession() async -> SessionValidationResult
    func signOut() async -> SessionSignOutResult
}
~~~

- [ ] **RED:** Assert all root cases and priority: maintenance wins; incomplete onboarding wins over unresolved read; completed policy + unresolved read is restoring; resolved read is Main. Every Restoring/Onboarding/Maintenance policy transition in both directions carries `.preserve`, and replaying Onboarding or toggling Maintenance returns two independent scenes to their exact hidden Main histories; only an explicit scene reset emits `.reset`. Freeze `IAppFlowCoordinator` as only `IOnboardingActions & IMaintenanceActions`; `AppFlowCoordinator` and `FlowRouter` expose no root `signIn`/`signOut` methods. Compatibility tests invoke both disabled legacy adapters and prove AppState/root are unchanged: Authentication keeps its adapter only until phase 5, while the separately named Settings adapter keeps the still-compiled legacy Settings sources type-correct until their phase-8 removal. `SettingsView` must no longer pass `FlowRouter` as `IAuthenticationActions`. Update every `.authentication` AppFlow fixture in the listed router/lifecycle/snapshot/launch tests in this same commit. Assert one bootstrap across scenes; sign-out success remains Main; sign-out failure retains authenticated state; revision increments exactly once per committed changed state. After a valid local session is published as validating, bootstrap/root release returns before a signalled suspended remote call, while exactly one retained app-owned startup validation runs: far-future/missing expiry calls me, expired/inside-leeway refreshes directly, and each result maps through the same status path without changing Main. Guest/unavailable starts none. Cancellation, Sign Out, newer login/generation, retry bootstrap, and controller teardown cancel/supersede it; stale completion cannot publish. `.disabled` starts none; UI scenarios may opt into `.automatic` only with corresponding ordered scripted steps. Controller tests also cover manual login, retryPersistence, validate, refresh, and sign-out result→status/revision mapping, including exact expiry update after token rotation and old-date retention after persistence failure. `presentation` is a computed projection of the same atomic `status`. With a manual clock/sleep, automatic scheduled refresh sleeps until `accessExpiresAt - 60 seconds`, triggers one shared refresh, persists before publishing, and reschedules only for a new expiry. A failed attempt is not immediately rescheduled against the same expired date. Missing expiry schedules nothing. Both automation policies are `.disabled` in preview and ordinary unit-test graphs; dedicated suites use manual/scripted automatic policies.

~~~swift
@Test func rootPriorityIsExact() {
    #expect(AppFlowPolicy.resolve(
        .init(hasCompletedOnboarding: true, isMaintenanceEnabled: true),
        isLocalSessionBootstrapResolved: false
    ) == .maintenance)
    #expect(AppFlowPolicy.resolve(
        .init(hasCompletedOnboarding: true, isMaintenanceEnabled: false),
        isLocalSessionBootstrapResolved: false
    ) == .restoring)
}
~~~

- [ ] Run RED; expect AppFlow/policy/composition mismatches.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/SessionControllerTests -only-testing:AppTemplateTests/AppFlowPolicyTests -only-testing:AppTemplateTests/AppFlowCoordinatorTests -only-testing:AppTemplateTests/AuthenticationViewModelTests -only-testing:AppTemplateTests/SettingsViewModelTests
~~~

- [ ] **GREEN:** AppDependencies owns one repository and clock; AppTemplateApp creates one @State controller, starts idempotent bootstrap, and shares it across scenes. Live composition explicitly passes both automation policies `.automatic`; previews and ordinary unit tests pass both `.disabled`; phase-1 `UITestSessionSeed` gains `validationMode: UITestSessionValidationMode`, where `.scripted` maps to automatic startup validation only over the scenario's fail-closed ordered auth steps and `.disabled` maps to none; scheduled refresh is always disabled in UI tests. Dedicated suites use manual/scripted `.automatic`. After local resolution publishes an authenticated validating snapshot, controller starts—but does not await—one retained generation/revision-bound `validateStoredSession()` Task. It maps the result through the canonical commit function, never changes root, and cancels/replaces the task on the boundaries tested above. Separately, the controller retains at most one scheduled-refresh Task. On each committed authenticated status with a new access-expiry date it cancels the old schedule, sleeps until expiry minus the fixed 60-second leeway, rechecks identity/revision/generation, then calls the repository's single-flight refresh. It records the attempted expiry so failure retaining old dates cannot busy-loop; rotated expiry arms a new schedule. Sign Out, newer login, and teardown cancel both tasks. Every policy transition to or from Restoring, Onboarding, or Maintenance calls `transitionForPolicy(..., historyAction: .preserve)`; explicit scene navigation owns `.reset`. AppRootView has SessionRestoringView and no Authentication root. Set `AppFlowRouter`'s default to `.restoring`, remove the old Authentication launch scenario, and update every test fixture—including `AuthenticationViewModelTests`—to the four-case root. That suite injects its dedicated authentication-actions spy/disabled adapter and no longer passes `FlowRouter` or constructs `.authentication`. Update `makeTestAppFlowCoordinator` in shared TestSupport to accept an explicit `isLocalSessionBootstrapResolved` argument (default true for established Main fixtures), forward it to the new policy signature, and remove obsolete auth commands/conformance. Legacy Authentication views remain compiled but unreachable until Phase 5 by receiving `DisabledLegacyAuthenticationActions`; legacy Settings receives only its distinct `DisabledLegacySettingsAuthenticationActions` until phase 8. Neither adapter is composed into AppRoot or can mutate AppState. Remove `IAuthenticationActions` inheritance from `IAppFlowCoordinator` and remove the old root `signIn`/`signOut` forwarding methods from `AppFlowCoordinator` and `FlowRouter`; session mutation exists only on `ISessionActions`. Controller commits state, revision, and UI-safe expiry as one `SessionStatusPresentation`; validateSession/refreshSession/startup validation/scheduled refresh all map repository snapshots through that same function and expose no bearer value.

~~~swift
if state.isMaintenanceEnabled { return .maintenance }
if !state.hasCompletedOnboarding { return .onboarding }
if !isLocalSessionBootstrapResolved { return .restoring }
return .main
~~~

- [ ] Run PASS, iOS build, and commit.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/SessionControllerTests -only-testing:AppTemplateTests/SessionControllerBootstrapTests -only-testing:AppTemplateTests/SessionStartupValidationTests -only-testing:AppTemplateTests/SessionRefreshSchedulingTests -only-testing:AppTemplateTests/AppFlowPolicyTests -only-testing:AppTemplateTests/AppFlowCoordinatorTests -only-testing:AppTemplateTests/FlowRouterTests -only-testing:AppTemplateTests/AuthenticationViewModelTests -only-testing:AppTemplateTests/SettingsViewModelTests -only-testing:AppTemplateTests/AppDependenciesTests
xcodebuild build -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
git add -A AppTemplate/App/Navigation/Routing/LegacyAuthenticationState.swift AppTemplateTests/App/Navigation/Routing/LegacyAuthenticationStateTests.swift
git add AppTemplate/App/Session/ISessionActions.swift AppTemplate/App/Session/SessionRefreshSchedulePolicy.swift AppTemplate/App/Session/SessionStartupValidationPolicy.swift AppTemplate/App/Session/SessionController.swift AppTemplate/App/Navigation/Containers/SessionRestoringView.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplate/App/Entry/AppTemplateApp.swift AppTemplate/App/Entry/AppLaunchConfiguration.swift AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift AppTemplate/App/PreviewSupport/PreviewFixtures.swift AppTemplate/App/Navigation/Routing/AppFlow.swift AppTemplate/App/Navigation/Routing/AppFlowPolicy.swift AppTemplate/App/Navigation/Routing/AppFlowRouter.swift AppTemplate/App/Navigation/Routing/AppFlowCoordinator.swift AppTemplate/App/Navigation/Containers/AppRootView.swift AppTemplate/App/Navigation/Core/FlowRouter.swift AppTemplate/App/Navigation/Routing/IAppFlowCoordinator.swift AppTemplate/Features/Authentication/Dependencies/DisabledLegacyAuthenticationActions.swift AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift AppTemplateTests/App/Session/SessionControllerTests.swift AppTemplateTests/App/Session/SessionControllerBootstrapTests.swift AppTemplateTests/App/Session/SessionStartupValidationTests.swift AppTemplateTests/App/Session/SessionRefreshSchedulingTests.swift AppTemplateTests/App/Navigation/Routing/AppFlowPolicyTests.swift AppTemplateTests/App/Navigation/Routing/AppFlowCoordinatorTests.swift AppTemplateTests/App/Navigation/Routing/AppFlowRouterTests.swift AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift AppTemplateTests/App/Navigation/Core/FlowRouterTests.swift AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift AppTemplateTests/App/Entry/UITesting/UITestScenarioTests.swift AppTemplateTests/App/Composition/AppDependenciesTests.swift AppTemplateTests/Features/Authentication/Screens/Authentication/AuthenticationViewModelTests.swift AppTemplateTests/Features/Settings/Screens/Settings/SettingsViewModelTests.swift AppTemplateTests/TestSupport/AppFlowCoordinatorSpy.swift
git commit -m "feat: compose app owned session"
~~~

## Phase 3 Verification

- [ ] Run all tests/build and inspect staged paths.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
git status --short
git diff --cached --name-only
~~~
