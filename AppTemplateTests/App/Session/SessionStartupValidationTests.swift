import Foundation
import Testing
@testable import AppTemplate

struct SessionStartupValidationTests {
    @Test @MainActor func authenticatedBootstrapReturnsBeforeRetainedValidationCompletes() async {
        let repository = StartupValidationRepository(snapshot: Self.validatingSnapshot)
        let controller = SessionController(
            repository: repository,
            startupValidationPolicy: .automatic,
            refreshSchedulePolicy: .disabled
        )

        await controller.bootstrap()
        await repository.waitUntilValidationStarts()

        #expect(controller.isLocalBootstrapResolved)
        #expect(controller.presentation.state == Self.validatingSnapshot.state)
        #expect(await repository.validationCount == 1)

        await repository.releaseValidation(with: .snapshot(.init(
            state: .authenticated(Self.profile, availability: .online),
            expiry: Self.validatingSnapshot.expiry
        )))
        for _ in 0..<10 { await Task.yield() }
        #expect(controller.presentation.state == .authenticated(Self.profile, availability: .online))
        #expect(controller.presentation.revision == 2)
    }

    @Test @MainActor func disabledAndGuestBootstrapStartNoValidation() async {
        let disabled = StartupValidationRepository(snapshot: Self.validatingSnapshot)
        let disabledController = SessionController(
            repository: disabled,
            startupValidationPolicy: .disabled,
            refreshSchedulePolicy: .disabled
        )
        await disabledController.bootstrap()

        let guest = StartupValidationRepository(snapshot: .init(state: .guest, expiry: nil))
        let guestController = SessionController(
            repository: guest,
            startupValidationPolicy: .automatic,
            refreshSchedulePolicy: .disabled
        )
        await guestController.bootstrap()
        for _ in 0..<10 { await Task.yield() }

        #expect(await disabled.validationCount == 0)
        #expect(await guest.validationCount == 0)
    }

    @Test @MainActor func suspendedValidationDoesNotRetainController() async {
        let repository = StartupValidationRepository(snapshot: Self.validatingSnapshot)
        var controller: SessionController? = SessionController(
            repository: repository,
            startupValidationPolicy: .automatic,
            refreshSchedulePolicy: .disabled
        )
        weak let weakController = controller
        await controller?.bootstrap()
        await repository.waitUntilValidationStarts()

        controller = nil

        #expect(weakController == nil)
        await repository.releaseValidation(with: .unchanged)
    }

    private static let profile = UserProfile(
        id: 7, username: "grace", firstName: "Grace", lastName: "Hopper", imageURL: nil
    )
    private static let validatingSnapshot = SessionRepositorySnapshot(
        state: .authenticated(profile, availability: .validating),
        expiry: .init(accessExpiresAt: nil, refreshExpiresAt: nil)
    )
}

private actor StartupValidationRepository: ISessionRepository {
    let snapshot: SessionRepositorySnapshot
    private(set) var validationCount = 0
    private var validationContinuation: CheckedContinuation<SessionRepositoryValidationResult, Never>?
    private var validationWaiters: [CheckedContinuation<Void, Never>] = []

    init(snapshot: SessionRepositorySnapshot) { self.snapshot = snapshot }
    func beginBootstrapAttempt(_ attemptID: UInt64) {}
    func readBootstrapCandidate(attemptID: UInt64) -> SessionBootstrapReadResult { .candidateReady }
    func resolveBootstrapCandidate(attemptID: UInt64) -> SessionRepositorySnapshot { snapshot }
    func invalidateBootstrapAttempt(_ attemptID: UInt64) -> Bool { false }
    func validateStoredSession() async -> SessionRepositoryValidationResult {
        validationCount += 1
        let waiters = validationWaiters
        validationWaiters.removeAll()
        waiters.forEach { $0.resume() }
        return await withCheckedContinuation { validationContinuation = $0 }
    }
    func waitUntilValidationStarts() async {
        guard validationCount == 0 else { return }
        await withCheckedContinuation { validationWaiters.append($0) }
    }
    func releaseValidation(with result: SessionRepositoryValidationResult) {
        validationContinuation?.resume(returning: result)
        validationContinuation = nil
    }
}
