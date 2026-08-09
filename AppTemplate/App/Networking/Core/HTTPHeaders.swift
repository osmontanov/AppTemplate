nonisolated
struct HTTPHeaders: Sendable, Equatable, ExpressibleByDictionaryLiteral {
    nonisolated
    struct Field: Sendable, Equatable {
        let name: String
        let value: String
    }

    private var storage: [String: Field] = [:]

    init() {}

    init(dictionaryLiteral elements: (String, String)...) {
        for (name, value) in elements {
            set(value, for: name)
        }
    }

    subscript(_ name: String) -> String? {
        guard Self.isValidFieldName(name) else { return nil }
        return storage[Self.canonicalName(name)]?.value
    }

    mutating func set(_ value: String, for name: String) {
        precondition(Self.isValidFieldName(name), "Invalid HTTP field name")
        storage[Self.canonicalName(name)] = Field(name: name, value: value)
    }

    var fields: [Field] {
        storage.sorted { $0.key < $1.key }.map(\.value)
    }

    static func isValidFieldName(_ name: String) -> Bool {
        !name.isEmpty && name.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (65...90).contains(byte) ||
                (97...122).contains(byte) ||
                [
                    33, 35, 36, 37, 38, 39, 42, 43, 45, 46, 94, 95,
                    96, 124, 126
                ].contains(byte)
        }
    }

    static func canonicalName(_ name: String) -> String {
        String(decoding: name.utf8.map { byte in
            (65...90).contains(byte) ? byte + 32 : byte
        }, as: UTF8.self)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage.mapValues(\.value) == rhs.storage.mapValues(\.value)
    }
}
