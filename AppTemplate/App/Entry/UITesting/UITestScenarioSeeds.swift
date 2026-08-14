import Foundation

nonisolated enum UITestSessionValidationMode: Equatable, Sendable {
    case disabled
    case scripted
}

nonisolated struct UITestSessionSeed: Equatable, Sendable {
    let keychainData: Data?

    let validationMode: UITestSessionValidationMode

    init(
        keychainData: Data?,
        validationMode: UITestSessionValidationMode = .disabled
    ) {
        self.keychainData = keychainData
        self.validationMode = validationMode
    }
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
