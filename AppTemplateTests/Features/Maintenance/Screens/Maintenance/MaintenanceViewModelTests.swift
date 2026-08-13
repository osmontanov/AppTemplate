import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct MaintenanceViewModelTests {
    @Test
    func returnToAppDisablesMaintenance() {
        let coordinator = makeTestAppFlowCoordinator(
            state: AppState(
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: true
            ),
            isAuthenticated: true
        )
        let viewModel = MaintenanceViewModel(
            maintenanceActions: coordinator
        )

        viewModel.returnToApp()

        #expect(coordinator.appFlowRouter.flow == .main)
    }

    @Test
    func maintenanceFlowAndScreenCanBeConstructed() {
        let router = makeTestFlowRouter()

        _ = MaintenanceFlowView(router: router)
        _ = MaintenanceView(router: router)
    }
}
