import OSLog
import SwiftUI

struct AppSceneView: View {
    @Environment(SessionStore.self) private var sessionStore
    @State private var lifecycle = AppSceneNavigationLifecycle()
    @SceneStorage("AppTemplate.NavigationSnapshot") private var encodedSnapshot: Data?
    let dependencies: AppDependencies

    var body: some View {
        AppRootView(router: lifecycle.router, dependencies: dependencies)
            .task {
                if let snapshot = lifecycle.restore(from: encodedSnapshot) {
                    persist(snapshot)
                }
                await sessionStore.start()
                lifecycle.synchronizeSession(sessionStore.phase)
            }
            .onChange(of: lifecycle.router.snapshot) { _, snapshot in
                guard lifecycle.hasRestored else {
                    return
                }
                persist(snapshot)
            }
            .onChange(of: sessionStore.phase) { _, phase in
                lifecycle.synchronizeSession(phase)
            }
            .onOpenURL { url in
                if let snapshot = lifecycle.receive(url) {
                    persist(snapshot)
                }
            }
    }

    private func persist(_ snapshot: NavigationSnapshot) {
        do {
            guard let encoding = try NavigationSnapshotCodec.encodingIfChanged(
                snapshot,
                comparedTo: encodedSnapshot
            ) else {
                return
            }
            encodedSnapshot = encoding
        } catch {
            Logger.navigation.error(
                "Failed to encode navigation snapshot: \(String(describing: error), privacy: .public)"
            )
        }
    }
}
