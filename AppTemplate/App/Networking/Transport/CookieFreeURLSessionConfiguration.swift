import Foundation

nonisolated
enum CookieFreeURLSessionConfiguration {
    static func make(
        timeout: TimeInterval = 15,
        protocolClasses: [AnyClass]? = nil
    ) -> URLSessionConfiguration {
        let configuration = EphemeralURLSessionConfiguration.make(
            timeout: timeout,
            protocolClasses: protocolClasses
        )
        configuration.httpShouldSetCookies = false
        return configuration
    }
}

nonisolated
enum EphemeralURLSessionConfiguration {
    static func make(
        timeout: TimeInterval = 15,
        protocolClasses: [AnyClass]? = nil
    ) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        return configuration
    }
}
