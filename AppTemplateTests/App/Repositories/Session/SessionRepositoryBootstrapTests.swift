import Foundation
import Testing
@testable import AppTemplate

struct SessionRepositoryBootstrapTests {
    private let sessionKey = KeychainKey.data("Store.AuthSession")

    @Test func missingRecordResolvesGuestWithoutExpiryOrMutation() async {
        let keychain = KeychainServiceSpy()
        let repository = makeRepository(keychain: keychain)

        await repository.beginBootstrapAttempt(1)
        #expect(await repository.readBootstrapCandidate(attemptID: 1) == .candidateReady)
        #expect(await repository.resolveBootstrapCandidate(attemptID: 1) ==
            SessionRepositorySnapshot(state: .guest, expiry: nil))
        #expect(await keychain.callCounts().writes == 0)
        #expect(await keychain.callCounts().removals == 0)
    }

    @Test func currentEnvelopeResolvesValidatingWithExactUISafeExpiry() async throws {
        let envelope = fixtureEnvelope()
        let keychain = KeychainServiceSpy(storage: [
            sessionKey: try JSONEncoder().encode(envelope)
        ])
        let repository = makeRepository(keychain: keychain)

        await repository.beginBootstrapAttempt(7)
        #expect(await repository.readBootstrapCandidate(attemptID: 7) == .candidateReady)
        #expect(await repository.resolveBootstrapCandidate(attemptID: 7) ==
            SessionRepositorySnapshot(
                state: .authenticated(envelope.profile, availability: .validating),
                expiry: SessionExpiryPresentation(
                    accessExpiresAt: envelope.accessExpiresAt,
                    refreshExpiresAt: envelope.refreshExpiresAt
                )
            ))
    }

    @Test func corruptOwnedRecordIsRemovedBeforeResolvingGuest() async {
        let keychain = KeychainServiceSpy(storage: [sessionKey: Data("not-json".utf8)])
        let repository = makeRepository(keychain: keychain)

        await repository.beginBootstrapAttempt(2)
        #expect(await repository.readBootstrapCandidate(attemptID: 2) == .candidateReady)
        #expect(await repository.resolveBootstrapCandidate(attemptID: 2) ==
            SessionRepositorySnapshot(state: .guest, expiry: nil))
        #expect(await keychain.storedData(for: sessionKey) == nil)
        #expect(await keychain.callCounts().removals == 1)
        #expect(await keychain.callCounts().writes == 0)
    }

    @Test func corruptCleanupFailureResolvesUnavailableAndPreservesRecord() async {
        let bytes = Data("not-json".utf8)
        let keychain = KeychainServiceSpy(
            storage: [sessionKey: bytes],
            beforeRemove: { throw BootstrapTestFailure.injected }
        )
        let repository = makeRepository(keychain: keychain)

        await repository.beginBootstrapAttempt(3)
        #expect(await repository.readBootstrapCandidate(attemptID: 3) == .candidateReady)
        #expect(await repository.resolveBootstrapCandidate(attemptID: 3) ==
            SessionRepositorySnapshot(
                state: .unavailable(.secureStorageCleanupFailed),
                expiry: nil
            ))
        #expect(await keychain.storedData(for: sessionKey) == bytes)
        #expect(await keychain.callCounts().removals == 1)
        #expect(await keychain.callCounts().writes == 0)
    }

    @Test func unsupportedFutureEnvelopeIsUnavailableAndNeverMutated() async {
        let bytes = Data(
            #"{"schemaVersion":2,"profile":"future","accessToken":{"opaque":true}}"#.utf8
        )
        let keychain = KeychainServiceSpy(storage: [sessionKey: bytes])
        let repository = makeRepository(keychain: keychain)

        await repository.beginBootstrapAttempt(4)
        #expect(await repository.readBootstrapCandidate(attemptID: 4) == .candidateReady)
        #expect(await repository.resolveBootstrapCandidate(attemptID: 4) ==
            SessionRepositorySnapshot(
                state: .unavailable(.secureStorageReadFailed),
                expiry: nil
            ))
        #expect(await keychain.storedData(for: sessionKey) == bytes)
        let counts = await keychain.callCounts()
        #expect(counts.removals == 0)
        #expect(counts.writes == 0)
    }

    @Test func systemReadFailureResolvesUnavailableWithoutMutation() async {
        let keychain = KeychainServiceSpy(beforeRead: {
            throw BootstrapTestFailure.injected
        })
        let repository = makeRepository(keychain: keychain)

        await repository.beginBootstrapAttempt(5)
        #expect(await repository.readBootstrapCandidate(attemptID: 5) == .readFailed)
        #expect(await repository.resolveBootstrapCandidate(attemptID: 5) ==
            SessionRepositorySnapshot(
                state: .unavailable(.secureStorageReadFailed),
                expiry: nil
            ))
        let counts = await keychain.callCounts()
        #expect(counts.removals == 0)
        #expect(counts.writes == 0)
    }

    @Test func invalidationMakesNoncooperativeLateReadStaleAndUnresolvable() async throws {
        let readGate = BootstrapReadGate()
        let envelope = fixtureEnvelope()
        let keychain = KeychainServiceSpy(
            storage: [sessionKey: try JSONEncoder().encode(envelope)],
            beforeReadAsync: { await readGate.suspendFirstRead() }
        )
        let repository = makeRepository(keychain: keychain)

        await repository.beginBootstrapAttempt(10)
        let readTask = Task {
            await repository.readBootstrapCandidate(attemptID: 10)
        }
        await readGate.waitUntilFirstReadStarts()
        #expect(await repository.invalidateBootstrapAttempt(10))
        await readGate.releaseFirstRead()
        #expect(await readTask.value == .staleAttempt)
        #expect(await repository.resolveBootstrapCandidate(attemptID: 10) ==
            SessionRepositorySnapshot(
                state: .unavailable(.secureStorageReadFailed),
                expiry: nil
            ))
    }

    private func makeRepository(keychain: KeychainServiceSpy) -> SessionRepository {
        SessionRepository(
            remote: BootstrapUnusedRemoteService(),
            secureStore: SessionSecureStore(keychain: keychain)
        )
    }

    private func fixtureEnvelope() -> StoredSessionEnvelope {
        StoredSessionEnvelope(
            schemaVersion: 1,
            profile: UserProfile(
                id: 42,
                username: "bootstrap-reader",
                firstName: "Grace",
                lastName: "Hopper",
                imageURL: URL(string: "https://example.test/grace.png")
            ),
            accessToken: "actor-confined-access",
            refreshToken: "actor-confined-refresh",
            accessExpiresAt: Date(timeIntervalSince1970: 1_800_000_123),
            refreshExpiresAt: Date(timeIntervalSince1970: 1_800_086_523)
        )
    }
}

private enum BootstrapTestFailure: Error {
    case injected
}

actor BootstrapReadGate {
    private var firstReadStarted = false
    private var firstReadRelease: CheckedContinuation<Void, Never>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func suspendFirstRead() async {
        guard !firstReadStarted else { return }
        firstReadStarted = true
        let waiters = startWaiters
        startWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        await withCheckedContinuation { firstReadRelease = $0 }
    }

    func waitUntilFirstReadStarts() async {
        guard !firstReadStarted else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func releaseFirstRead() {
        firstReadRelease?.resume()
        firstReadRelease = nil
    }
}

actor BootstrapUnusedRemoteService: IRemoteService {
    func fetchExample(_ request: ExampleRequest) async throws -> ExampleResponse {
        throw BootstrapTestFailure.injected
    }
    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO {
        throw BootstrapTestFailure.injected
    }
    func categories() async throws -> [ProductCategoryDTO] {
        throw BootstrapTestFailure.injected
    }
    func product(id: Int) async throws -> ProductDTO {
        throw BootstrapTestFailure.injected
    }
    func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO {
        throw BootstrapTestFailure.injected
    }
    func me(accessToken: String) async throws -> UserProfileDTO {
        throw BootstrapTestFailure.injected
    }
    func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO {
        throw BootstrapTestFailure.injected
    }
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO {
        throw BootstrapTestFailure.injected
    }
}
