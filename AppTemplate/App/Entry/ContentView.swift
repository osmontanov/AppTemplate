//
//  ContentView.swift
//  AppTemplate
//
//  Created by aurora on 24/07/2026.
//

import Foundation
import SwiftUI

struct ContentView: View {
    let settings: SettingsDependencies
    @State private var appFlowCoordinator: AppFlowCoordinator
    @State private var router: AppRouter

    init(
        appFlowCoordinator: AppFlowCoordinator,
        settings: SettingsDependencies
    ) {
        self.settings = settings
        _appFlowCoordinator = State(initialValue: appFlowCoordinator)
        _router = State(
            initialValue: AppRouter(
                appFlowRouter: appFlowCoordinator.appFlowRouter,
                appFlowCoordinator: appFlowCoordinator
            )
        )
    }

    var body: some View {
        AppRootView(
            appFlowRouter: appFlowCoordinator.appFlowRouter,
            router: router,
            settings: settings
        )
    }
}

#Preview {
    PreviewFixtures.appComposition(
        state: AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
    )
}
