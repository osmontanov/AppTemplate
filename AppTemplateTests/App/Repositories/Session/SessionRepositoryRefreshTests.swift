import Foundation
import Testing
@testable import AppTemplate

struct SessionRepositoryRefreshTests {
    @Test func exactlySixtySecondsRefreshesButSixtyOneSecondsCallsMe() async throws {
        for (remaining, expectedMe, expectedRefresh) in [(61.0, 1, 0), (60.0, 0, 1)] {
            let access = SessionOperationFixtures.jwt(
                exp: SessionOperationFixtures.now.addingTimeInterval(remaining).timeIntervalSince1970
            )
            let envelope = SessionOperationFixtures.envelope(accessToken: access)
            let keychain = SessionOperationKeychain(envelope: envelope)
            let remote = SessionOperationRemote(
                meResults: [.success(UserProfileDTO(
                    id: 1, username: "emilys", firstName: "Emily", lastName: "Johnson",
                    email: "ignored@example.test", image: SessionOperationFixtures.profile.imageURL
                ))],
                refreshResults: [.success(AuthTokensDTO(
                    accessToken: SessionOperationFixtures.accessToken,
                    refreshToken: SessionOperationFixtures.refreshToken
                ))]
            )
            let repository = SessionRepository(
                remote: remote,
                secureStore: SessionSecureStore(keychain: keychain),
                clock: AppClock(
                    now: { SessionOperationFixtures.now },
                    monotonicNow: { ContinuousClock().now },
                    sleep: { _ in }
                )
            )
            await repository.beginBootstrapAttempt(1)
            _ = await repository.readBootstrapCandidate(attemptID: 1)
            _ = await repository.resolveBootstrapCandidate(attemptID: 1)

            _ = await repository.validateStoredSession()
            let counts = await remote.counts()
            #expect(counts.me == expectedMe)
            #expect(counts.refresh == expectedRefresh)
        }
    }

    @Test func forcedRefreshPersistsRotatedTokensBeforeOnlineSnapshot() async {
        let old = SessionOperationFixtures.envelope()
        let rotatedAccess = SessionOperationFixtures.jwt(exp: SessionOperationFixtures.now.addingTimeInterval(7_200).timeIntervalSince1970)
        let rotatedRefresh = SessionOperationFixtures.jwt(exp: SessionOperationFixtures.now.addingTimeInterval(172_800).timeIntervalSince1970)
        let keychain = SessionOperationKeychain(envelope: old)
        let remote = SessionOperationRemote(refreshResults: [
            .success(AuthTokensDTO(accessToken: rotatedAccess, refreshToken: rotatedRefresh))
        ])
        let repository = SessionRepository(remote: remote, secureStore: SessionSecureStore(keychain: keychain))
        await repository.beginBootstrapAttempt(1)
        _ = await repository.readBootstrapCandidate(attemptID: 1)
        _ = await repository.resolveBootstrapCandidate(attemptID: 1)

        let result = await repository.refreshStoredSession()
        guard case let .snapshot(snapshot) = result else {
            Issue.record("Expected refreshed snapshot")
            return
        }
        #expect(snapshot.state == .authenticated(old.profile, availability: .online))
        #expect(await keychain.sessionEnvelope()?.accessToken == rotatedAccess)
        #expect(await keychain.sessionEnvelope()?.refreshToken == rotatedRefresh)
    }

    @Test func authoritativeRefreshRejectionDeletesBeforeGuestAndCleanupFailureIsUnavailable() async {
        let mapped = AuthErrorDTO(message: "mapped")
        for removeFailures in [0, 1] {
            let envelope = SessionOperationFixtures.envelope()
            let keychain = SessionOperationKeychain(envelope: envelope, removeFailures: removeFailures)
            let remote = SessionOperationRemote(refreshResults: [
                .failure(RemoteServiceError.status(code: 401, authenticationError: mapped))
            ])
            let repository = SessionRepository(remote: remote, secureStore: SessionSecureStore(keychain: keychain))
            await repository.beginBootstrapAttempt(1)
            _ = await repository.readBootstrapCandidate(attemptID: 1)
            _ = await repository.resolveBootstrapCandidate(attemptID: 1)

            let result = await repository.refreshStoredSession()
            if removeFailures == 0 {
                #expect(result == .snapshot(SessionRepositorySnapshot(state: .guest, expiry: nil)))
                #expect(await keychain.sessionEnvelope() == nil)
            } else {
                #expect(result == .snapshot(SessionRepositorySnapshot(
                    state: .unavailable(.secureStorageCleanupFailed), expiry: nil
                )))
                #expect(await repository.validateStoredSession() == .unchanged)
            }
        }
    }

    @Test func missingExpiryCallsMeAndForcedRefreshIgnoresFarFutureAccess() async {
        let missingExpiry = SessionOperationFixtures.envelope(accessToken: SessionOperationFixtures.jwt(exp: nil))
        let keychain = SessionOperationKeychain(envelope: missingExpiry)
        let remote = SessionOperationRemote(
            meResults: [.success(UserProfileDTO(
                id: 1, username: "emilys", firstName: "Emily", lastName: "Johnson",
                email: "ignored@example.test", image: SessionOperationFixtures.profile.imageURL
            ))],
            refreshResults: [.success(AuthTokensDTO(
                accessToken: SessionOperationFixtures.accessToken,
                refreshToken: SessionOperationFixtures.refreshToken
            ))]
        )
        let repository = SessionRepository(remote: remote, secureStore: SessionSecureStore(keychain: keychain))
        await repository.beginBootstrapAttempt(1)
        _ = await repository.readBootstrapCandidate(attemptID: 1)
        _ = await repository.resolveBootstrapCandidate(attemptID: 1)

        _ = await repository.validateStoredSession()
        _ = await repository.refreshStoredSession()
        let counts = await remote.counts()
        #expect(counts.me == 1)
        #expect(counts.refresh == 1)
    }

    @Test func refreshWriteFailureRetainsOldDatesAndRetryNeverReplaysRemote() async {
        let old = SessionOperationFixtures.envelope()
        let rotatedAccess = SessionOperationFixtures.jwt(exp: 2_100_000_000)
        let rotatedRefresh = SessionOperationFixtures.jwt(exp: 2_200_000_000)
        let keychain = SessionOperationKeychain(envelope: old, writeFailures: 1)
        let remote = SessionOperationRemote(refreshResults: [
            .success(AuthTokensDTO(accessToken: rotatedAccess, refreshToken: rotatedRefresh))
        ])
        let repository = SessionRepository(remote: remote, secureStore: SessionSecureStore(keychain: keychain))
        await repository.beginBootstrapAttempt(1)
        _ = await repository.readBootstrapCandidate(attemptID: 1)
        _ = await repository.resolveBootstrapCandidate(attemptID: 1)

        let result = await repository.refreshStoredSession()
        guard case let .persistenceFailed(retained, token) = result else {
            Issue.record("Expected refresh persistence retry")
            return
        }
        #expect(retained.expiry == SessionExpiryPresentation(
            accessExpiresAt: old.accessExpiresAt,
            refreshExpiresAt: old.refreshExpiresAt
        ))
        #expect(retained.state == .authenticated(old.profile, availability: .offline(.secureStorageWriteFailed)))

        _ = await repository.retryPersistence(token)
        #expect(await remote.counts().refresh == 1)
        #expect(await keychain.sessionEnvelope()?.refreshToken == rotatedRefresh)
    }

    @Test func simultaneousForcedAndExpiryRefreshesJoinOneFlightAndWrite() async {
        let oldAccess = SessionOperationFixtures.jwt(
            exp: SessionOperationFixtures.now.addingTimeInterval(60).timeIntervalSince1970
        )
        let old = SessionOperationFixtures.envelope(accessToken: oldAccess)
        let keychain = SessionOperationKeychain(envelope: old)
        let remote = SharedRefreshRemote()
        let repository = SessionRepository(
            remote: remote,
            secureStore: SessionSecureStore(keychain: keychain),
            clock: AppClock(
                now: { SessionOperationFixtures.now },
                monotonicNow: { ContinuousClock().now },
                sleep: { _ in }
            )
        )
        await repository.beginBootstrapAttempt(1)
        _ = await repository.readBootstrapCandidate(attemptID: 1)
        _ = await repository.resolveBootstrapCandidate(attemptID: 1)

        let validation = Task { await repository.validateStoredSession() }
        await remote.waitUntilRefreshStarts()
        let forced1 = Task { await repository.refreshStoredSession() }
        let forced2 = Task { await repository.refreshStoredSession() }
        await remote.releaseRefresh()
        _ = await (validation.value, forced1.value, forced2.value)

        #expect(await remote.refreshCalls == 1)
        #expect(await keychain.counts().writes == 1)
    }

#if DEBUG
    @Test func tokenFreeSemanticProbeRefreshesAndRetriesExactlyOnce() async {
        let old = SessionOperationFixtures.envelope()
        let keychain = SessionOperationKeychain(envelope: old)
        let mapped = AuthErrorDTO(message: "mapped")
        let remote = SessionOperationRemote(
            meResults: [
                .failure(RemoteServiceError.status(code: 401, authenticationError: mapped)),
                .success(UserProfileDTO(
                    id: 1, username: "emilys", firstName: "Emily", lastName: "Johnson",
                    email: "ignored@example.test", image: SessionOperationFixtures.profile.imageURL
                ))
            ],
            refreshResults: [.success(AuthTokensDTO(
                accessToken: SessionOperationFixtures.jwt(exp: 2_100_000_000),
                refreshToken: SessionOperationFixtures.jwt(exp: 2_200_000_000)
            ))]
        )
        let repository = SessionRepository(remote: remote, secureStore: SessionSecureStore(keychain: keychain))
        await repository.beginBootstrapAttempt(1)
        _ = await repository.readBootstrapCandidate(attemptID: 1)
        _ = await repository.resolveBootstrapCandidate(attemptID: 1)

        _ = await repository.authenticatedOperationProbeForTesting()
        let counts = await remote.counts()
        #expect(counts.me == 2)
        #expect(counts.refresh == 1)
    }
#endif
}

actor SharedRefreshRemote: IRemoteService {
    private(set) var refreshCalls = 0
    private var started = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO {
        refreshCalls += 1
        started = true
        let waiters = startWaiters
        startWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        await withCheckedContinuation { releaseContinuation = $0 }
        return AuthTokensDTO(
            accessToken: SessionOperationFixtures.jwt(exp: 2_100_000_000),
            refreshToken: SessionOperationFixtures.jwt(exp: 2_200_000_000)
        )
    }

    func waitUntilRefreshStarts() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func releaseRefresh() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func fetchExample(_ request: ExampleRequest) async throws -> ExampleResponse { throw SessionOperationFailure.injected }
    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO { throw SessionOperationFailure.injected }
    func categories() async throws -> [ProductCategoryDTO] { throw SessionOperationFailure.injected }
    func product(id: Int) async throws -> ProductDTO { throw SessionOperationFailure.injected }
    func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO { throw SessionOperationFailure.injected }
    func me(accessToken: String) async throws -> UserProfileDTO { throw SessionOperationFailure.injected }
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO { throw SessionOperationFailure.injected }
}
