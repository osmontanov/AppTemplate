import Foundation

nonisolated enum KeychainLabKind: String, CaseIterable, Sendable {
    case data
    case string
    case codable

    var title: String {
        switch self {
        case .data: "Data"
        case .string: "String"
        case .codable: "Codable"
        }
    }
}

nonisolated struct KeychainLabCodable: Codable, Equatable, Sendable {
    let number: Int
    let label: String
}

nonisolated enum KeychainLabKeys {
    static let data = KeychainKey.data("Data")
    static let string = KeychainKey.data("String")
    static let codable = KeychainCodableKey<KeychainLabCodable>.codable(
        "Codable",
        schemaVersion: 1
    )

    static var allPhysicalAccounts: Set<String> {
        [data.account, string.account, codable.account]
    }
}

nonisolated enum KeychainLabFixtures {
    static let data = Data([0x10, 0x2A, 0x7F, 0xFF])
    static let string = "Secure demo value"
    static let codable = KeychainLabCodable(number: 7, label: "Secure model")
}
