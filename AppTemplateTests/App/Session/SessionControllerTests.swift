import Foundation
import Testing
@testable import AppTemplate

struct SessionControllerTests {
    @Test @MainActor func loginCommitsOneAtomicStatusAndOneRevision() async {
        let expiry = SessionExpiryPresentation(
            accessExpiresAt: Date(timeIntervalSince1970: 2_000_000_000),
            refreshExpiresAt: Date(timeIntervalSince1970: 2_000_086_400)
        )
        let snapshot = SessionRepositorySnapshot(
            state: .authenticated(Self.profile, availability: .online),
            expiry: expiry
        )
        let repository = SessionActionsRepository(loginResult: .authenticated(snapshot))
        let controller = SessionController(
            repository: repository,
            clock: .live,
            startupValidationPolicy: .disabled,
            refreshSchedulePolicy: .disabled
        )

        let result = await controller.login(username: "ada", password: "secret")

        #expect(result == .authenticated(snapshot))
        #expect(controller.status == SessionStatusPresentation(
            session: SessionPresentation(state: snapshot.state, revision: 1),
            expiry: expiry
        ))
        #expect(controller.presentation == controller.status.session)
    }

    @Test @MainActor func failedSignOutRetainsAuthenticatedStatus() async {
        let snapshot = SessionRepositorySnapshot(
            state: .authenticated(Self.profile, availability: .online),
            expiry: nil
        )
        let repository = SessionActionsRepository(
            loginResult: .authenticated(snapshot),
            signOutResult: .deletionFailed
        )
        let controller = SessionController(
            repository: repository,
            clock: .live,
            startupValidationPolicy: .disabled,
            refreshSchedulePolicy: .disabled
        )
        _ = await controller.login(username: "ada", password: "secret")

        #expect(await controller.signOut() == .deletionFailed)
        #expect(controller.presentation.state == snapshot.state)
        #expect(controller.presentation.revision == 1)
    }

    private static let profile = UserProfile(
        id: 1,
        username: "ada",
        firstName: "Ada",
        lastName: "Lovelace",
        imageURL: nil
    )
}

private actor SessionActionsRepository: ISessionRepository {
    let loginResult: SessionLoginResult
    let signOutResult: SessionSignOutResult

    init(
        loginResult: SessionLoginResult,
        signOutResult: SessionSignOutResult = .guest
    ) {
        self.loginResult = loginResult
        self.signOutResult = signOutResult
    }

    func beginBootstrapAttempt(_ attemptID: UInt64) {}
    func readBootstrapCandidate(attemptID: UInt64) -> SessionBootstrapReadResult { .staleAttempt }
    func resolveBootstrapCandidate(attemptID: UInt64) -> SessionRepositorySnapshot {
        .init(state: .guest, expiry: nil)
    }
    func invalidateBootstrapAttempt(_ attemptID: UInt64) -> Bool { false }
    func login(username: String, password: String) -> SessionLoginResult { loginResult }
    func signOut() -> SessionSignOutResult { signOutResult }
}
