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
    @StateObject private var communityVM: CommunityViewModel

    init() {
        if let supabase = SupabaseCommunityDataSource.makeFromInfoPlist() {
            _communityVM = StateObject(wrappedValue: CommunityViewModel(dataSource: supabase))
        } else {
            _communityVM = StateObject(wrappedValue: CommunityViewModel(dataSource: MockCommunityDataSource()))
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(activityStore)
                .environmentObject(communityVM)
                .tint(.taqvoCTA)
                .background(Color.taqvoBackgroundDark)
        }
    }
}
