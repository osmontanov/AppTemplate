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
        let urlWithPath = target.baseURL.appending(path: target.path)
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

        if !target.task.queryItems.isEmpty {
            components.queryItems =
                (components.queryItems ?? []) + target.task.queryItems
        }

        guard let url = components.url else {
            throw NetworkError.requestConstruction
        }

        var request = URLRequest(url: url)
        request.httpMethod = target.method.rawValue

        if let body = target.task.body {
            try apply(body, to: &request)
        }

        for (name, value) in target.headers {
            let normalizedName =
                name.caseInsensitiveCompare("Content-Type") == .orderedSame
                ? "Content-Type"
                : name
            request.setValue(value, forHTTPHeaderField: normalizedName)
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
