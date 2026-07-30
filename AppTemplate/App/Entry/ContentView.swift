//
//  ContentView.swift
//  AppTemplate
//
//  Created by aurora on 24/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var appFlowRouter: AppFlowRouter
    @State private var router: AppRouter

    init() {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        _appFlowRouter = State(initialValue: appFlowRouter)
        _router = State(
            initialValue: AppRouter(appFlowRouter: appFlowRouter)
        )
    }

    var body: some View {
        AppRootView(
            appFlowRouter: appFlowRouter,
            router: router
        )
    }
}

#Preview {
    ContentView()
}
