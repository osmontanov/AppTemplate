import Foundation

nonisolated
enum StubBehavior: Sendable {
    case never
    case immediate
    case delayed(Duration)
}
