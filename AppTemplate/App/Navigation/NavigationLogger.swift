import Foundation
import OSLog

extension Logger {
    static let navigation = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate",
        category: "Navigation"
    )
}
