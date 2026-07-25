//
//  ContentView.swift
//  AppTemplate
//
//  Created by aurora on 24/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var router = AppRouter()
    let dependencies: AppDependencies

    var body: some View {
        AppRootView(router: router, dependencies: dependencies)
    }
}

#Preview {
    ContentView(
        dependencies: .preview(
            browseItems: [
                BrowseItem(
                    id: "preview",
                    title: "Preview",
                    summary: "Deterministic preview content."
                )
            ],
            session: nil
        )
    )
}
