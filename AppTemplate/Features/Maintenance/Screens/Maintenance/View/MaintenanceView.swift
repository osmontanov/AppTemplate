import SwiftUI

struct MaintenanceView: View {
    @State private var viewModel: MaintenanceViewModel

    init(router: FlowRouter) {
        _viewModel = State(
            initialValue: MaintenanceViewModel(router: router)
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Maintenance is in progress")
            Text("Return to the app when you are ready.")
                .foregroundStyle(.secondary)
            Button("Return to App") {
                viewModel.returnToApp()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Maintenance")
    }
}
