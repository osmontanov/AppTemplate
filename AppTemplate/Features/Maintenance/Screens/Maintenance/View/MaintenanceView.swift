import SwiftUI

struct MaintenanceView: View {
    @State private var viewModel: MaintenanceViewModel

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
                Text(StoreServicesText.resource("Disable the saved maintenance flag to return to the required app flow."))
                    .foregroundStyle(.secondary)
                Button(StoreServicesText.resource("Return to App")) {
                    viewModel.returnToApp()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle(StoreServicesText.resource("Maintenance"))
    }
}

#Preview("Accessibility Size") {
    PreviewFixtures.maintenanceFlow()
        .environment(\.dynamicTypeSize, .accessibility5)
}
