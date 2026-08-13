import Foundation

nonisolated struct UITestSessionSeed: Equatable, Sendable {
    let keychainData: Data?
}

nonisolated struct UITestLocalDatabaseSeed: Equatable, Sendable {
    let examples: [ExampleRecord]
}

nonisolated struct UITestPreferencesSeed: Equatable, Sendable {
    let encodedValues: [String: Data]
}

nonisolated struct UITestNotificationSeed: Equatable, Sendable {
    let authorizationStatus: LocalNotificationAuthorizationStatus
    let pendingRequests: [LocalNotificationRequest]
}

nonisolated struct UITestImageSeed: Equatable, Sendable {
    let steps: [ScriptedImageStep]
}
