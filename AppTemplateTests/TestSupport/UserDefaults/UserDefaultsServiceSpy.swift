import Foundation
@testable import AppTemplate

nonisolated
final class UserDefaultsServiceSpy:
    IUserDefaultsService,
    @unchecked Sendable
{
    struct KeyRecord: Equatable, Sendable {
        let logicalName: String
        let physicalKind: UserDefaultsPhysicalKind
    }

    private struct State {
        var value: Data?
        var valueError: (any Error)?
        var valueKeys: [KeyRecord] = []
        var setKeys: [KeyRecord] = []
        var setValues: [Data] = []
        var removeKeys: [KeyRecord] = []
    }

    private let lock = NSLock()
    private var state: State

    init(
        value: Data? = nil,
        valueError: (any Error)? = nil
    ) {
        state = State(value: value, valueError: valueError)
    }

    func value<Value: Sendable>(
        for key: UserDefaultsKey<Value>
    ) throws -> Value? {
        try lock.withLock {
            state.valueKeys.append(Self.record(key))
            if let valueError = state.valueError {
                throw valueError
            }
            guard let value = state.value else { return nil }
            guard let typedValue = value as? Value else {
                preconditionFailure("UserDefaultsServiceSpy supports Data reads only")
            }
            return typedValue
        }
    }

    func set<Value: Sendable>(
        _ value: Value,
        for key: UserDefaultsKey<Value>
    ) throws {
        lock.withLock {
            guard let data = value as? Data else {
                preconditionFailure("UserDefaultsServiceSpy supports Data writes only")
            }
            state.setKeys.append(Self.record(key))
            state.setValues.append(data)
            state.value = data
        }
    }

    func remove<Value: Sendable>(_ key: UserDefaultsKey<Value>) {
        lock.withLock {
            state.removeKeys.append(Self.record(key))
            state.value = nil
        }
    }

    var requestedValueKeys: [KeyRecord] {
        lock.withLock { state.valueKeys }
    }

    var requestedSetKeys: [KeyRecord] {
        lock.withLock { state.setKeys }
    }

    var savedValues: [Data] {
        lock.withLock { state.setValues }
    }

    var requestedRemoveKeys: [KeyRecord] {
        lock.withLock { state.removeKeys }
    }

    private static func record<Value: Sendable>(
        _ key: UserDefaultsKey<Value>
    ) -> KeyRecord {
        KeyRecord(
            logicalName: key.logicalName,
            physicalKind: key.physicalKind
        )
    }
}
