import SwiftUI
import Combine

enum AppMode: String, CaseIterable {
    case app = "app"
    case console = "console"

    var displayName: String {
        switch self {
        case .app:
            return NSLocalizedString("App", comment: "App mode")
        case .console:
            return NSLocalizedString("Console", comment: "Console mode")
        }
    }

    var icon: String {
        switch self {
        case .app:
            return "person.3.fill"
        case .console:
            return "gearshape.fill"
        }
    }
}

@MainActor
class AppModeContext: ObservableObject {
    @Published var currentMode: AppMode {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: "currentAppMode")
            NotificationCenter.default.post(name: .appModeDidChange, object: nil)
        }
    }

    init() {
        if let savedMode = UserDefaults.standard.string(forKey: "currentAppMode"),
           let mode = AppMode(rawValue: savedMode) {
            self.currentMode = mode
        } else {
            self.currentMode = .app
        }
    }

    func toggleMode() {
        currentMode = currentMode == .app ? .console : .app
    }

    func switchTo(_ mode: AppMode) {
        currentMode = mode
    }
}

extension Notification.Name {
    static let appModeDidChange = Notification.Name("appModeDidChange")
}
