import SwiftUI
import Testing
@testable import AppTemplate

struct AdaptiveFlowLayoutPolicyTests {
    @Test
    func macOSAlwaysUsesRegularColumns() {
        #expect(AdaptiveFlowLayoutPolicy.resolve(horizontalSizeClass: nil, isMacOS: true) == .regularColumns)
        #expect(AdaptiveFlowLayoutPolicy.resolve(horizontalSizeClass: .compact, isMacOS: true) == .regularColumns)
    }

    @Test
    func iOSUsesRegularColumnsOnlyForRegularWidth() {
        #expect(AdaptiveFlowLayoutPolicy.resolve(horizontalSizeClass: .regular, isMacOS: false) == .regularColumns)
        #expect(AdaptiveFlowLayoutPolicy.resolve(horizontalSizeClass: .compact, isMacOS: false) == .compactStack)
        #expect(AdaptiveFlowLayoutPolicy.resolve(horizontalSizeClass: nil, isMacOS: false) == .compactStack)
    }
}
