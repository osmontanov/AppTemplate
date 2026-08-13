import Foundation
import Testing
@testable import AppTemplate

struct CookieFreeURLSessionConfigurationTests {
    @Test
    func credentialConfigurationHasNoAmbientState() {
        let configuration = CookieFreeURLSessionConfiguration.make()

        #expect(configuration.timeoutIntervalForRequest == 15)
        #expect(configuration.timeoutIntervalForResource == 15)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.urlCache == nil)
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.urlCredentialStorage == nil)
        #expect(configuration.httpShouldSetCookies == false)
    }

    @Test
    func credentialConfigurationAcceptsProtocolFixtures() {
        let configuration = CookieFreeURLSessionConfiguration.make(
            protocolClasses: [CredentialRedirectFixtureURLProtocol.self]
        )

        #expect(configuration.protocolClasses?.count == 1)
        #expect(configuration.protocolClasses?.first === CredentialRedirectFixtureURLProtocol.self)
    }
}
