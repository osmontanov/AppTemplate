@MainActor
protocol IMaintenanceActions: AnyObject {
    @discardableResult
    func setMaintenanceEnabled(_ isEnabled: Bool) -> AppFlowActionResult
}
