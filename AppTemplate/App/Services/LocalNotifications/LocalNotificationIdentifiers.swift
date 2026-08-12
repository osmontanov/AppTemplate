import Foundation

nonisolated
enum LocalNotificationIdentifierKind: String, Codable, CaseIterable, Hashable, Sendable {
    case request
    case category
    case action
    case attachment
}

nonisolated
struct LocalNotificationID: Hashable, Codable, Sendable {
    let value: String

    init(_ value: String) throws {
        try LocalNotificationIdentifierValidator.validate(value, kind: .request, maximumBytes: 128)
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard (try? LocalNotificationIdentifierValidator.validate(value, kind: .request, maximumBytes: 128)) != nil else {
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Invalid local notification request identifier")
        }
        self.value = value
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

nonisolated
struct LocalNotificationCategoryID: Hashable, Codable, Sendable {
    let value: String

    init(_ value: String) throws {
        try LocalNotificationIdentifierValidator.validate(value, kind: .category, maximumBytes: 128)
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard (try? LocalNotificationIdentifierValidator.validate(value, kind: .category, maximumBytes: 128)) != nil else {
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Invalid local notification category identifier")
        }
        self.value = value
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

nonisolated
struct LocalNotificationActionID: Hashable, Codable, Sendable {
    let value: String

    init(_ value: String) throws {
        try LocalNotificationIdentifierValidator.validate(value, kind: .action, maximumBytes: 128)
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard (try? LocalNotificationIdentifierValidator.validate(value, kind: .action, maximumBytes: 128)) != nil else {
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Invalid local notification action identifier")
        }
        self.value = value
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

nonisolated
struct LocalNotificationAttachmentID: Hashable, Codable, Sendable {
    let value: String

    init(_ value: String) throws {
        try LocalNotificationIdentifierValidator.validate(value, kind: .attachment, maximumBytes: 128)
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard (try? LocalNotificationIdentifierValidator.validate(value, kind: .attachment, maximumBytes: 128)) != nil else {
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Invalid local notification attachment identifier")
        }
        self.value = value
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

nonisolated
enum LocalNotificationIdentifierValidator {
    static func validate(_ value: String, kind: LocalNotificationIdentifierKind, maximumBytes: Int) throws {
        guard value.utf8.count >= 1,
              value.utf8.count <= maximumBytes,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !containsASCIIControl(value) else {
            throw LocalNotificationServiceError.invalidIdentifier(kind)
        }
    }

    static func containsASCIIControl(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            scalar.value <= 0x1F || scalar.value == 0x7F
        }
    }
}

nonisolated
struct LocalNotificationNamespace: Hashable, Sendable {
    static let live = "AppTemplate.LocalNotification"

    let value: String

    init(_ value: String = LocalNotificationNamespace.live) throws {
        guard value == Self.live else {
            throw LocalNotificationServiceError.invalidIdentifier(.request)
        }
        self.value = value
    }

    func physicalRequestID(_ identifier: LocalNotificationID) -> String {
        "\(value).request.\(encode(identifier.value))"
    }

    func logicalRequestID(_ physicalIdentifier: String) -> LocalNotificationID? {
        decode(physicalIdentifier, prefix: "\(value).request.", as: LocalNotificationID.init)
    }

    func physicalCategoryID(_ identifier: LocalNotificationCategoryID) -> String {
        "\(value).category.\(encode(identifier.value))"
    }

    func logicalCategoryID(_ physicalIdentifier: String) -> LocalNotificationCategoryID? {
        decode(physicalIdentifier, prefix: "\(value).category.", as: LocalNotificationCategoryID.init)
    }

    func physicalActionID(category: LocalNotificationCategoryID, action: LocalNotificationActionID) -> String {
        "\(value).action.\(encode(category.value)).\(encode(action.value))"
    }

    func physicalActionID(_ category: LocalNotificationCategoryID, _ action: LocalNotificationActionID) -> String {
        physicalActionID(category: category, action: action)
    }

    func logicalActionID(_ physicalIdentifier: String) -> (category: LocalNotificationCategoryID, action: LocalNotificationActionID)? {
        let prefix = "\(value).action."
        guard physicalIdentifier.hasPrefix(prefix) else { return nil }
        let parts = physicalIdentifier.dropFirst(prefix.count).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let category = decode(String(parts[0]), as: LocalNotificationCategoryID.init),
              let action = decode(String(parts[1]), as: LocalNotificationActionID.init) else {
            return nil
        }
        return (category, action)
    }

    func physicalAttachmentID(request: LocalNotificationID, attachment: LocalNotificationAttachmentID) -> String {
        "\(value).attachment.\(encode(request.value)).\(encode(attachment.value))"
    }

    func physicalAttachmentID(_ request: LocalNotificationID, _ attachment: LocalNotificationAttachmentID) -> String {
        physicalAttachmentID(request: request, attachment: attachment)
    }

    func logicalAttachmentID(_ physicalIdentifier: String) -> (request: LocalNotificationID, attachment: LocalNotificationAttachmentID)? {
        let prefix = "\(value).attachment."
        guard physicalIdentifier.hasPrefix(prefix) else { return nil }
        let parts = physicalIdentifier.dropFirst(prefix.count).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let request = decode(String(parts[0]), as: LocalNotificationID.init),
              let attachment = decode(String(parts[1]), as: LocalNotificationAttachmentID.init) else {
            return nil
        }
        return (request, attachment)
    }

    var envelopeKey: String { "\(value).envelope" }

    private func encode(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func decode<ID>(_ physicalIdentifier: String, prefix: String, as initializer: (String) throws -> ID) -> ID? {
        guard physicalIdentifier.hasPrefix(prefix) else { return nil }
        return decode(String(physicalIdentifier.dropFirst(prefix.count)), as: initializer)
    }

    private func decode<ID>(_ encoded: String, as initializer: (String) throws -> ID) -> ID? {
        guard !encoded.isEmpty,
              encoded.unicodeScalars.allSatisfy({ scalar in
                  (65...90).contains(scalar.value) || (97...122).contains(scalar.value) ||
                  (48...57).contains(scalar.value) || scalar.value == 45 || scalar.value == 95
              }),
              encoded.count % 4 != 1 else { return nil }
        let base64 = encoded.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: padded),
              let value = String(data: data, encoding: .utf8),
              encode(value) == encoded else { return nil }
        return try? initializer(value)
    }
}
