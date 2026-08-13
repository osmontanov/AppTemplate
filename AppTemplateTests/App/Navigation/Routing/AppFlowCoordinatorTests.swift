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
        #expect(!sut.legacyAuthentication.isAuthenticated)
        #expect(!sut.store.state.isMaintenanceEnabled)
        #expect(sut.storage.savedData.count == 1)
        #expect(sut.router.flow == .authentication)
        #expect(sut.router.transition.pendingIntentAction == .preserve)
    }

    @Test
    func signInRoutesThroughMaintenanceWithoutPersistingAuthentication() throws {
        let state = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let sut = try makeSUT(state: state)

        sut.coordinator.signIn()

        #expect(sut.legacyAuthentication.isAuthenticated)
        #expect(sut.storage.savedData.isEmpty)
        #expect(sut.router.flow == .maintenance)
        #expect(sut.router.transition.pendingIntentAction == .preserve)
    }

    @Test
    func disablingMaintenanceEntersMainAndReplaysPendingIntent() throws {
        let state = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let sut = try makeSUT(state: state, isAuthenticated: true)

        sut.coordinator.setMaintenanceEnabled(false)

        #expect(!sut.store.state.isMaintenanceEnabled)
        #expect(sut.router.flow == .main)
        #expect(sut.router.transition.pendingIntentAction == .replay)
    }

    @Test
    func changedLowerPriorityFlagWritesWithoutResettingVisibleFlow() throws {
        let state = AppState(
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
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(
            state: state,
            isAuthenticated: true,
            visibleFlow: .onboarding
        )

        sut.coordinator.completeOnboarding()

        #expect(sut.storage.savedData.isEmpty)
        #expect(sut.router.flow == .main)
        #expect(sut.router.transition.pendingIntentAction == .replay)
    }

    @Test
    func repeatedConsistentSignInDoesNotWriteOrTransition() throws {
        let state = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(state: state, isAuthenticated: true)
        let transition = sut.router.transition

        sut.coordinator.signIn()

        #expect(sut.storage.savedData.isEmpty)
        #expect(sut.router.transition == transition)
    }

    @Test
    func signInStillWorksWhenPolicyPersistenceIsReadOnly() throws {
        let state = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(
            state: state,
            saveError: StorageError.failed
        )
        #expect(
            sut.coordinator.setMaintenanceEnabled(true)
                == .rejected(.saveFailed)
        )

        let result = sut.coordinator.signIn()

        #expect(result == .applied(flow: .main, didTransition: true))
        #expect(sut.legacyAuthentication.isAuthenticated)
        #expect(sut.store.persistenceStatus == .readOnly(.saveFailed))
        #expect(sut.storage.savedData.isEmpty)
    }

    @Test
    func unchangedPolicyActionReturnsUnchanged() throws {
        let state = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(state: state, isAuthenticated: true)

        #expect(sut.coordinator.signIn() == .unchanged)
    }

    @Test
    func unchangedAuthenticationCanReconcileInfrastructureFlowDrift() throws {
        let state = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(
            state: state,
            isAuthenticated: true,
            visibleFlow: .onboarding
        )

        #expect(
            sut.coordinator.signIn()
                == .applied(flow: .main, didTransition: true)
        )
    }

    @Test
    func effectiveSignOutPreservesPolicyAndForcesSameFlowDiscard() throws {
        let state = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let sut = try makeSUT(
            state: state,
            isAuthenticated: true,
            visibleFlow: .authentication
        )
        let previousID = sut.router.transition.id

        sut.coordinator.signOut()

        #expect(!sut.legacyAuthentication.isAuthenticated)
        #expect(sut.store.state.hasCompletedOnboarding)
        #expect(sut.store.state.isMaintenanceEnabled)
        #expect(sut.storage.savedData.isEmpty)
        #expect(sut.router.flow == .authentication)
        #expect(sut.router.transition.id != previousID)
        #expect(sut.router.transition.pendingIntentAction == .discard)
    }

    @Test
    func restartOnboardingChangesOnlyTheOnboardingFlag() throws {
        let state = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let sut = try makeSUT(state: state, isAuthenticated: true)

        sut.coordinator.restartOnboarding()

        #expect(sut.legacyAuthentication.isAuthenticated)
        #expect(!sut.store.state.hasCompletedOnboarding)
        #expect(sut.store.state.isMaintenanceEnabled)
        #expect(sut.router.flow == .onboarding)
    }

    @Test
    func enablingMaintenanceChangesOnlyTheMaintenanceFlag() throws {
        let state = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let sut = try makeSUT(state: state, isAuthenticated: true)

        sut.coordinator.setMaintenanceEnabled(true)

        #expect(sut.legacyAuthentication.isAuthenticated)
        #expect(sut.store.state.hasCompletedOnboarding)
        #expect(sut.store.state.isMaintenanceEnabled)
        #expect(sut.router.flow == .maintenance)
    }
}

@MainActor
private struct CoordinatorSUT {
    let storage: AppStateStorageSpy
    let store: AppStateStore
    let legacyAuthentication: LegacyAuthenticationState
    let router: AppFlowRouter
    let coordinator: AppFlowCoordinator
}

@MainActor
private func makeSUT(
    state: AppState,
    isAuthenticated: Bool = false,
    visibleFlow: AppFlow? = nil,
    saveError: (any Error)? = nil
) throws -> CoordinatorSUT {
    let storage = AppStateStorageSpy(
        loadResult: .data(try JSONEncoder().encode(state)),
        saveError: saveError
    )
    let store = AppStateStore(storage: storage)
    let legacyAuthentication = LegacyAuthenticationState(
        isAuthenticated: isAuthenticated
    )
    let router = AppFlowRouter(
        flow: visibleFlow ?? AppFlowPolicy.resolve(
            state,
            legacyAuthentication: legacyAuthentication
        )
    )
    return CoordinatorSUT(
        storage: storage,
        store: store,
        legacyAuthentication: legacyAuthentication,
        router: router,
        coordinator: AppFlowCoordinator(
            store: store,
            appFlowRouter: router,
            legacyAuthentication: legacyAuthentication
        )
    )
}

private enum StorageError: Error {
    case failed
}
