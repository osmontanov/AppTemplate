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

@MainActor
private func makePreviewAppFlowCoordinator() -> AppFlowCoordinator {
    let defaults = UserDefaults(suiteName: "AppTemplate.Preview")
        ?? UserDefaults()
    let storage = UserDefaultsAppStateStorage(userDefaults: defaults)
    let store = AppStateStore(storage: storage)
    let router = AppFlowRouter(flow: AppFlowPolicy.resolve(store.state))
    return AppFlowCoordinator(store: store, appFlowRouter: router)
}

#Preview {
    ContentView(
        appFlowCoordinator: makePreviewAppFlowCoordinator(),
        settings: SettingsDependencies(
            appInfo: AppInfoService(
                displayName: "AppTemplate Preview",
                version: "1.0"
            )
        )
    )
}
