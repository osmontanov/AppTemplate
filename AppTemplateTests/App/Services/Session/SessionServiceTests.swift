import Testing
@testable import AppTemplate

struct SessionServiceTests {
    @Test
    func sessionLifecycleUsesTheDeclaredInterface() async throws {
        let service: any ISessionService = SessionService(
            initialSession: nil
        )

        #expect(try await service.currentSession() == nil)

        let signedIn = try await service.signIn()
        #expect(signedIn.id == "template-user")
        #expect(try await service.currentSession() == signedIn)

        try await service.signOut()
        #expect(try await service.currentSession() == nil)
    }
}
