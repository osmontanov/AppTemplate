import CoreFoundation
import Foundation

nonisolated enum ScriptedNetworkResult: Equatable, Sendable {
    case response(statusCode: Int, headers: HTTPHeaders, body: Data)
    case failure(ScriptedNetworkFailure)
}

nonisolated enum ScriptedNetworkFailure: Error, Equatable, Sendable {
    case cancelled
    case transport
}

nonisolated enum ScriptedBodyExpectation: Equatable, Sendable {
    case none
    case exact(Data)
    case json(Data)
}

nonisolated struct ScriptedNetworkStep: Equatable, Sendable {
    let origin: URL
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: HTTPHeaders
    let shouldHandleCookies: Bool?
    let body: ScriptedBodyExpectation
    let result: ScriptedNetworkResult

    func matches(_ request: URLRequest) -> Bool {
        guard let url = request.url,
              normalizedOrigin(origin) == normalizedOrigin(url),
              request.httpMethod == method.rawValue,
              url.path == path,
              canonicalQueryItems(url) == canonicalQueryItems(queryItems),
              headersMatch(request),
              shouldHandleCookies.map({ request.httpShouldHandleCookies == $0 }) ?? true,
              bodyMatches(request.httpBody)
        else { return false }
        return true
    }

    func response(for request: URLRequest) throws -> (Data, URLResponse) {
        switch result {
        case let .failure(error):
            throw error
        case let .response(statusCode, responseHeaders, responseBody):
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: Dictionary(
                        uniqueKeysWithValues: responseHeaders.fields.map { ($0.name, $0.value) }
                    )
                  )
            else { throw ScriptedNetworkFailure.transport }
            return (responseBody, response)
        }
    }

    private func normalizedOrigin(_ url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              components.fragment == nil
        else { return nil }
        let effectivePort = components.port ?? (scheme == "https" ? 443 : scheme == "http" ? 80 : -1)
        guard effectivePort > 0 else { return nil }
        return "\(scheme)://\(host):\(effectivePort)"
    }

    private func canonicalQueryItems(_ url: URL) -> [CanonicalQueryItem] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return canonicalQueryItems(items)
    }

    private func canonicalQueryItems(_ items: [URLQueryItem]) -> [CanonicalQueryItem] {
        items.map { CanonicalQueryItem(name: $0.name, value: $0.value) }.sorted()
    }

    private func headersMatch(_ request: URLRequest) -> Bool {
        for field in headers.fields where request.value(forHTTPHeaderField: field.name) != field.value {
            return false
        }
        for sensitive in ["Authorization", "Cookie", "Proxy-Authorization"]
        where headers[sensitive] == nil && request.value(forHTTPHeaderField: sensitive) != nil {
            return false
        }
        return true
    }

    private func bodyMatches(_ actual: Data?) -> Bool {
        switch body {
        case .none:
            return actual == nil
        case let .exact(expected):
            return actual == expected
        case let .json(expected):
            guard let actual,
                  let lhs = try? JSONSerialization.jsonObject(with: expected, options: [.fragmentsAllowed]),
                  let rhs = try? JSONSerialization.jsonObject(with: actual, options: [.fragmentsAllowed])
            else { return false }
            return jsonEqual(lhs, rhs)
        }
    }

    private func jsonEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        switch (lhs, rhs) {
        case let (left as [String: Any], right as [String: Any]):
            return left.keys == right.keys && left.allSatisfy { key, value in
                guard let other = right[key] else { return false }
                return jsonEqual(value, other)
            }
        case let (left as [Any], right as [Any]):
            return left.count == right.count && zip(left, right).allSatisfy(jsonEqual)
        case let (left as NSNumber, right as NSNumber):
            let leftIsBoolean = CFGetTypeID(left) == CFBooleanGetTypeID()
            let rightIsBoolean = CFGetTypeID(right) == CFBooleanGetTypeID()
            return leftIsBoolean == rightIsBoolean && left == right
        case let (left as String, right as String):
            return left == right
        case (_ as NSNull, _ as NSNull):
            return true
        default:
            return false
        }
    }
}

private nonisolated struct CanonicalQueryItem: Equatable, Comparable {
    let name: String
    let value: String?

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.name != rhs.name { return lhs.name < rhs.name }
        switch (lhs.value, rhs.value) {
        case (nil, nil): return false
        case (nil, _): return true
        case (_, nil): return false
        case let (left?, right?): return left < right
        }
    }
}
