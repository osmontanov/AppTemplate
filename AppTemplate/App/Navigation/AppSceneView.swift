import OSLog
import SwiftUI

struct AppSceneView: View {
    @State private var lifecycle = AppSceneNavigationLifecycle()
    @SceneStorage("AppTemplate.NavigationSnapshot") private var encodedSnapshot: Data?

    var body: some View {
        AppRootView(router: lifecycle.router)
            .task {
                if let snapshot = lifecycle.restore(from: encodedSnapshot) {
                    persist(snapshot)
                }
            }
            .onChange(of: lifecycle.router.snapshot) { _, snapshot in
                guard lifecycle.hasRestored else {
                    return
                }
                persist(snapshot)
            }
            .onOpenURL { url in
                if let snapshot = lifecycle.receive(url) {
                    persist(snapshot)
                }
            }
    }

    private func persist(_ snapshot: NavigationSnapshot) {
        do {
            encodedSnapshot = try NavigationSnapshotCodec.encode(snapshot)
        } catch {
            Logger.navigation.error(
                "Failed to encode navigation snapshot: \(String(describing: error), privacy: .public)"
            )
        }
    }
}
