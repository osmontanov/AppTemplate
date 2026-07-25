//
//  AppTemplateApp.swift
//  AppTemplate
//
//  Created by aurora on 24/07/2026.
//

import SwiftUI

@main
struct AppTemplateApp: App {
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            AppSceneView(dependencies: dependencies)
        }
    }
}
