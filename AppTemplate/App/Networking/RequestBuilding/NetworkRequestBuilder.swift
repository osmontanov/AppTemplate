import Foundation

nonisolated
struct NetworkRequestBuilder: Sendable {
    private let jsonEncoderFactory: @Sendable () -> JSONEncoder

    init(
        jsonEncoderFactory: @escaping @Sendable () -> JSONEncoder = {
            JSONEncoder()
        }
    ) {
        self.jsonEncoderFactory = jsonEncoderFactory
    }

    func build<Target: NetworkTarget>(_ target: Target) throws -> URLRequest {
        let baseURL = target.baseURL
        let path = target.path
        let method = target.method
        let task = target.task
        let headers = target.headers
        let shouldHandleCookies = target.shouldHandleCookies

        let urlWithPath = path.isEmpty ? baseURL : baseURL.appending(path: path)
        guard
            var components = URLComponents(
                url: urlWithPath,
                resolvingAgainstBaseURL: false
            ),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            components.host?.isEmpty == false
        else {
            throw NetworkError.requestConstruction
        }

        if !task.queryItems.isEmpty {
            var appended = URLComponents()
            appended.queryItems = task.queryItems
            guard let appendedQuery = appended.percentEncodedQuery else {
                throw NetworkError.requestConstruction
            }

            if let existingQuery = components.percentEncodedQuery, !existingQuery.isEmpty {
                components.percentEncodedQuery = existingQuery + "&" + appendedQuery
            } else {
                components.percentEncodedQuery = appendedQuery
            }
        }

        guard let url = components.url else {
            throw NetworkError.requestConstruction
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpShouldHandleCookies = shouldHandleCookies

        if let body = task.body {
            try apply(body, to: &request)
        }

        for field in headers.fields {
            request.setValue(field.value, forHTTPHeaderField: field.name)
        }

        return request
    }

    private func apply(
        _ body: NetworkBody,
        to request: inout URLRequest
    ) throws {
        switch body {
        case let .json(payload):
            do {
                request.httpBody = try jsonEncoderFactory().encode(payload)
            } catch {
                throw NetworkError.requestEncoding(underlying: error)
            }
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )

        case let .data(data, contentType):
            request.httpBody = data
            if let contentType {
                request.setValue(
                    contentType,
                    forHTTPHeaderField: "Content-Type"
                )
            }
        }
    }
}
