import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AppFlowCoordinatorTests {
    @Test
    func completingOnboardingPersistsAndPreservesPendingIntentAtAuthentication()
        throws {
        let sut = try makeSUT(state: .initial)

        sut.coordinator.completeOnboarding()

        #expect(sut.store.state.hasCompletedOnboarding)
        #expect(!sut.store.state.isAuthenticated)
        #expect(!sut.store.state.isMaintenanceEnabled)
        #expect(sut.storage.savedData.count == 1)
        #expect(sut.router.flow == .authentication)
        #expect(sut.router.transition.pendingIntentAction == .preserve)
    }

    @Test
    func signInRoutesThroughMaintenanceAndPreservesPendingIntent() throws {
        let state = AppState(
            isAuthenticated: false,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let sut = try makeSUT(state: state)

        sut.coordinator.signIn()

        #expect(sut.store.state.isAuthenticated)
        #expect(sut.router.flow == .maintenance)
        #expect(sut.router.transition.pendingIntentAction == .preserve)
    }

    @Test
    func disablingMaintenanceEntersMainAndReplaysPendingIntent() throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let sut = try makeSUT(state: state)

        sut.coordinator.setMaintenanceEnabled(false)

        #expect(!sut.store.state.isMaintenanceEnabled)
        #expect(sut.router.flow == .main)
        #expect(sut.router.transition.pendingIntentAction == .replay)
    }

    @Test
    func changedLowerPriorityFlagWritesWithoutResettingVisibleFlow() throws {
        let state = AppState(
            isAuthenticated: false,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(state: state)
        let transition = sut.router.transition

        let result = sut.coordinator.setMaintenanceEnabled(true)

        #expect(
            result
                == .applied(
                    flow: .authentication,
                    didTransition: false
                )
        )
        #expect(sut.store.state.isMaintenanceEnabled)
        #expect(sut.storage.savedData.count == 1)
        #expect(sut.router.transition == transition)
    }

    @Test
    func unchangedFlagReconcilesAnInconsistentTemporaryFlowWithoutWriting()
        throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(state: state, visibleFlow: .onboarding)

        sut.coordinator.completeOnboarding()

        #expect(sut.storage.savedData.isEmpty)
        #expect(sut.router.flow == .main)
        #expect(sut.router.transition.pendingIntentAction == .replay)
    }

    @Test
    func repeatedConsistentCommandDoesNotWriteOrTransition() throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(state: state)
        let transition = sut.router.transition

        sut.coordinator.signIn()

        #expect(sut.storage.savedData.isEmpty)
        #expect(sut.router.transition == transition)
    }

    @Test
    func rejectedSignInDoesNotChangeStateOrRootTransition() throws {
        let sut = try makeSUT(
            state: .initial,
            saveError: StorageError.failed
        )
        let transition = sut.router.transition

        let result = sut.coordinator.signIn()

        #expect(result == .rejected(.saveFailed))
        #expect(sut.store.state == .initial)
        #expect(sut.router.transition == transition)
    }

    @Test
    func unchangedPolicyActionReturnsUnchanged() throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(state: state)

        #expect(sut.coordinator.signIn() == .unchanged)
    }

    @Test
    func unchangedStateCanReconcileInfrastructureFlowDrift() throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(state: state, visibleFlow: .onboarding)

        #expect(
            sut.coordinator.signIn()
                == .applied(flow: .main, didTransition: true)
        )
    }

    @Test
    func effectiveSignOutPreservesOtherFlagsAndForcesSameFlowDiscard() throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let sut = try makeSUT(state: state, visibleFlow: .authentication)
        let previousID = sut.router.transition.id

        sut.coordinator.signOut()

        #expect(!sut.store.state.isAuthenticated)
        #expect(sut.store.state.hasCompletedOnboarding)
        #expect(sut.store.state.isMaintenanceEnabled)
        #expect(sut.router.flow == .authentication)
        #expect(sut.router.transition.id != previousID)
        #expect(sut.router.transition.pendingIntentAction == .discard)
    }

    @Test
    func restartOnboardingChangesOnlyTheOnboardingFlag() throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let sut = try makeSUT(state: state)

        sut.coordinator.restartOnboarding()

        #expect(sut.store.state.isAuthenticated)
        #expect(!sut.store.state.hasCompletedOnboarding)
        #expect(sut.store.state.isMaintenanceEnabled)
        #expect(sut.router.flow == .onboarding)
    }

    @Test
    func enablingMaintenanceChangesOnlyTheMaintenanceFlag() throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(state: state)

        sut.coordinator.setMaintenanceEnabled(true)

        #expect(sut.store.state.isAuthenticated)
        #expect(sut.store.state.hasCompletedOnboarding)
        #expect(sut.store.state.isMaintenanceEnabled)
        #expect(sut.router.flow == .maintenance)
    }
}

@MainActor
private struct CoordinatorSUT {
    let storage: AppStateStorageSpy
    let store: AppStateStore
    let router: AppFlowRouter
    let coordinator: AppFlowCoordinator
}

@MainActor
private func makeSUT(
    state: AppState,
    visibleFlow: AppFlow? = nil,
    saveError: (any Error)? = nil
) throws -> CoordinatorSUT {
    let storage = AppStateStorageSpy(
        loadResult: .data(try JSONEncoder().encode(state)),
        saveError: saveError
    )
    let store = AppStateStore(storage: storage)
    let router = AppFlowRouter(
        flow: visibleFlow ?? AppFlowPolicy.resolve(state)
    )
    return CoordinatorSUT(
        storage: storage,
        store: store,
        router: router,
        coordinator: AppFlowCoordinator(
            store: store,
            appFlowRouter: router
        )
    )
}

private enum StorageError: Error {
    case failed
}
