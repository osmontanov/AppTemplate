import Foundation

nonisolated
enum ProductReminderPolicy {
    static let maximumInterval: TimeInterval = 604_800
    static let minimumRepeatingInterval: TimeInterval = 60
    static let quickTestInterval: TimeInterval = 5
    static let remindLaterDelay: Duration = .seconds(600)
}
