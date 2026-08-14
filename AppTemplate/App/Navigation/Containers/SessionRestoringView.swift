import SwiftUI

struct SessionRestoringView: View {
    var body: some View {
        VStack {
            ProgressView(StoreServicesText.resource("Restoring session"))
                .accessibilityValue(StoreServicesText.resource("In progress"))
                .accessibilityIdentifier(AppAccessibilityIdentifier.result(.loading))
        }
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.restoring))
    }
}
