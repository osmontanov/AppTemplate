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
    private let storeDependencies: StoreDependencies?
    private let storeUISupport: StoreUISupport?
    private let sceneNavigationPersistencePolicy: AppSceneNavigationPersistencePolicy
    @State private var appFlowCoordinator: AppFlowCoordinator?
    @State private var sessionController: SessionController?

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
        storeDependencies = resolved?.makeStoreDependencies()
        storeUISupport = resolved?.storeUISupport
        sceneNavigationPersistencePolicy = configuration.sceneNavigationPersistencePolicy
        if let resolved {
            let store = AppStateStore(storage: resolved.appStateStorage)
            let router = AppFlowRouter(
                flow: AppFlowPolicy.resolve(
                    store.state,
                    isLocalSessionBootstrapResolved: false
                )
            )
            _appFlowCoordinator = State(
                initialValue: AppFlowCoordinator(
                    store: store,
                    appFlowRouter: router,
                    isLocalSessionBootstrapResolved: false
                )
            )
            _sessionController = State(initialValue: SessionController(
                repository: resolved.sessionRepository,
                clock: resolved.clock,
                startupValidationPolicy: resolved.sessionStartupValidationPolicy,
                refreshSchedulePolicy: resolved.sessionRefreshSchedulePolicy
            ))
        } else {
            _appFlowCoordinator = State(initialValue: nil)
            _sessionController = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let dependencies,
               let storeDependencies,
               let storeUISupport,
               let appFlowCoordinator,
               let sessionController {
                ConfiguredAppRootView(
                    dependencies: dependencies,
                    storeDependencies: storeDependencies,
                    storeUISupport: storeUISupport,
                    appFlowCoordinator: appFlowCoordinator,
                    sessionController: sessionController,
                    navigationPersistencePolicy: sceneNavigationPersistencePolicy
                )
                #if os(macOS)
                .frame(minWidth: 820, minHeight: 620)
                #endif
            } else {
                InvalidUITestDependenciesView()
            }
        }

        #if os(macOS)
        Settings {
            if let storeDependencies {
                StoreSettingsSceneView(dependencies: storeDependencies)
            } else {
                InvalidUITestDependenciesView()
            }
        }
        #endif
    }
}

private struct ConfiguredAppRootView: View {
    let dependencies: AppDependencies
    let storeDependencies: StoreDependencies
    let storeUISupport: StoreUISupport
    let appFlowCoordinator: AppFlowCoordinator
    let sessionController: SessionController
    let navigationPersistencePolicy: AppSceneNavigationPersistencePolicy

    @State private var isReady: Bool
    @State private var bootstrapFailed = false
    @State private var scriptPresentation: UITestScriptConsumptionPresentation

    init(
        dependencies: AppDependencies,
        storeDependencies: StoreDependencies,
        storeUISupport: StoreUISupport,
        appFlowCoordinator: AppFlowCoordinator,
        sessionController: SessionController,
        navigationPersistencePolicy: AppSceneNavigationPersistencePolicy
    ) {
        self.dependencies = dependencies
        self.storeDependencies = storeDependencies
        self.storeUISupport = storeUISupport
        self.appFlowCoordinator = appFlowCoordinator
        self.sessionController = sessionController
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
                    session: sessionController.presentation,
                    localNotifications: dependencies.localNotifications,
                    storeDependencies: storeDependencies,
                    storeUISupport: storeUISupport,
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
            do {
                try await dependencies.bootstrap()
                guard !Task.isCancelled else { return }
                await sessionController.bootstrap()
                guard !Task.isCancelled else { return }
                appFlowCoordinator.setLocalSessionBootstrapResolved(
                    sessionController.isLocalBootstrapResolved
                )
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
