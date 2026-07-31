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
    @State private var appFlowCoordinator: AppFlowCoordinator

    init() {
        let dependencies = AppDependencies.live()
        let store = AppStateStore(
            storage: dependencies.appStateStorage
        )
        let appFlowRouter = AppFlowRouter(
            flow: AppFlowPolicy.resolve(store.state)
        )
        self.dependencies = dependencies
        _appFlowCoordinator = State(
            initialValue: AppFlowCoordinator(
                store: store,
                appFlowRouter: appFlowRouter
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            AppSceneView(appFlowCoordinator: appFlowCoordinator)
        }
    }
}
