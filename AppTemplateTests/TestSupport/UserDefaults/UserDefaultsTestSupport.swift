import CoreFoundation
import Foundation
import Synchronization
import Testing
@testable import AppTemplate

nonisolated
enum UserDefaultsTestPhysicalKind: Equatable, Sendable {
    case bool
    case int
    case float32
    case float64
    case string
    case data
    case date
    case array
    case dictionary
    case other
}

nonisolated
final class RecordingUserDefaults: UserDefaults, @unchecked Sendable {
    private static let unrecordedSeedThreadKey =
        "AppTemplateTests.RecordingUserDefaults.UnrecordedSeed"

    private struct State {
        var objectCallCount = 0
        var setCallCount = 0
        var removeCallCount = 0
        var inFlightRawCalls = 0
        var maxConcurrentRawCalls = 0
        var usesOverlapDelay = false
    }

    private enum RawOperation {
        case object
        case set
        case remove
    }

    private let stateLock = NSLock()
    private var state = State()
    private let recordedSuiteName: String

    init?(suiteName: String) {
        recordedSuiteName = suiteName
        super.init(suiteName: suiteName)
    }

    var objectCallCount: Int {
        stateLock.withLock { state.objectCallCount }
    }

    var setCallCount: Int {
        stateLock.withLock { state.setCallCount }
    }

    var removeCallCount: Int {
        stateLock.withLock { state.removeCallCount }
    }

    var maxConcurrentRawCalls: Int {
        stateLock.withLock { state.maxConcurrentRawCalls }
    }

    func enableRawCallOverlapDelay() {
        stateLock.withLock { state.usesOverlapDelay = true }
    }

    func resetRecording() {
        stateLock.withLock {
            state.objectCallCount = 0
            state.setCallCount = 0
            state.removeCallCount = 0
            state.inFlightRawCalls = 0
            state.maxConcurrentRawCalls = 0
        }
    }

    override func object(forKey defaultName: String) -> Any? {
        let usesDelay = begin(.object)
        defer { finish() }
        if usesDelay { Thread.sleep(forTimeInterval: 0.005) }
        return super.object(forKey: defaultName)
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        if Thread.current.threadDictionary[
            Self.unrecordedSeedThreadKey
        ] as? Bool == true {
            super.set(value, forKey: defaultName)
            return
        }
        let usesDelay = begin(.set)
        defer { finish() }
        if usesDelay { Thread.sleep(forTimeInterval: 0.005) }
        super.set(value, forKey: defaultName)
    }

    override func removeObject(forKey defaultName: String) {
        let usesDelay = begin(.remove)
        defer { finish() }
        if usesDelay { Thread.sleep(forTimeInterval: 0.005) }
        super.set(nil, forKey: defaultName)
    }

    func seed(_ value: Any, forKey key: String) {
        super.set(value, forKey: key)
    }

    func seed(_ value: URL, forKey key: String) {
        Thread.current.threadDictionary[Self.unrecordedSeedThreadKey] = true
        defer {
            Thread.current.threadDictionary.removeObject(
                forKey: Self.unrecordedSeedThreadKey
            )
        }
        super.set(value, forKey: key)
    }

    func rawObject(forKey key: String) -> Any? {
        super.object(forKey: key)
    }

    func storedKeys() -> Set<String> {
        guard let domain = super.persistentDomain(forName: recordedSuiteName) else {
            return []
        }
        return Set(domain.keys)
    }

    func physicalKind(forKey key: String) -> UserDefaultsTestPhysicalKind? {
        guard let raw = rawObject(forKey: key) else { return nil }
        return userDefaultsTestPhysicalKind(of: raw)
    }

    private func begin(_ operation: RawOperation) -> Bool {
        stateLock.withLock {
            switch operation {
            case .object:
                state.objectCallCount += 1
            case .set:
                state.setCallCount += 1
            case .remove:
                state.removeCallCount += 1
            }
            state.inFlightRawCalls += 1
            state.maxConcurrentRawCalls = max(
                state.maxConcurrentRawCalls,
                state.inFlightRawCalls
            )
            return state.usesOverlapDelay
        }
    }

    private func finish() {
        stateLock.withLock { state.inFlightRawCalls -= 1 }
    }
}

nonisolated
func makeRecordingUserDefaults(
    label: String
) throws -> (suiteName: String, defaults: RecordingUserDefaults) {
    let suiteName = "AppTemplateTests.UserDefaults.\(label).\(UUID().uuidString)"
    let defaults = try #require(RecordingUserDefaults(suiteName: suiteName))
    return (suiteName, defaults)
}

nonisolated
func userDefaultsTestPhysicalKind(of raw: Any) -> UserDefaultsTestPhysicalKind {
    let typeID = CFGetTypeID(raw as CFTypeRef)
    if typeID == CFBooleanGetTypeID() { return .bool }
    if typeID == CFNumberGetTypeID() {
        let number = raw as! CFNumber
        switch CFNumberGetType(number) {
        case .float32Type:
            return .float32
        case .float64Type:
            return .float64
        default:
            return .int
        }
    }
    if raw is String { return .string }
    if raw is Data { return .data }
    if raw is Date { return .date }
    if raw is [Any] { return .array }
    if raw is [String: Any] { return .dictionary }
    return .other
}

nonisolated
func userDefaultsTestObjectsAreEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
    guard let lhs, let rhs else { return lhs == nil && rhs == nil }
    return (lhs as AnyObject).isEqual(rhs)
}

nonisolated
struct CodableFixture: Codable, Equatable, Sendable {
    let value: Int
}

nonisolated
enum UserDefaultsFixtureError: Error, CustomStringConvertible, Sendable {
    case encodingSentinel

    var description: String { "UNDERLYING-ENCODING-SENTINEL" }
}

nonisolated
struct ThrowingCodable: Codable, Sendable {
    let value: Int

    init(value: Int) {
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(Int.self)
    }

    func encode(to encoder: any Encoder) throws {
        throw UserDefaultsFixtureError.encodingSentinel
    }
}

nonisolated
struct ReentrantEncodingFixture: Codable, Sendable {
    let value: Int
    private let callback: @Sendable () throws -> Void

    init(value: Int, callback: @escaping @Sendable () throws -> Void) {
        self.value = value
        self.callback = callback
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(Int.self)
        callback = {}
    }

    func encode(to encoder: any Encoder) throws {
        try callback()
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

nonisolated
enum ReentrantDecodingFixtureCallback {
    private static let storage = Mutex<(@Sendable () throws -> Void)?>(nil)

    static func install(_ callback: @escaping @Sendable () throws -> Void) {
        storage.withLock { $0 = callback }
    }

    static func reset() {
        storage.withLock { $0 = nil }
    }

    static func invokeAndReset() throws {
        let callback = storage.withLock { $0 }
        defer { reset() }
        try callback?()
    }
}

nonisolated
struct ReentrantDecodingFixture: Codable, Equatable, Sendable {
    let value: Int

    init(value: Int) {
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        try ReentrantDecodingFixtureCallback.invokeAndReset()
        let container = try decoder.singleValueContainer()
        value = try container.decode(Int.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
