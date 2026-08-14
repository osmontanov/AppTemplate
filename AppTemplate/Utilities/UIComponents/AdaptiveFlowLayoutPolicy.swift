import SwiftUI

nonisolated
enum AdaptiveFlowLayout: Equatable, Sendable {
    case compactStack
    case regularColumns
}

nonisolated
enum AdaptiveFlowLayoutPolicy {
    static func resolve(
        horizontalSizeClass: UserInterfaceSizeClass?,
        isMacOS: Bool
    ) -> AdaptiveFlowLayout {
        if isMacOS { return .regularColumns }
        return horizontalSizeClass == .regular ? .regularColumns : .compactStack
    }
}
