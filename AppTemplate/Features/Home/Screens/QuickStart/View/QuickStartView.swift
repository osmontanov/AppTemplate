import SwiftUI

struct QuickStartView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = QuickStartViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.fill")
                .font(.largeTitle)
            Text(viewModel.title)
                .font(.title)
            Text(viewModel.message)
                .foregroundStyle(.secondary)
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
