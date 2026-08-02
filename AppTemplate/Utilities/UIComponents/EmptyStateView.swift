import SwiftUI

struct EmptyStateView: View {
    let title: LocalizedStringResource
    let systemImage: String
    let message: LocalizedStringResource

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}

#Preview("Empty") {
    EmptyStateView(
        title: "No Items",
        systemImage: "tray",
        message: "There are no items yet."
    )
}
