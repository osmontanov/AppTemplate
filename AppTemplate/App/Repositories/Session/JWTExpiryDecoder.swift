import Foundation

nonisolated enum JWTExpiryDecoder {
    static func expiryDate(from token: String) -> Date? {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3,
              let payload = decodeBase64URL(String(segments[1])),
              let claims = try? JSONDecoder().decode(ExpiryClaims.self, from: payload),
              let expiration = claims.exp
        else {
            return nil
        }

        return Date(timeIntervalSince1970: expiration)
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        guard !value.isEmpty else { return nil }

        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        switch base64.count % 4 {
        case 0:
            break
        case 2:
            base64.append("==")
        case 3:
            base64.append("=")
        default:
            return nil
        }
        return Data(base64Encoded: base64)
    }
}

private nonisolated struct ExpiryClaims: Decodable {
    let exp: Double?
}
