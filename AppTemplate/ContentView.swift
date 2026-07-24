//
//  ContentView.swift
//  AppTemplate
//
//  Created by aurora on 24/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var router = AppRouter()

    var body: some View {
        AppRootView(router: router)
    }
}

#Preview {
    ContentView()
}
