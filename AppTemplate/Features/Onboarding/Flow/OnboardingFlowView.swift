import SwiftUI

struct OnboardingFlowView: View {
    @Bindable var router: FlowRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            OnboardingView(router: router)
        }
    }
}
