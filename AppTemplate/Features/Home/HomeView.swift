import SwiftUI

struct HomeNavigationView: View {
    @Bindable var router: HomeRouter

    private var isResetAlertPresented: Binding<Bool> {
        Binding(
            get: { router.alert != nil },
            set: { isPresented in
                if !isPresented {
                    router.alert = nil
                }
            }
        )
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                NavigationLink("Navigation details", value: HomeRoute.details)
                Button("Open navigation guide") {
                    router.sheet = .navigationGuide
                }
                Button("Reset Home navigation", role: .destructive) {
                    router.alert = .resetNavigation
                }
            }
            .navigationTitle("Home")
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .details:
                    HomeDetailsView()
                }
            }
        }
        .sheet(item: $router.sheet) { route in
            switch route {
            case .navigationGuide:
                NavigationStack {
                    NavigationGuideView()
                }
            }
        }
        .alert("Reset Home navigation?", isPresented: isResetAlertPresented) {
            Button("Reset", role: .destructive) {
                router.popToRoot()
                router.alert = nil
            }
            Button("Cancel", role: .cancel) {
                router.alert = nil
            }
        } message: {
            Text("This clears only the Home navigation history.")
        }
    }
}

private struct HomeDetailsView: View {
    var body: some View {
        ContentUnavailableView(
            "Typed Destination",
            systemImage: "point.topleft.down.to.point.bottomright.curvepath",
            description: Text("HomeRoute.details produced this screen.")
        )
        .navigationTitle("Details")
    }
}

private struct NavigationGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Label("Typed paths", systemImage: "list.bullet.rectangle")
            Label("Independent tabs", systemImage: "square.3.layers.3d")
            Label("Scene restoration", systemImage: "arrow.clockwise")
        }
        .navigationTitle("Navigation Guide")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
