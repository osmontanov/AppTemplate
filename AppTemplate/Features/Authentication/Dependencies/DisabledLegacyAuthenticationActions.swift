@MainActor
final class DisabledLegacyAuthenticationActions: IAuthenticationActions {
    func signIn() -> AppFlowActionResult { .unchanged }
    func signOut() -> AppFlowActionResult { .unchanged }
}
