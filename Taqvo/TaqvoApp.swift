//
//  TaqvoApp.swift
//  Taqvo
//
//  Created by Juan Oclock on 10/17/25.
//

import SwiftUI

@main
struct TaqvoApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var activityStore = ActivityStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(activityStore)
                .tint(.taqvoCTA)
                .background(Color.taqvoBackgroundDark)
        }
    }
}
