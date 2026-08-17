import SwiftUI

struct SessionRestoringView: View {
    var body: some View {
        VStack {
            ProgressView(AppText.resource("Restoring session"))
                .accessibilityValue(AppText.resource("In progress"))
                .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
        }
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.restoring))
    }
}
