nonisolated
enum HomeRoute: String, NavigationRoute {
    case details
    case navigationGuide
}

nonisolated
enum HomeAlertRoute: String, Codable, Hashable, Sendable {
    case resetNavigation
}

nonisolated
enum HomeSheetRoute: String, Identifiable, Hashable, Sendable {
    case quickStart

    var id: Self { self }
}
