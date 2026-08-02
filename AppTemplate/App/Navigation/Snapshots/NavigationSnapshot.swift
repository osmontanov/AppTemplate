import Foundation
import SwiftUI

struct NavigationSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 4

    let schemaVersion: Int
    let lastAppliedTransitionID: UUID?
    var selectedSection: AppSection
    var homePath: FlowPathSnapshot
    var browsePath: FlowPathSnapshot
    var projectsPath: FlowPathSnapshot
    var settingsPath: FlowPathSnapshot

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        lastAppliedTransitionID: UUID? = nil,
        selectedSection: AppSection,
        homePath: NavigationPath,
        browsePath: NavigationPath,
        projectsPath: NavigationPath,
        settingsPath: NavigationPath
    ) {
        self.schemaVersion = schemaVersion
        self.lastAppliedTransitionID = lastAppliedTransitionID
        self.selectedSection = selectedSection
        self.homePath = FlowPathSnapshot(path: homePath)
        self.browsePath = FlowPathSnapshot(path: browsePath)
        self.projectsPath = FlowPathSnapshot(path: projectsPath)
        self.settingsPath = FlowPathSnapshot(path: settingsPath)
    }
}

enum NavigationSnapshotCodec {
    private struct Header: Decodable {
        let schemaVersion: Int
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

    static func encodingIfChanged(
        _ snapshot: NavigationSnapshot,
        comparedTo existingData: Data?
    ) throws -> Data? {
        if let existingData,
           let existingSnapshot = try? decode(existingData),
           existingSnapshot == snapshot {
            return nil
        }
        return try encode(snapshot)
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
