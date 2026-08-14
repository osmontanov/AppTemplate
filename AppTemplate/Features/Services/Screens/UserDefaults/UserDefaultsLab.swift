import Foundation

nonisolated enum UserDefaultsLabKind: String, CaseIterable, Sendable {
    case bool
    case int
    case float
    case double
    case string
    case data
    case date
    case codable

    var title: String {
        switch self {
        case .bool: "Bool"
        case .int: "Int"
        case .float: "Float"
        case .double: "Double"
        case .string: "String"
        case .data: "Data"
        case .date: "Date"
        case .codable: "Codable"
        }
    }
}

nonisolated struct UserDefaultsLabCodable: Codable, Equatable, Sendable {
    let number: Int
    let label: String
}

nonisolated enum UserDefaultsLabKeys {
    static let bool = UserDefaultsKey<Bool>.bool("Bool")
    static let int = UserDefaultsKey<Int>.int("Int")
    static let float = UserDefaultsKey<Float>.float("Float")
    static let double = UserDefaultsKey<Double>.double("Double")
    static let string = UserDefaultsKey<String>.string("String")
    static let data = UserDefaultsKey<Data>.data("Data")
    static let date = UserDefaultsKey<Date>.date("Date")
    static let codable = UserDefaultsKey<UserDefaultsLabCodable>.codable("Codable")

    static let allLogicalNames: Set<String> = [
        bool.logicalName,
        int.logicalName,
        float.logicalName,
        double.logicalName,
        string.logicalName,
        data.logicalName,
        date.logicalName,
        codable.logicalName
    ]
}

nonisolated enum UserDefaultsLabFixtures {
    static let bool = true
    static let int = 42
    static let float = Float(1.25)
    static let double = Double(2.5)
    static let string = "Hello from UserDefaults"
    static let data = Data([0x00, 0x2A, 0x7F, 0xFF])
    static let date = Date(timeIntervalSince1970: 1_700_000_000)
    static let codable = UserDefaultsLabCodable(number: 7, label: "Demo model")
}
