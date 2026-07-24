import Foundation
import Testing
@testable import AppTemplate

struct ProjectConfigurationTests {
    @Test
    func testTargetLoadsApplicationModule() {
        #expect(Bundle.main.bundleIdentifier == "com.oneday.AppTemplate")
    }
}
