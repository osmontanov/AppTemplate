import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct MaintenanceViewModelTests {
    @Test
    func leavingMaintenanceOpensMain() {
        let coordinator = makeTestAppFlowCoordinator(visibleFlow: .maintenance)
        let appFlowRouter = coordinator.appFlowRouter
        let router = FlowRouter(appFlowCoordinator: coordinator)
        let viewModel = MaintenanceViewModel(router: router)

        viewModel.returnToApp()

        #expect(appFlowRouter.flow == .main)
    }

    @Test
    func maintenanceFlowAndScreenCanBeConstructed() {
        let router = makeTestFlowRouter()

        _ = MaintenanceFlowView(router: router)
        _ = MaintenanceView(router: router)
    }
}
