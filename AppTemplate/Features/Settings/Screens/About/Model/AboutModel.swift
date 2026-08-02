nonisolated
struct AboutModel:
    Equatable,
    Sendable {
}

nonisolated
enum AppPlatform:
    String,
    CaseIterable,
    Codable,
    Equatable,
    Hashable,
    Sendable {
    case iOS
    case iPadOS
    case macOS
}
