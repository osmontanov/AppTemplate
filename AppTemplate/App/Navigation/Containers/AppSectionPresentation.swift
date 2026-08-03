import Foundation

extension AppSection {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .home:
            "Home"
        case .browse:
            "Browse"
        case .projects:
            "Projects"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .browse:
            "square.grid.2x2"
        case .projects:
            "folder"
        case .settings:
            "gearshape"
        }
    }

    var presentationIdentifier: String {
        "app.section.\(rawValue)"
    }

    var accessibilityIdentifier: String {
        "tab.\(rawValue)"
    }
}
