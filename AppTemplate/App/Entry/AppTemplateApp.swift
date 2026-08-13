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
    private let dependencies: AppDependencies?
    private let sceneNavigationPersistencePolicy: AppSceneNavigationPersistencePolicy
    @State private var appFlowCoordinator: AppFlowCoordinator?

    init() {
        let configuration = AppLaunchConfiguration(
            arguments: ProcessInfo.processInfo.arguments
        )
        let resolved: AppDependencies?
        switch configuration {
        case .live:
            resolved = AppDependencies.live()
        case let .uiTesting(scenario):
            resolved = AppDependencies.uiTesting(scenario: scenario)
        case .invalidUITesting:
            resolved = nil
        }

        dependencies = resolved
        sceneNavigationPersistencePolicy = configuration.sceneNavigationPersistencePolicy
        if let resolved {
            let store = AppStateStore(storage: resolved.appStateStorage)
            let router = AppFlowRouter(
                flow: AppFlowPolicy.resolve(
                    store.state,
                    legacyAuthentication: resolved.legacyAuthentication
                )
            )
            _appFlowCoordinator = State(
                initialValue: AppFlowCoordinator(
                    store: store,
                    appFlowRouter: router,
                    legacyAuthentication: resolved.legacyAuthentication
                )
            )
        } else {
            _appFlowCoordinator = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let dependencies, let appFlowCoordinator {
                ConfiguredAppRootView(
                    dependencies: dependencies,
                    appFlowCoordinator: appFlowCoordinator,
                    navigationPersistencePolicy: sceneNavigationPersistencePolicy
                )
            } else {
                InvalidUITestDependenciesView()
            }
        }

        #if os(macOS)
        Settings {
            if let dependencies {
                AppSettingsView(dependencies: dependencies.settings)
            } else {
                InvalidUITestDependenciesView()
            }
        }
        #endif
    }
}

private struct ConfiguredAppRootView: View {
    let dependencies: AppDependencies
    let appFlowCoordinator: AppFlowCoordinator
    let navigationPersistencePolicy: AppSceneNavigationPersistencePolicy

    @State private var isReady: Bool
    @State private var bootstrapFailed = false
    @State private var scriptPresentation: UITestScriptConsumptionPresentation

    init(
        dependencies: AppDependencies,
        appFlowCoordinator: AppFlowCoordinator,
        navigationPersistencePolicy: AppSceneNavigationPersistencePolicy
    ) {
        self.dependencies = dependencies
        self.appFlowCoordinator = appFlowCoordinator
        self.navigationPersistencePolicy = navigationPersistencePolicy
        _isReady = State(initialValue: dependencies.uiTestScriptTracker == nil)
        _scriptPresentation = State(initialValue: .pending)
    }

    var body: some View {
        Group {
            if bootstrapFailed {
                InvalidUITestDependenciesView()
            } else if isReady {
                AppSceneView(
                    appFlowCoordinator: appFlowCoordinator,
                    settings: dependencies.settings,
                    localNotifications: dependencies.localNotifications,
                    navigationPersistencePolicy: navigationPersistencePolicy
                )
            } else {
                ProgressView()
            }
        }
        .overlay(alignment: .topLeading) {
            if dependencies.uiTestScriptTracker != nil {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier(scriptAccessibilityIdentifier)
            }
        }
        .task {
            guard dependencies.uiTestScriptTracker != nil else { return }
            do {
                try await dependencies.bootstrap()
                guard !Task.isCancelled else { return }
                isReady = true
            } catch {
                bootstrapFailed = true
            }
        }
        .task {
            guard let tracker = dependencies.uiTestScriptTracker else { return }
            for await update in await tracker.updates() {
                guard !Task.isCancelled else { return }
                scriptPresentation = update
            }
        }
    }

    private var scriptAccessibilityIdentifier: String {
        switch scriptPresentation {
        case .pending: "ui-test.script-status.pending"
        case .exhausted: "ui-test.script-status.exhausted"
        case .failed: "ui-test.script-status.failed"
        }
    }
}
