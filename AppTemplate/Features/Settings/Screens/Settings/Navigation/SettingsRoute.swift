nonisolated
enum SettingsRoute: String, NavigationRoute {
    case about
}

nonisolated
enum SettingsSheetRoute: String, Identifiable, Hashable, Sendable {
    case sessionInfo

    var id: Self { self }
}
