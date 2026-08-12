import CoreFoundation
import Foundation

nonisolated
final class UserDefaultsService: IUserDefaultsService, @unchecked Sendable {
    private let namespace: String
    private let userDefaults: UserDefaults
    private let lock = NSLock()

    init(namespace: String, userDefaults: UserDefaults = .standard) {
        precondition(UserDefaultsComponent.isValid(namespace))
        self.namespace = namespace
        self.userDefaults = userDefaults
    }

    func value<Value: Sendable>(
        for key: UserDefaultsKey<Value>
    ) throws -> Value? {
        let encoded = try lock.withLock { () throws -> UserDefaultsEncodedValue? in
            guard let raw = userDefaults.object(forKey: physicalKey(for: key)) else {
                return nil
            }
            return try copyEncodedValue(raw, expected: key.physicalKind)
        }
        return try encoded.map(key.decode)
    }

    func set<Value: Sendable>(
        _ value: Value,
        for key: UserDefaultsKey<Value>
    ) throws {
        let encoded = try key.encode(value)
        lock.withLock {
            let physicalKey = physicalKey(for: key)
            if let existing = userDefaults.object(forKey: physicalKey),
               !hasCompatibleRepresentation(existing, with: encoded) {
                userDefaults.removeObject(forKey: physicalKey)
            }
            set(encoded, forKey: physicalKey)
        }
    }

    func remove<Value: Sendable>(_ key: UserDefaultsKey<Value>) {
        lock.withLock {
            userDefaults.removeObject(forKey: physicalKey(for: key))
        }
    }

    private func physicalKey<Value: Sendable>(
        for key: UserDefaultsKey<Value>
    ) -> String {
        "\(namespace).\(key.logicalName)"
    }

    private func copyEncodedValue(
        _ raw: Any,
        expected: UserDefaultsPhysicalKind
    ) throws -> UserDefaultsEncodedValue {
        switch expected {
        case .bool:
            guard CFGetTypeID(raw as CFTypeRef) == CFBooleanGetTypeID() else {
                throw UserDefaultsServiceError.invalidStoredValue
            }
            return .bool((raw as! NSNumber).boolValue)
        case .int:
            guard CFGetTypeID(raw as CFTypeRef) == CFNumberGetTypeID() else {
                throw UserDefaultsServiceError.invalidStoredValue
            }
            let number = raw as! CFNumber
            guard !CFNumberIsFloatType(number),
                  let value = Int(exactly: raw as! NSNumber) else {
                throw UserDefaultsServiceError.invalidStoredValue
            }
            return .int(value)
        case .float:
            guard CFGetTypeID(raw as CFTypeRef) == CFNumberGetTypeID() else {
                throw UserDefaultsServiceError.invalidStoredValue
            }
            let number = raw as! CFNumber
            guard CFNumberGetType(number) == .float32Type else {
                throw UserDefaultsServiceError.invalidStoredValue
            }
            return .float((raw as! NSNumber).floatValue)
        case .double:
            guard CFGetTypeID(raw as CFTypeRef) == CFNumberGetTypeID() else {
                throw UserDefaultsServiceError.invalidStoredValue
            }
            let number = raw as! CFNumber
            guard CFNumberGetType(number) == .float64Type else {
                throw UserDefaultsServiceError.invalidStoredValue
            }
            return .double((raw as! NSNumber).doubleValue)
        case .string:
            guard let value = raw as? String else {
                throw UserDefaultsServiceError.invalidStoredValue
            }
            return .string(value)
        case .data:
            guard let value = raw as? Data else {
                throw UserDefaultsServiceError.invalidStoredValue
            }
            return .data(value)
        case .date:
            guard let value = raw as? Date else {
                throw UserDefaultsServiceError.invalidStoredValue
            }
            return .date(value)
        }
    }

    private func hasCompatibleRepresentation(
        _ raw: Any,
        with encoded: UserDefaultsEncodedValue
    ) -> Bool {
        do {
            _ = try copyEncodedValue(raw, expected: physicalKind(of: encoded))
            return true
        } catch {
            return false
        }
    }

    private func physicalKind(
        of encoded: UserDefaultsEncodedValue
    ) -> UserDefaultsPhysicalKind {
        switch encoded {
        case .bool:
            .bool
        case .int:
            .int
        case .float:
            .float
        case .double:
            .double
        case .string:
            .string
        case .data:
            .data
        case .date:
            .date
        }
    }

    private func set(
        _ encoded: UserDefaultsEncodedValue,
        forKey physicalKey: String
    ) {
        switch encoded {
        case let .bool(value):
            userDefaults.set(value, forKey: physicalKey)
        case let .int(value):
            userDefaults.set(value, forKey: physicalKey)
        case let .float(value):
            userDefaults.set(value, forKey: physicalKey)
        case let .double(value):
            userDefaults.set(value, forKey: physicalKey)
        case let .string(value):
            userDefaults.set(value, forKey: physicalKey)
        case let .data(value):
            userDefaults.set(value, forKey: physicalKey)
        case let .date(value):
            userDefaults.set(value, forKey: physicalKey)
        }
    }
}
