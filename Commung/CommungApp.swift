import SwiftUI
import UserNotifications

@main
struct CommungApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    UNUserNotificationCenter.current().setBadgeCount(0)
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                UNUserNotificationCenter.current().setBadgeCount(0)
            }
        }
    }
}
