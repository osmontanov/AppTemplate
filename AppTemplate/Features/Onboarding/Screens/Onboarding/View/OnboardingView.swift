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
        AdaptiveContentContainer {
            VStack(spacing: 16) {
                Text(StoreServicesText.resource("Welcome to AppTemplate"))
                Text(StoreServicesText.resource("Completion is saved and the next required app flow opens automatically."))
                    .foregroundStyle(.secondary)
                Button(StoreServicesText.resource("Finish Onboarding")) {
                    viewModel.finish()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle(StoreServicesText.resource("Onboarding"))
        .accessibilityIdentifier("screen.onboarding")
    }
}

#Preview("Accessibility Size") {
    PreviewFixtures.onboardingFlow()
        .environment(\.dynamicTypeSize, .accessibility5)
}
