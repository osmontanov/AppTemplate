import SwiftUI

struct LoadingStateView: View {
    let title: String

    var body: some View {
        ProgressView(title)
    }
}

#Preview("Loading") {
    LoadingStateView(title: "Loading…")
}
