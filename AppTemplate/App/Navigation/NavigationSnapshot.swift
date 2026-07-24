import Foundation
import OSLog

struct NavigationSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var selectedSection: AppSection
    var homePath: [HomeRoute]
    var browsePath: [BrowseRoute]
    var settingsPath: [SettingsRoute]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        selectedSection: AppSection,
        homePath: [HomeRoute],
        browsePath: [BrowseRoute],
        settingsPath: [SettingsRoute]
    ) {
        self.schemaVersion = schemaVersion
        self.selectedSection = selectedSection
        self.homePath = homePath
        self.browsePath = browsePath
        self.settingsPath = settingsPath
    }
}

enum NavigationSnapshotCodec {
    static func encode(_ snapshot: NavigationSnapshot) throws -> Data {
        try JSONEncoder().encode(snapshot)
    }

    static func decode(_ data: Data) throws -> NavigationSnapshot {
        try JSONDecoder().decode(NavigationSnapshot.self, from: data)
    }
}

enum NavigationRestorationFailure: Equatable, Sendable {
    case corruptData
    case unsupportedSchema(Int)
}

enum NavigationRestorationResult: Equatable, Sendable {
    case noState
    case restored
    case reset(NavigationRestorationFailure)
}
