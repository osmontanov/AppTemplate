import Foundation
import OSLog

extension Logger {
    static let appState = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate",
        category: "AppState"
    )
}
