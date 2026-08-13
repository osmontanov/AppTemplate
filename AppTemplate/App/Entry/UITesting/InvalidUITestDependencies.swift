import SwiftUI

struct InvalidUITestDependenciesView: View {
    var body: some View {
        Text("Invalid UI test configuration")
            .accessibilityIdentifier("ui-test.configuration.invalid")
    }
}
