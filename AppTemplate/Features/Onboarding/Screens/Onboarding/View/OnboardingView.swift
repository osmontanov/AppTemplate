import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    @AccessibilityFocusState private var primaryActionIsFocused: Bool

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
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)
                Text(StoreServicesText.resource("Completion is saved and the next required app flow opens automatically."))
                    .foregroundStyle(.secondary)
                Button(StoreServicesText.resource("Finish Onboarding")) {
                    viewModel.finish()
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
                .keyboardShortcut(.defaultAction)
                .accessibilityFocused($primaryActionIsFocused)
                .accessibilityIdentifier("action.onboarding.finish")
            }
        }
        .navigationTitle(StoreServicesText.resource("Onboarding"))
        .task { primaryActionIsFocused = true }
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.onboarding))
    }
}

#Preview("Accessibility Size") {
    PreviewFixtures.onboardingFlow()
        .environment(\.dynamicTypeSize, .accessibility5)
}
