import Testing
@testable import AppTemplate

@MainActor
struct LegacyAuthenticationStateTests {
    @Test
    func defaultsToSignedOut() {
        #expect(!LegacyAuthenticationState().isAuthenticated)
    }

    @Test
    func signInAuthenticatesAndRepeatedSignInIsIdempotent() {
        let state = LegacyAuthenticationState()

        state.signIn()
        state.signIn()

        #expect(state.isAuthenticated)
    }

    @Test
    func signOutDeauthenticatesAndRepeatedSignOutIsIdempotent() {
        let state = LegacyAuthenticationState(isAuthenticated: true)

        state.signOut()
        state.signOut()

        #expect(!state.isAuthenticated)
    }
}
