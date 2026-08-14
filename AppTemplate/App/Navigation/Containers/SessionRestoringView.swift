import SwiftUI

struct SessionRestoringView: View {
    var body: some View {
        ProgressView(StoreServicesText.resource("Restoring session"))
            .accessibilityIdentifier("screen.session-restoring")
    }
}
