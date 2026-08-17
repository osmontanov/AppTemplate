import SwiftUI

struct ErrorStateView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                title,
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text(message)
        } actions: {
            Button(AppText.resource("Retry"), action: retry)
        }
    }
}

#Preview("Error") {
    ErrorStateView(
        title: "Unavailable",
        message: "Please try again.",
        retry: {}
    )
}
