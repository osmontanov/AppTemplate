//
//  ContentView.swift
//  AppTemplate
//
//  Created by aurora on 24/07/2026.
//

import SwiftUI

struct ContentView: View {
    let dependencies: AppDependencies
    @State private var router = AppRouter()

    var body: some View {
        AppRootView(router: router, dependencies: dependencies)
    }
}

@MainActor
private struct PreviewRoot: View {
    let dependencies: AppDependencies
    @State private var sessionStore: SessionStore

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _sessionStore = State(
            initialValue: SessionStore(service: dependencies.session.service)
        )
    }

    var body: some View {
        ContentView(dependencies: dependencies)
            .environment(sessionStore)
    }
}

#Preview {
    let dependencies = AppDependencies.preview(
        browseItems: [
            BrowseItem(
                id: "swiftui",
                title: "SwiftUI",
                summary: "Adaptive native interfaces."
            ),
            BrowseItem(
                id: "observation",
                title: "Observation",
                summary: "Focused state tracking."
            ),
            BrowseItem(
                id: "routing",
                title: "Typed Routing",
                summary: "Navigation represented as data."
            )
        ],
        session: UserSession(id: "preview-user", displayName: "Preview User")
    )
    PreviewRoot(dependencies: dependencies)
}
