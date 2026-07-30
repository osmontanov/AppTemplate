//
//  ContentView.swift
//  AppTemplate
//
//  Created by aurora on 24/07/2026.
//

import SwiftUI

struct ContentView: View {
    let dependencies: AppDependencies
    @State private var appFlowRouter: AppFlowRouter
    @State private var router: AppRouter

    init(dependencies: AppDependencies) {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        self.dependencies = dependencies
        _appFlowRouter = State(initialValue: appFlowRouter)
        _router = State(
            initialValue: AppRouter(appFlowRouter: appFlowRouter)
        )
    }

    var body: some View {
        AppRootView(
            appFlowRouter: appFlowRouter,
            router: router,
            dependencies: dependencies
        )
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    ContentView(dependencies: dependencies)
}
