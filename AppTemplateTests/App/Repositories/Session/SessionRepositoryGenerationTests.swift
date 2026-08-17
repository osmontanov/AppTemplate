import Foundation
import Testing
@testable import AppTemplate

struct SessionRepositoryGenerationTests {
    @Test func signOutRemovalFailureRetainsAdoptedAuthentication() async {
        let envelope = SessionOperationFixtures.envelope()
        let keychain = SessionOperationKeychain(envelope: envelope, removeFailures: 1)
        let repository = SessionRepository(
            remote: SessionOperationRemote(),
            secureStore: SessionSecureStore(keychain: keychain)
        )
        await repository.beginBootstrapAttempt(1)
        _ = await repository.readBootstrapCandidate(attemptID: 1)
        let initial = await repository.resolveBootstrapCandidate(attemptID: 1)
        #expect(initial.state == .authenticated(envelope.profile, availability: .validating))

        #expect(await repository.signOut() == .deletionFailed)
        #expect(await keychain.sessionEnvelope() == envelope)
        // The failed sign-out must leave the session usable, not half-erased.
        #expect(await repository.validateStoredSession() != .unchanged)
    }

    @Test func acceptedNewLoginInvalidatesPersistenceRetryToken() async {
        let keychain = SessionOperationKeychain(writeFailures: 1)
        let remote = SessionOperationRemote(loginResults: [
            .success(SessionOperationFixtures.loginSession()),
            .success(SessionOperationFixtures.loginSession())
        ])
        let repository = SessionRepository(remote: remote, secureStore: SessionSecureStore(keychain: keychain))
        let first = await repository.login(username: "first", password: "secret")
        guard case let .failure(.persistenceFailed(token)) = first else {
            Issue.record("Expected persistence retry")
            return
        }

        _ = await repository.login(username: "second", password: "secret")
        #expect(await repository.retryPersistence(token) == .invalidToken)
    }

    @Test func bootstrapSnapshotSignatureRemainsUISafe() async {
        let repository: any ISessionRepository = SessionRepository(
            remote: SessionOperationRemote(),
            secureStore: SessionSecureStore(keychain: SessionOperationKeychain())
        )
        await repository.beginBootstrapAttempt(77)
        _ = await repository.readBootstrapCandidate(attemptID: 77)
        let snapshot: SessionRepositorySnapshot = await repository.resolveBootstrapCandidate(attemptID: 77)
        #expect(snapshot == SessionRepositorySnapshot(state: .guest, expiry: nil))
    }

    @Test func cancellationDuringNoncooperativeLoginWriteRestoresPreviousRecord() async throws {
        let old = SessionOperationFixtures.envelope()
        let keychain = SessionMutationBarrierKeychain(envelope: old, barrier: .write)
        let replacementAccess = SessionOperationFixtures.jwt(exp: 2_100_000_000)
        let remote = SessionOperationRemote(loginResults: [
            .success(SessionOperationFixtures.loginSession(accessToken: replacementAccess))
        ])
        let repository = SessionRepository(remote: remote, secureStore: SessionSecureStore(keychain: keychain))
        await repository.beginBootstrapAttempt(1)
        _ = await repository.readBootstrapCandidate(attemptID: 1)
        _ = await repository.resolveBootstrapCandidate(attemptID: 1)

        let login = Task { await repository.login(username: "replacement", password: "secret") }
        await keychain.waitUntilBarrierStarts()
        login.cancel()
        await keychain.releaseBarrier()

        #expect(await login.value == .cancelled)
        #expect(await keychain.sessionEnvelope() == old)
    }

    @Test func cancellationDuringNoncooperativeSignOutRestoresRetainedRecord() async throws {
        let old = SessionOperationFixtures.envelope()
        let keychain = SessionMutationBarrierKeychain(envelope: old, barrier: .remove)
        let repository = SessionRepository(
            remote: SessionOperationRemote(),
            secureStore: SessionSecureStore(keychain: keychain)
        )
        await repository.beginBootstrapAttempt(1)
        _ = await repository.readBootstrapCandidate(attemptID: 1)
        _ = await repository.resolveBootstrapCandidate(attemptID: 1)

        let signOut = Task { await repository.signOut() }
        await keychain.waitUntilBarrierStarts()
        signOut.cancel()
        await keychain.releaseBarrier()

        #expect(await signOut.value == .cancelled)
        #expect(await keychain.sessionEnvelope() == old)
    }

    @Test func refreshDuringSignOutRemovalDoesNotResurrectSession() async {
        let envelope = SessionOperationFixtures.envelope()
        let keychain = SessionMutationBarrierKeychain(envelope: envelope, barrier: .remove)
        let remote = SessionOperationRemote()
        let repository = SessionRepository(
            remote: remote,
            secureStore: SessionSecureStore(keychain: keychain)
        )
        await repository.beginBootstrapAttempt(1)
        _ = await repository.readBootstrapCandidate(attemptID: 1)
        _ = await repository.resolveBootstrapCandidate(attemptID: 1)

        let signOut = Task { await repository.signOut() }
        await keychain.waitUntilBarrierStarts()
        let refresh = await repository.refreshStoredSession()
        let validation = await repository.validateStoredSession()
        await keychain.releaseBarrier()

        #expect(refresh == .unchanged)
        #expect(validation == .unchanged)
        #expect(await signOut.value == .guest)
        #expect(await remote.counts().refresh == 0)
        #expect(await remote.counts().me == 0)
        #expect(await keychain.sessionEnvelope() == nil)
    }

    @Test func cancelledSignOutBeforeRemovalKeepsSessionAndStorageAgreeing() async {
        let envelope = SessionOperationFixtures.envelope()
        let keychain = SessionMutationBarrierKeychain(envelope: envelope, barrier: .remove)
        let repository = SessionRepository(
            remote: SessionOperationRemote(),
            secureStore: SessionSecureStore(keychain: keychain)
        )
        await repository.beginBootstrapAttempt(1)
        _ = await repository.readBootstrapCandidate(attemptID: 1)
        _ = await repository.resolveBootstrapCandidate(attemptID: 1)

        let signOut = Task { await repository.signOut() }
        await keychain.waitUntilBarrierStarts()
        signOut.cancel()
        await keychain.releaseBarrier()

        #expect(await signOut.value == .cancelled)
        #expect(await keychain.sessionEnvelope() == envelope)
        // Storage still holds the record, so the repository must still adopt it.
        #expect(await repository.validateStoredSession() != .unchanged)
    }
}

actor SessionMutationBarrierKeychain: IKeychainService {
    enum Barrier { case write, remove }

    private let sessionKey = KeychainKey.data("Store.AuthSession")
    private let barrier: Barrier
    private var storage: [KeychainKey: Data]
    private var barrierStarted = false
    private var barrierConsumed = false
    private var barrierContinuation: CheckedContinuation<Void, Never>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    init(envelope: StoredSessionEnvelope, barrier: Barrier) {
        self.barrier = barrier
        storage = [sessionKey: try! JSONEncoder().encode(envelope)]
    }

    func data(for key: KeychainKey) async throws -> Data? { storage[key] }

    func set(_ data: Data, for key: KeychainKey) async throws {
        if barrier == .write { await suspendAtBarrier() }
        storage[key] = data
    }

    func remove(_ key: KeychainKey) async throws -> Bool {
        let removed = storage.removeValue(forKey: key) != nil
        if barrier == .remove { await suspendAtBarrier() }
        return removed
    }

    func waitUntilBarrierStarts() async {
        guard !barrierStarted else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func releaseBarrier() {
        barrierContinuation?.resume()
        barrierContinuation = nil
    }

    func sessionEnvelope() -> StoredSessionEnvelope? {
        guard let data = storage[sessionKey] else { return nil }
        return try? JSONDecoder().decode(StoredSessionEnvelope.self, from: data)
    }

    private func suspendAtBarrier() async {
        guard !barrierConsumed else { return }
        barrierConsumed = true
        barrierStarted = true
        let waiters = startWaiters
        startWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        await withCheckedContinuation { barrierContinuation = $0 }
    }
}
