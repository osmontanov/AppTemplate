import SwiftUI

struct LoadingStateView: View {
    let title: LocalizedStringResource

    var body: some View {
        ProgressView(title)
    }
}

#Preview("Loading") {
    LoadingStateView(title: "Loading…")
}
