import Foundation
import Testing
@testable import AppTemplate

struct SessionRepositoryLoginTests {
    @Test func loginPersistsBeforePublishingAndRetryDoesNotReplayRemote() async throws {
        let keychain = SessionOperationKeychain(writeFailures: 1)
        let remote = SessionOperationRemote(loginResults: [
            .success(SessionOperationFixtures.loginSession())
        ])
        let repository = SessionRepository(
            remote: remote,
            secureStore: SessionSecureStore(keychain: keychain)
        )

        let first = await repository.login(username: "emilys", password: "password-sentinel")
        guard case let .failure(.persistenceFailed(token)) = first else {
            Issue.record("Expected persistence retry")
            return
        }
        #expect(await keychain.sessionEnvelope() == nil)

        let retry = await repository.retryPersistence(token)
        guard case let .committed(snapshot) = retry else {
            Issue.record("Expected committed retry")
            return
        }
        #expect(snapshot.state == .authenticated(SessionOperationFixtures.profile, availability: .online))
        #expect(await remote.counts().login == 1)
        #expect(await keychain.counts().writes == 2)
        #expect(await keychain.sessionEnvelope()?.refreshToken == SessionOperationFixtures.refreshToken)
    }

    @Test func loginClassifierRowsMapExactlyAndNeverWrite() async {
        let mapped = AuthErrorDTO(message: "mapped")
        let rows: [(Error, SessionLoginResult)] = [
            (RemoteServiceError.status(code: 401, authenticationError: mapped), .failure(.invalidCredentials)),
            (RemoteServiceError.transport, .failure(.transport)),
            (RemoteServiceError.status(code: 503, authenticationError: nil), .failure(.serverUnavailable)),
            (RemoteServiceError.status(code: 429, authenticationError: nil), .failure(.rateLimited)),
            (RemoteServiceError.invalidResponse, .failure(.responseInvalid)),
            (SessionOperationFailure.injected, .failure(.responseInvalid)),
            (RemoteServiceError.cancelled, .cancelled),
            (CancellationError(), .cancelled)
        ]

        for (error, expected) in rows {
            let keychain = SessionOperationKeychain()
            let remote = SessionOperationRemote(loginResults: [.failure(error)])
            let repository = SessionRepository(
                remote: remote,
                secureStore: SessionSecureStore(keychain: keychain)
            )
            #expect(await repository.login(username: "user", password: "secret") == expected)
            #expect(await keychain.counts().writes == 0)
        }
    }

    @Test func resultDescriptionsContainNoCredentialSentinels() async {
        let access = SessionOperationFixtures.accessToken
        let refresh = SessionOperationFixtures.refreshToken
        let values: [Any] = [
            SessionLoginResult.failure(.responseInvalid),
            SessionPersistenceRetryResult.invalidToken,
            SessionRepositoryValidationResult.failed(.responseInvalid),
            SessionValidationResult.failed(.responseInvalid),
            SessionSignOutResult.deletionFailed,
            SessionPresentationError.secureStorageWriteFailed
        ]
        for value in values {
            let descriptions = [String(describing: value), String(reflecting: value)]
            #expect(descriptions.allSatisfy { !$0.contains(access) && !$0.contains(refresh) })
        }
    }

    @Test func repeatedRetryFailureRotatesOpaqueTokenAndMismatchedDiscardDoesNothing() async {
        let keychain = SessionOperationKeychain(writeFailures: 2)
        let remote = SessionOperationRemote(loginResults: [
            .success(SessionOperationFixtures.loginSession())
        ])
        let repository = SessionRepository(remote: remote, secureStore: SessionSecureStore(keychain: keychain))
        let first = await repository.login(username: "emilys", password: "secret")
        guard case let .failure(.persistenceFailed(firstToken)) = first else {
            Issue.record("Expected first persistence token")
            return
        }
        let retry = await repository.retryPersistence(firstToken)
        guard case let .failed(secondToken, retained) = retry else {
            Issue.record("Expected rotated persistence token")
            return
        }
        #expect(firstToken != secondToken)
        #expect(retained == SessionRepositorySnapshot(state: .guest, expiry: nil))
        #expect(await repository.retryPersistence(firstToken) == .invalidToken)

        await repository.discardPersistenceRetry(firstToken)
        #expect(await repository.retryPersistence(secondToken) != .invalidToken)
    }

    @Test func simultaneousSecondLoginIsRejectedAndLaterLoginIsAccepted() async {
        let remote = LoginBarrierRemote()
        let repository = SessionRepository(
            remote: remote,
            secureStore: SessionSecureStore(keychain: SessionOperationKeychain())
        )
        let first = Task { await repository.login(username: "first", password: "secret") }
        await remote.waitUntilLoginStarts()

        #expect(await repository.login(username: "second", password: "secret") == .failure(.concurrentAttempt))
        await remote.releaseLogin()
        guard case .authenticated = await first.value else {
            Issue.record("Expected first login to finish")
            return
        }

        guard case .authenticated = await repository.login(username: "third", password: "secret") else {
            Issue.record("Expected later login to be accepted")
            return
        }
        #expect(await remote.loginCalls == 2)
    }
}

actor LoginBarrierRemote: IRemoteService {
    private(set) var loginCalls = 0
    private var started = false
    private var didSuspend = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO {
        loginCalls += 1
        if !didSuspend {
            didSuspend = true
            started = true
            let waiters = startWaiters
            startWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
            await withCheckedContinuation { releaseContinuation = $0 }
        }
        return SessionOperationFixtures.loginSession()
    }

    func waitUntilLoginStarts() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func releaseLogin() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO { throw SessionOperationFailure.injected }
    func categories() async throws -> [ProductCategoryDTO] { throw SessionOperationFailure.injected }
    func product(id: Int) async throws -> ProductDTO { throw SessionOperationFailure.injected }
    func me(accessToken: String) async throws -> UserProfileDTO { throw SessionOperationFailure.injected }
    func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO { throw SessionOperationFailure.injected }
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO { throw SessionOperationFailure.injected }
}

enum SessionOperationFailure: Error { case injected }

nonisolated enum SessionOperationFixtures {
    static let now = Date(timeIntervalSince1970: 2_000_000_000)
    static let accessToken = jwt(exp: now.addingTimeInterval(3_600).timeIntervalSince1970)
    static let refreshToken = jwt(exp: now.addingTimeInterval(86_400).timeIntervalSince1970)
    static let profile = UserProfile(
        id: 1,
        username: "emilys",
        firstName: "Emily",
        lastName: "Johnson",
        imageURL: URL(string: "https://example.test/emily.png")
    )

    static func jwt(exp: TimeInterval?) -> String {
        let payload: String
        if let exp { payload = #"{"exp":\#(exp)}"# } else { payload = "{}" }
        return "header.\(Data(payload.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")).signature"
    }

    static func loginSession(
        accessToken: String = accessToken,
        refreshToken: String = refreshToken
    ) -> AuthSessionDTO {
        AuthSessionDTO(
            id: profile.id,
            username: profile.username,
            firstName: profile.firstName,
            lastName: profile.lastName,
            email: "email-is-not-session-state@example.test",
            image: profile.imageURL,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    static func envelope(
        accessToken: String = accessToken,
        refreshToken: String = refreshToken
    ) -> StoredSessionEnvelope {
        StoredSessionEnvelope(
            schemaVersion: StoredSessionEnvelope.currentSchemaVersion,
            profile: profile,
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessExpiresAt: JWTExpiryDecoder.expiryDate(from: accessToken),
            refreshExpiresAt: JWTExpiryDecoder.expiryDate(from: refreshToken)
        )
    }
}

actor SessionOperationRemote: IRemoteService {
    private var loginResults: [Result<AuthSessionDTO, Error>]
    private var meResults: [Result<UserProfileDTO, Error>]
    private var refreshResults: [Result<AuthTokensDTO, Error>]
    private var loginCallCount = 0
    private var meCallCount = 0
    private var refreshCallCount = 0

    init(
        loginResults: [Result<AuthSessionDTO, Error>] = [],
        meResults: [Result<UserProfileDTO, Error>] = [],
        refreshResults: [Result<AuthTokensDTO, Error>] = []
    ) {
        self.loginResults = loginResults
        self.meResults = meResults
        self.refreshResults = refreshResults
    }

    func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO {
        loginCallCount += 1
        guard !loginResults.isEmpty else { throw SessionOperationFailure.injected }
        return try loginResults.removeFirst().get()
    }

    func me(accessToken: String) async throws -> UserProfileDTO {
        meCallCount += 1
        guard !meResults.isEmpty else { throw SessionOperationFailure.injected }
        return try meResults.removeFirst().get()
    }

    func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO {
        refreshCallCount += 1
        guard !refreshResults.isEmpty else { throw SessionOperationFailure.injected }
        return try refreshResults.removeFirst().get()
    }

    func counts() -> (login: Int, me: Int, refresh: Int) {
        (loginCallCount, meCallCount, refreshCallCount)
    }

    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO { throw SessionOperationFailure.injected }
    func categories() async throws -> [ProductCategoryDTO] { throw SessionOperationFailure.injected }
    func product(id: Int) async throws -> ProductDTO { throw SessionOperationFailure.injected }
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO { throw SessionOperationFailure.injected }
}

actor SessionOperationKeychain: IKeychainService {
    private let sessionKey = KeychainKey.data("Store.AuthSession")
    private var storage: [KeychainKey: Data]
    private var remainingWriteFailures: Int
    private var remainingRemoveFailures: Int
    private var writeCount = 0
    private var removeCount = 0

    init(
        envelope: StoredSessionEnvelope? = nil,
        writeFailures: Int = 0,
        removeFailures: Int = 0
    ) {
        if let envelope, let data = try? JSONEncoder().encode(envelope) {
            storage = [sessionKey: data]
        } else {
            storage = [:]
        }
        remainingWriteFailures = writeFailures
        remainingRemoveFailures = removeFailures
    }

    func data(for key: KeychainKey) async throws -> Data? { storage[key] }

    func set(_ data: Data, for key: KeychainKey) async throws {
        writeCount += 1
        if remainingWriteFailures > 0 {
            remainingWriteFailures -= 1
            throw SessionOperationFailure.injected
        }
        storage[key] = data
    }

    func remove(_ key: KeychainKey) async throws -> Bool {
        removeCount += 1
        if remainingRemoveFailures > 0 {
            remainingRemoveFailures -= 1
            throw SessionOperationFailure.injected
        }
        return storage.removeValue(forKey: key) != nil
    }

    func counts() -> (writes: Int, removals: Int) { (writeCount, removeCount) }
    func sessionEnvelope() -> StoredSessionEnvelope? {
        guard let data = storage[sessionKey] else { return nil }
        return try? JSONDecoder().decode(StoredSessionEnvelope.self, from: data)
    }
}
