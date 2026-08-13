import Foundation
import Testing
@testable import AppTemplate

struct EphemeralURLSessionConfigurationTests {
    @Test
    func ephemeralConfigurationHasNoPersistentStores() {
        let configuration = EphemeralURLSessionConfiguration.make()

        #expect(configuration.timeoutIntervalForRequest == 15)
        #expect(configuration.timeoutIntervalForResource == 15)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.urlCache == nil)
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.urlCredentialStorage == nil)
    }

    @Test
    func ephemeralConfigurationAcceptsCustomTimeoutAndProtocolFixtures() {
        let configuration = EphemeralURLSessionConfiguration.make(
            timeout: 7,
            protocolClasses: [CredentialRedirectFixtureURLProtocol.self]
        )

        #expect(configuration.timeoutIntervalForRequest == 7)
        #expect(configuration.timeoutIntervalForResource == 7)
        #expect(configuration.protocolClasses?.count == 1)
        #expect(configuration.protocolClasses?.first === CredentialRedirectFixtureURLProtocol.self)
    }
}
