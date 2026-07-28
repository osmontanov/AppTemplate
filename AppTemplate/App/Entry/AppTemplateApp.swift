//
//  AppTemplateApp.swift
//  AppTemplate
//
//  Created by aurora on 24/07/2026.
//

import SwiftUI

@main
struct AppTemplateApp: App {
    private let dependencies: AppDependencies
    @State private var sessionStore: SessionStore

    init() {
        let dependencies = AppDependencies.live()
        self.dependencies = dependencies
        _sessionStore = State(
            initialValue: SessionStore(service: dependencies.session.service)
        )
    }

    var body: some Scene {
        WindowGroup {
            AppSceneView(dependencies: dependencies)
                .environment(sessionStore)
        }
    }
}
