import Foundation

nonisolated enum LocalNotificationAuthorizationStatus: String, Codable, CaseIterable, Hashable, Sendable { case notDetermined, denied, authorized, provisional, ephemeral, notSupported, unknown }
nonisolated enum LocalNotificationSettingState: String, Codable, CaseIterable, Hashable, Sendable { case notSupported, disabled, enabled, unknown }
nonisolated enum LocalNotificationAlertStyle: String, Codable, CaseIterable, Hashable, Sendable { case none, banner, alert, notSupported, unknown }
nonisolated enum LocalNotificationPreviewSetting: String, Codable, CaseIterable, Hashable, Sendable { case always, whenAuthenticated, never, notSupported, unknown }

nonisolated struct LocalNotificationSettings: Hashable, Codable, Sendable {
    let authorizationStatus: LocalNotificationAuthorizationStatus
    let alertSetting: LocalNotificationSettingState
    let soundSetting: LocalNotificationSettingState
    let badgeSetting: LocalNotificationSettingState
    let notificationCenterSetting: LocalNotificationSettingState
    let lockScreenSetting: LocalNotificationSettingState
    let alertStyle: LocalNotificationAlertStyle
    let previewSetting: LocalNotificationPreviewSetting
    init(authorizationStatus: LocalNotificationAuthorizationStatus, alertSetting: LocalNotificationSettingState, soundSetting: LocalNotificationSettingState, badgeSetting: LocalNotificationSettingState, notificationCenterSetting: LocalNotificationSettingState, lockScreenSetting: LocalNotificationSettingState, alertStyle: LocalNotificationAlertStyle, previewSetting: LocalNotificationPreviewSetting) {
        self.authorizationStatus = authorizationStatus; self.alertSetting = alertSetting; self.soundSetting = soundSetting; self.badgeSetting = badgeSetting; self.notificationCenterSetting = notificationCenterSetting; self.lockScreenSetting = lockScreenSetting; self.alertStyle = alertStyle; self.previewSetting = previewSetting
    }
}

nonisolated struct LocalNotificationAuthorizationOptions: OptionSet, Hashable, Sendable {
    let rawValue: UInt
    static let alert = Self(rawValue: 1 << 0); static let sound = Self(rawValue: 1 << 1); static let badge = Self(rawValue: 1 << 2); static let provisional = Self(rawValue: 1 << 3)
    static let allowed: Self = [.alert, .sound, .badge, .provisional]
    init(rawValue: UInt) { self.rawValue = rawValue }
}
nonisolated extension LocalNotificationAuthorizationOptions: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer(); let options = Self(rawValue: try container.decode(UInt.self))
        guard (try? LocalNotificationValidator.validate(authorization: options)) != nil else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid local notification authorization options") }
        self = options
    }
    func encode(to encoder: any Encoder) throws { try LocalNotificationValidator.validate(authorization: self); var container = encoder.singleValueContainer(); try container.encode(rawValue) }
}
