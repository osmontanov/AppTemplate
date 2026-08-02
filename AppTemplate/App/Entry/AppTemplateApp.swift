//
//  AppTemplateApp.swift
//  AppTemplate
//
//  Created by aurora on 24/07/2026.
//

import Foundation
import SwiftUI

@main
struct AppTemplateApp: App {
    private let dependencies: AppDependencies
    @State private var appFlowCoordinator: AppFlowCoordinator

    init() {
        let launchConfiguration = AppLaunchConfiguration(
            arguments: ProcessInfo.processInfo.arguments
        )
        let dependencies: AppDependencies

        switch launchConfiguration {
        case .live:
            dependencies = AppDependencies.live()
        case let .uiTesting(initialState):
            dependencies = AppDependencies.uiTesting(initialState: initialState)
        }

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
            AppSceneView(
                appFlowCoordinator: appFlowCoordinator,
                settings: dependencies.settings
            )
        }

        #if os(macOS)
        Settings {
            AppSettingsView(dependencies: dependencies.settings)
        }
        #endif
    }
}
