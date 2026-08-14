import SwiftUI

struct AdaptiveFlowNavigationContainer<Route: NavigationRoute, Master: View, Placeholder: View, Destination: View>: View {
    @Binding private var path: [Route]
    let layout: AdaptiveFlowLayout
    private let master: () -> Master
    private let placeholder: () -> Placeholder
    private let destination: (Route) -> Destination

    init(
        path: Binding<[Route]>,
        layout: AdaptiveFlowLayout,
        @ViewBuilder master: @escaping () -> Master,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder destination: @escaping (Route) -> Destination
    ) {
        _path = path
        self.layout = layout
        self.master = master
        self.placeholder = placeholder
        self.destination = destination
    }

    var body: some View {
        switch layout {
        case .compactStack:
            NavigationStack(path: $path) {
                master().navigationDestination(for: Route.self, destination: destination)
            }
        case .regularColumns:
            HStack(spacing: 0) {
                NavigationStack { master() }
                    .frame(minWidth: 300, idealWidth: 360, maxWidth: 440)
                Divider()
                NavigationStack(path: $path) {
                    placeholder().navigationDestination(for: Route.self, destination: destination)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
