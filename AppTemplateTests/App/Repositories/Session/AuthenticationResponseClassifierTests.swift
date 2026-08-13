import Testing
@testable import AppTemplate

struct AuthenticationResponseClassifierTests {
    private let mappedBody = AuthErrorDTO(message: "mapped")

    @Test func endpointSpecificMappedRejectionsUseOnlyDocumentedRows() {
        let cases: [(AuthEndpoint, Int, AuthFailureDisposition)] = [
            (.login, 400, .invalidCredentials),
            (.login, 401, .invalidCredentials),
            (.login, 403, .invalidCredentials),
            (.me, 401, .refreshRequired),
            (.me, 403, .refreshRequired),
            (.refresh, 400, .credentialsRejected),
            (.refresh, 401, .credentialsRejected),
            (.refresh, 403, .credentialsRejected)
        ]

        for (endpoint, code, expected) in cases {
            #expect(
                AuthenticationResponseClassifier.classify(
                    .status(code: code, authenticationError: mappedBody),
                    endpoint: endpoint
                ) == expected
            )
        }
    }

    @Test func infrastructureAndCancellationFailuresPrecedeAuthenticationBodies() {
        let cases: [(RemoteServiceError, AuthFailureDisposition)] = [
            (.cancelled, .cancelled),
            (.transport, .transport),
            (.invalidResponse, .responseInvalid),
            (.status(code: 408, authenticationError: nil), .serverUnavailable),
            (.status(code: 408, authenticationError: mappedBody), .serverUnavailable),
            (.status(code: 500, authenticationError: nil), .serverUnavailable),
            (.status(code: 503, authenticationError: mappedBody), .serverUnavailable),
            (.status(code: 599, authenticationError: nil), .serverUnavailable),
            (.status(code: 429, authenticationError: nil), .rateLimited),
            (.status(code: 429, authenticationError: mappedBody), .rateLimited)
        ]

        for (error, expected) in cases {
            #expect(
                AuthenticationResponseClassifier.classify(
                    error,
                    endpoint: .login
                ) == expected
            )
        }
    }

    @Test func missingOrUnmappedAuthenticationBodiesAreResponseInvalid() {
        let cases: [(AuthEndpoint, Int, AuthErrorDTO?)] = [
            (.login, 400, nil),
            (.me, 401, nil),
            (.refresh, 403, nil),
            (.me, 400, mappedBody),
            (.login, 404, mappedBody),
            (.refresh, 418, mappedBody),
            (.refresh, 204, nil)
        ]

        for (endpoint, code, body) in cases {
            #expect(
                AuthenticationResponseClassifier.classify(
                    .status(code: code, authenticationError: body),
                    endpoint: endpoint
                ) == .responseInvalid
            )
        }
    }

    @Test func unknownRefreshStatusCannotReject() {
        #expect(AuthenticationResponseClassifier.classify(
            .status(code: 418, authenticationError: mappedBody),
            endpoint: .refresh
        ) == .responseInvalid)
    }
}
