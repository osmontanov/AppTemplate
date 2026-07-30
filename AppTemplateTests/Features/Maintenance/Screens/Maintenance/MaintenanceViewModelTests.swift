import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct MaintenanceViewModelTests {
    @Test
    func returnToAppDisablesMaintenance() {
        let coordinator = AppFlowCoordinatorSpy()
        let viewModel = MaintenanceViewModel(
            router: FlowRouter(appFlowCoordinator: coordinator)
        )

        viewModel.returnToApp()

        #expect(
            coordinator.commands == [.setMaintenanceEnabled(false)]
        )
    }

    @Test
    func maintenanceFlowAndScreenCanBeConstructed() {
        let router = makeTestFlowRouter()

        _ = MaintenanceFlowView(router: router)
        _ = MaintenanceView(router: router)
    }
}
