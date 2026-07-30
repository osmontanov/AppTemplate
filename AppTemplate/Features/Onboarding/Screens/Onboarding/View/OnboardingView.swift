import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel

    init(router: FlowRouter) {
        _viewModel = State(
            initialValue: OnboardingViewModel(router: router)
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to AppTemplate")
            Text("Finish onboarding to return to the app.")
                .foregroundStyle(.secondary)
            Button("Finish Onboarding") {
                viewModel.finish()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Onboarding")
    }
}
