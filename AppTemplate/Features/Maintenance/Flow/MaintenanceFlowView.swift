import SwiftUI

struct MaintenanceFlowView: View {
    @Bindable var router: FlowRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            MaintenanceView(router: router)
        }
    }
}

#Preview("Maintenance") {
    PreviewFixtures.maintenanceFlow()
}
