import Testing
@testable import AppTemplate

struct LocalDatabaseServiceTests {
    @Test
    func concreteExampleSatisfiesTheEmptyInterface() {
        let service: any ILocalDatabaseService = LocalDatabaseService()

        #expect(service is LocalDatabaseService)
    }
}
