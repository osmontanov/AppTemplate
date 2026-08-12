import Foundation

nonisolated enum UserDefaultsComponent {
    static func isValid(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

nonisolated struct UserDefaultsKey<Value: Sendable>: Sendable {
    let logicalName: String
    let physicalKind: UserDefaultsPhysicalKind
    let encode: @Sendable (Value) throws -> UserDefaultsEncodedValue
    let decode: @Sendable (UserDefaultsEncodedValue) throws -> Value

    private init(
        name: String,
        kind: UserDefaultsPhysicalKind,
        encode: @escaping @Sendable (Value) throws -> UserDefaultsEncodedValue,
        decode: @escaping @Sendable (UserDefaultsEncodedValue) throws -> Value
    ) {
        precondition(UserDefaultsComponent.isValid(name))
        self.logicalName = name
        self.physicalKind = kind
        self.encode = encode
        self.decode = decode
    }
}

nonisolated extension UserDefaultsKey where Value == Bool {
    static func bool(_ name: String) -> Self {
        Self(name: name, kind: .bool, encode: UserDefaultsEncodedValue.bool) {
            guard case let .bool(value) = $0 else { throw UserDefaultsServiceError.invalidStoredValue }
            return value
        }
    }
}

nonisolated extension UserDefaultsKey where Value == Int {
    static func int(_ name: String) -> Self {
        Self(name: name, kind: .int, encode: UserDefaultsEncodedValue.int) {
            guard case let .int(value) = $0 else { throw UserDefaultsServiceError.invalidStoredValue }
            return value
        }
    }
}

nonisolated extension UserDefaultsKey where Value == Float {
    static func float(_ name: String) -> Self {
        Self(name: name, kind: .float, encode: UserDefaultsEncodedValue.float) {
            guard case let .float(value) = $0 else { throw UserDefaultsServiceError.invalidStoredValue }
            return value
        }
    }
}

nonisolated extension UserDefaultsKey where Value == Double {
    static func double(_ name: String) -> Self {
        Self(name: name, kind: .double, encode: UserDefaultsEncodedValue.double) {
            guard case let .double(value) = $0 else { throw UserDefaultsServiceError.invalidStoredValue }
            return value
        }
    }
}

nonisolated extension UserDefaultsKey where Value == String {
    static func string(_ name: String) -> Self {
        Self(name: name, kind: .string, encode: UserDefaultsEncodedValue.string) {
            guard case let .string(value) = $0 else { throw UserDefaultsServiceError.invalidStoredValue }
            return value
        }
    }
}

nonisolated extension UserDefaultsKey where Value == Data {
    static func data(_ name: String) -> Self {
        Self(name: name, kind: .data, encode: UserDefaultsEncodedValue.data) {
            guard case let .data(value) = $0 else { throw UserDefaultsServiceError.invalidStoredValue }
            return value
        }
    }
}

nonisolated extension UserDefaultsKey where Value == Date {
    static func date(_ name: String) -> Self {
        Self(name: name, kind: .date, encode: UserDefaultsEncodedValue.date) {
            guard case let .date(value) = $0 else { throw UserDefaultsServiceError.invalidStoredValue }
            return value
        }
    }
}

nonisolated extension UserDefaultsKey where Value: Codable {
    static func codable(_ name: String) -> Self {
        Self(name: name, kind: .data, encode: { value in
            do {
                return .data(try JSONEncoder().encode(value))
            } catch {
                throw UserDefaultsServiceError.encodingFailed
            }
        }) { encoded in
            guard case let .data(data) = encoded else {
                throw UserDefaultsServiceError.invalidStoredValue
            }
            do {
                return try JSONDecoder().decode(Value.self, from: data)
            } catch {
                throw UserDefaultsServiceError.decodingFailed
            }
        }
    }
}
