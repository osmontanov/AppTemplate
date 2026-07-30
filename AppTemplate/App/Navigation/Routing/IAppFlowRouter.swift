@MainActor
protocol IAppFlowRouter: AnyObject {
    func setFlow(_ flow: AppFlow)
}
