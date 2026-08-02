nonisolated
protocol IAppInfoService: Sendable {
    var displayName: String { get }
    var version: String { get }
}
