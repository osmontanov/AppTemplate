import Foundation

nonisolated
struct NavigationSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 5

    let schemaVersion: Int
    let lastAppliedTransitionID: UUID?
    var selectedSection: AppSection
    var storePath: [StoreRoute]
    var servicesPath: [ServicesRoute]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        lastAppliedTransitionID: UUID? = nil,
        selectedSection: AppSection,
        storePath: [StoreRoute],
        servicesPath: [ServicesRoute]
    ) {
        self.schemaVersion = schemaVersion
        self.lastAppliedTransitionID = lastAppliedTransitionID
        self.selectedSection = selectedSection
        self.storePath = storePath
        self.servicesPath = servicesPath
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case lastAppliedTransitionID
        case selectedSection
        case storePath
        case servicesPath
    }

    init(from decoder: Decoder) throws {
        let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
        try dynamic.rejectUnknownKeys(allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        lastAppliedTransitionID = try container.decodeIfPresent(UUID.self, forKey: .lastAppliedTransitionID)
        selectedSection = try container.decode(AppSection.self, forKey: .selectedSection)
        storePath = try container.decode([StoreRoute].self, forKey: .storePath)
        servicesPath = try container.decode([ServicesRoute].self, forKey: .servicesPath)
    }
}

nonisolated
enum NavigationSnapshotCodec {
    private struct Header: Decodable { let schemaVersion: Int }

    struct RecoveredSchemaFive {
        let snapshot: NavigationSnapshot
        let recoveredSections: Set<AppSection>
    }

    static func encode(_ snapshot: NavigationSnapshot) throws -> Data {
        try JSONEncoder().encode(snapshot)
    }

    static func schemaVersion(in data: Data) throws -> Int {
        try JSONDecoder().decode(Header.self, from: data).schemaVersion
    }

    static func decode(_ data: Data) throws -> NavigationSnapshot {
        try JSONDecoder().decode(NavigationSnapshot.self, from: data)
    }

    static func decodeRecoveringSchemaFive(_ data: Data) throws -> RecoveredSchemaFive {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }
        let allowed = Set(["schemaVersion", "lastAppliedTransitionID", "selectedSection", "storePath", "servicesPath"])
        guard Set(object.keys).isSubset(of: allowed),
              let schemaVersion = object["schemaVersion"] as? Int,
              schemaVersion == NavigationSnapshot.currentSchemaVersion,
              let selectedRawValue = object["selectedSection"] as? String,
              let selectedSection = AppSection(rawValue: selectedRawValue),
              let storeObject = object["storePath"],
              let servicesObject = object["servicesPath"] else {
            throw CocoaError(.coderReadCorrupt)
        }

        let checkpoint: UUID?
        if let rawCheckpoint = object["lastAppliedTransitionID"] {
            if rawCheckpoint is NSNull {
                checkpoint = nil
            } else {
                guard let value = rawCheckpoint as? String, let uuid = UUID(uuidString: value) else {
                    throw CocoaError(.coderReadCorrupt)
                }
                checkpoint = uuid
            }
        } else {
            checkpoint = nil
        }

        var recovered: Set<AppSection> = []
        let storePath: [StoreRoute]
        do {
            storePath = try decodeArray(StoreRoute.self, object: storeObject)
        } catch {
            storePath = []
            recovered.insert(.store)
        }
        let servicesPath: [ServicesRoute]
        do {
            servicesPath = try decodeArray(ServicesRoute.self, object: servicesObject)
        } catch {
            servicesPath = []
            recovered.insert(.services)
        }
        return RecoveredSchemaFive(
            snapshot: NavigationSnapshot(
                lastAppliedTransitionID: checkpoint,
                selectedSection: selectedSection,
                storePath: storePath,
                servicesPath: servicesPath
            ),
            recoveredSections: recovered
        )
    }

    static func encodingIfChanged(
        _ snapshot: NavigationSnapshot,
        comparedTo existingData: Data?
    ) throws -> Data? {
        if let existingData {
            if let version = try? schemaVersion(in: existingData),
               version > NavigationSnapshot.currentSchemaVersion {
                return nil
            }
            if let existingSnapshot = try? decode(existingData), existingSnapshot == snapshot {
                return nil
            }
        }
        return try encode(snapshot)
    }

    private static func decodeArray<Value: Decodable>(
        _ type: Value.Type,
        object: Any
    ) throws -> [Value] {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode([Value].self, from: data)
    }
}

nonisolated
enum NavigationRestorationFailure: Equatable, Sendable {
    case corruptData
    case unsupportedSchema(Int)
}

nonisolated
enum NavigationRestorationResult: Equatable, Sendable {
    case noState
    case restored
    case migrated(from: Int)
    case recovered(Set<AppSection>)
    case reset(NavigationRestorationFailure)
    case preservedFutureSchema(Int)
}

nonisolated
struct NavigationRestoration: Equatable, Sendable {
    let result: NavigationRestorationResult
    let lastAppliedTransitionID: UUID?
}
