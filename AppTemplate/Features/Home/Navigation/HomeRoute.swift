enum HomeRoute: String, Codable, Hashable, Sendable {
    case details
}

enum HomeSheetRoute: String, Codable, Hashable, Identifiable, Sendable {
    case navigationGuide

    var id: Self { self }
}

enum HomeAlertRoute: String, Codable, Hashable, Sendable {
    case resetNavigation
}
