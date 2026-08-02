@MainActor
protocol IAuthenticationActions: AnyObject {
    @discardableResult
    func signIn() -> AppFlowActionResult

    @discardableResult
    func signOut() -> AppFlowActionResult
}
