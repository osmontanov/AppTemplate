import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel

    init(router: FlowRouter) {
        _viewModel = State(
            initialValue: OnboardingViewModel(
                onboardingActions: router
            )
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to AppTemplate")
            Text("Completion is saved and the next required app flow opens automatically.")
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
