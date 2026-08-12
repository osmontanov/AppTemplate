import Foundation

nonisolated struct LocalNotificationDeepLinkPolicy: Sendable {
    let accepts: @Sendable (URL) -> Bool
    init(accepts: @escaping @Sendable (URL) -> Bool) { self.accepts = accepts }
    func isValid(_ url: URL) -> Bool { accepts(url) }
}
