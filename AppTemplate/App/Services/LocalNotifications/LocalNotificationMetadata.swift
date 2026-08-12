import Foundation

nonisolated indirect enum LocalNotificationMetadataValue: Hashable, Sendable { case string(String), integer(Int64), double(Double), boolean(Bool), array([LocalNotificationMetadataValue]), object([String: LocalNotificationMetadataValue]), null }
nonisolated extension LocalNotificationMetadataValue: Codable {
    private enum CodingKeys: String, CodingKey { case type, value }
    private enum Tag: String, Codable { case string, integer, double, boolean, array, object, null }
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Tag.self, forKey: .type) {
        case .string: self = .string(try container.decode(String.self, forKey: .value))
        case .integer: self = .integer(try container.decode(Int64.self, forKey: .value))
        case .double: let value = try container.decode(Double.self, forKey: .value); guard value.isFinite else { throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Metadata double must be finite") }; self = .double(value)
        case .boolean: self = .boolean(try container.decode(Bool.self, forKey: .value))
        case .array: self = .array(try container.decode([Self].self, forKey: .value))
        case .object: let value = try container.decode([String: Self].self, forKey: .value); guard (try? LocalNotificationValidator.validate(metadata: .object(value))) != nil else { throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Invalid metadata object") }; self = .object(value)
        case .null: self = .null
        }
    }
    func encode(to encoder: any Encoder) throws {
        try LocalNotificationValidator.validate(metadata: self); var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .string(value): try container.encode(Tag.string, forKey: .type); try container.encode(value, forKey: .value)
        case let .integer(value): try container.encode(Tag.integer, forKey: .type); try container.encode(value, forKey: .value)
        case let .double(value): try container.encode(Tag.double, forKey: .type); try container.encode(value, forKey: .value)
        case let .boolean(value): try container.encode(Tag.boolean, forKey: .type); try container.encode(value, forKey: .value)
        case let .array(value): try container.encode(Tag.array, forKey: .type); try container.encode(value, forKey: .value)
        case let .object(value): try container.encode(Tag.object, forKey: .type); try container.encode(value, forKey: .value)
        case .null: try container.encode(Tag.null, forKey: .type)
        }
    }
}
