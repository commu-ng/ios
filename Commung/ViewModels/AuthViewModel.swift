import Foundation
import SwiftUI
import Combine
import UserNotifications

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        checkAuthStatus()
    }

    func checkAuthStatus() {
        if AuthService.shared.hasStoredSession() {
            Task {
                await autoLogin()
            }
        }
    }

    func login(loginName: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let user = try await AuthService.shared.login(loginName: loginName, password: password)
            currentUser = user
            isAuthenticated = true

            // Request notification permissions immediately after successful login
            await requestPushNotificationPermission()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signup(loginName: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let user = try await AuthService.shared.signup(loginName: loginName, password: password)
            currentUser = user
            isAuthenticated = true

            // Request notification permissions immediately after successful signup
            await requestPushNotificationPermission()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func requestPushNotificationPermission() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                print("✅ Push notification permission granted")
                // Register for remote notifications on the main thread
                UIApplication.shared.registerForRemoteNotifications()
            } else {
                print("⚠️ Push notification permission denied")
            }
        } catch {
            print("❌ Failed to request push notification permission: \(error)")
        }
    }

    func autoLogin() async {
        isLoading = true
        errorMessage = nil

        do {
            let user = try await AuthService.shared.getCurrentUser()
            currentUser = user
            isAuthenticated = true
        } catch {
            // Only sign out on authentication failure (401 Unauthorized)
            // Keep user signed in for temporary errors like 5XX or decoding failures
            if let networkError = error as? NetworkError {
                switch networkError {
                case .unauthorized:
                    // Clear token and sign out on auth failure
                    _ = KeychainService.shared.delete(forKey: Constants.Keychain.sessionTokenKey)
                    isAuthenticated = false
                    errorMessage = error.localizedDescription
                case .serverError, .decodingError:
                    // Keep user authenticated for temporary errors
                    // They still have a valid token, just show error message
                    isAuthenticated = AuthService.shared.hasStoredSession()
                    errorMessage = error.localizedDescription
                default:
                    isAuthenticated = false
                    errorMessage = error.localizedDescription
                }
            } else {
                // Network connectivity issues - keep session if token exists
                isAuthenticated = AuthService.shared.hasStoredSession()
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func logout() async {
        isLoading = true

        // Delete device registration before logging out
        if let pushToken = UserDefaults.standard.string(forKey: "pushToken") {
            do {
                try await DeviceService.shared.deleteDevice(pushToken: pushToken)
                UserDefaults.standard.removeObject(forKey: "pushToken")
            } catch {
                print("Failed to delete device (continuing with logout): \(error)")
            }
        }

        do {
            try await AuthService.shared.logout()
        } catch {
            print("Logout error: \(error)")
        }

        currentUser = nil
        isAuthenticated = false
        isLoading = false
    }
}
