nonisolated
enum HomeRoute: String, NavigationRoute {
    case details
    case navigationGuide
}

nonisolated
enum HomeAlertRoute: String, Codable, Hashable, Sendable {
    case resetNavigation
}
