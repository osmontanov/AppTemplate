import Observation

@MainActor
@Observable
final class MaintenanceViewModel {
    private let maintenanceActions: any IMaintenanceActions

    init(maintenanceActions: any IMaintenanceActions) {
        self.maintenanceActions = maintenanceActions
    }

    func returnToApp() {
        maintenanceActions.setMaintenanceEnabled(false)
    }
}
