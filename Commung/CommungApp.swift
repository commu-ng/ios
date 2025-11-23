//
//  CommungApp.swift
//  Commung
//
//  Created by Jihyeok Seo on 11/16/25.
//

import SwiftUI
import Combine
import UserNotifications

@main
struct CommungApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var communityContext = CommunityContext()
    @StateObject private var profileContext = ProfileContext()
    @StateObject private var appModeContext = AppModeContext()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(communityContext)
                .environmentObject(profileContext)
                .environmentObject(appModeContext)
                .onAppear {
                    // Clear badge count when app launches
                    clearBadge()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Clear badge when app becomes active (comes to foreground)
                clearBadge()
            }
        }
    }

    private func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
