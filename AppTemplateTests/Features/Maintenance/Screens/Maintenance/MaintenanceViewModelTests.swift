import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct MaintenanceViewModelTests {
    @Test
    func leavingMaintenanceOpensMain() {
        let appFlowRouter = AppFlowRouter(flow: .maintenance)
        let router = FlowRouter(appFlowRouter: appFlowRouter)
        let viewModel = MaintenanceViewModel(router: router)

        viewModel.returnToApp()

        #expect(appFlowRouter.flow == .main)
    }

    @Test
    func maintenanceFlowAndScreenCanBeConstructed() {
        let router = FlowRouter()

        _ = MaintenanceFlowView(router: router)
        _ = MaintenanceView(router: router)
    }
}
