import SwiftUI

struct MaintenanceView: View {
    @State private var viewModel: MaintenanceViewModel
    @AccessibilityFocusState private var primaryActionIsFocused: Bool

    init(router: FlowRouter) {
        _viewModel = State(
            initialValue: MaintenanceViewModel(
                maintenanceActions: router
            )
        )
    }

    var body: some View {
        AdaptiveContentContainer {
            VStack(spacing: 16) {
                Text(StoreServicesText.resource("Maintenance is in progress"))
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)
                Text(StoreServicesText.resource("Disable the saved maintenance flag to return to the required app flow."))
                    .foregroundStyle(.secondary)
                Button(StoreServicesText.resource("Return to App")) {
                    viewModel.returnToApp()
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
                .keyboardShortcut(.defaultAction)
                .accessibilityFocused($primaryActionIsFocused)
            }
        }
        .navigationTitle(StoreServicesText.resource("Maintenance"))
        .task { primaryActionIsFocused = true }
        .accessibilityIdentifier(AppAccessibilityIdentifier.screen(.maintenance))
    }
}

#Preview("Accessibility Size") {
    PreviewFixtures.maintenanceFlow()
        .environment(\.dynamicTypeSize, .accessibility5)
}
