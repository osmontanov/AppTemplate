import Foundation
import Testing
@testable import AppTemplate

nonisolated struct FirstSecret: Codable, Equatable, Sendable { let value: Int }
nonisolated struct SecondSecret: Codable, Equatable, Sendable { let text: String }
nonisolated struct UnicodeSecret: Codable, Equatable, Sendable {
    let title: String
    let enabled: Bool
}

nonisolated struct SentinelCodecError:
    Error,
    LocalizedError,
    CustomStringConvertible,
    Sendable
{
    let description: String
    var errorDescription: String? { description }
}

nonisolated struct FailingEncodeSecret: Codable, Sendable {
    init() {}
    init(from decoder: any Decoder) throws {
        throw SentinelCodecError(
            description: "SECRET-DECODE-PAYLOAD at codingPath.session.token"
        )
    }
    func encode(to encoder: any Encoder) throws {
        throw SentinelCodecError(
            description: "SECRET-ENCODE-PAYLOAD at codingPath.session.token"
        )
    }
}

nonisolated struct FailingDecodeSecret: Codable, Sendable {
    init(from decoder: any Decoder) throws {
        throw SentinelCodecError(
            description: "SECRET-DECODE-PAYLOAD at codingPath.session.token"
        )
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(0)
    }
}

nonisolated struct CancellingCodecSecret: Codable, Sendable {
    init() {}
    init(from decoder: any Decoder) throws { throw CancellationError() }
    func encode(to encoder: any Encoder) throws { throw CancellationError() }
}

nonisolated func assertRedacted(
    _ error: any Error,
    expected: KeychainServiceError,
    forbidden: [String]
) {
    #expect(error as? KeychainServiceError == expected)
    let rendered = [
        String(describing: error),
        String(reflecting: error),
        (error as NSError).localizedDescription
    ]
    for sentinel in forbidden {
        #expect(rendered.allSatisfy { !$0.contains(sentinel) })
    }
}
