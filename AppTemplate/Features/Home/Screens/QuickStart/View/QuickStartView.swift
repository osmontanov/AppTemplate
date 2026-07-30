import SwiftUI

struct QuickStartView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = QuickStartViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.fill")
                .font(.largeTitle)
            Text("Quick Start")
                .font(.title)
            Text(
                """
                Explore five independent flows—Authentication, Home, Browse, Projects, \
                and Settings—plus screen-owned simple sheets and the independent \
                create-project modal flow.
                """
            )
                .foregroundStyle(.secondary)
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
