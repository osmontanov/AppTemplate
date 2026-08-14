@MainActor
struct AuthenticationDependencies {
    let session: any ISessionActions
    let cancellation: any IAuthenticationCancellation
}
