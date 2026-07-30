import Testing
@testable import AppTemplate

struct RemoteServiceTests {
    @Test
    func concreteExampleSatisfiesTheEmptyInterface() {
        let service: any IRemoteService = RemoteService()

        #expect(service is RemoteService)
    }
}
