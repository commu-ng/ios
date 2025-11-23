import Foundation

class AccountService {
    static let shared = AccountService()

    private init() {}

    // MARK: - Get Current User

    func getCurrentUser() async throws -> User {
        let url = URL(string: "\(APIClient.apiBaseURL)/console/me")!

        struct UserResponse: Codable {
            let data: User
        }

        let response: UserResponse = try await APIClient.shared.get(url: url)
        return response.data
    }

    // MARK: - Change Password

    func changePassword(currentPassword: String, newPassword: String) async throws {
        let url = URL(string: "\(APIClient.apiBaseURL)/console/change-password")!

        struct ChangePasswordRequest: Codable {
            let currentPassword: String
            let newPassword: String
        }

        let request = ChangePasswordRequest(
            currentPassword: currentPassword,
            newPassword: newPassword
        )

        let _: EmptyResponse = try await APIClient.shared.post(url: url, body: request)
    }

    // MARK: - Change Email

    func changeEmail(newEmail: String) async throws {
        let url = URL(string: "\(APIClient.apiBaseURL)/console/email")!

        struct ChangeEmailRequest: Codable {
            let email: String
        }

        let request = ChangeEmailRequest(email: newEmail)

        let _: EmptyResponse = try await APIClient.shared.post(url: url, body: request)
    }

    // MARK: - Data Export

    func requestDataExport() async throws {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/export")!

        struct ExportRequest: Codable {
            let profileId: String
        }

        // For now, we'll need to pass a profile ID
        // This should be updated to use the current profile from context
        let _: EmptyResponse = try await APIClient.shared.post(url: url, body: EmptyBody())
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        let url = URL(string: "\(APIClient.apiBaseURL)/console/users/me")!
        try await APIClient.shared.delete(url: url)

        // Clear stored session token
        await APIClient.shared.clearSession()
    }

    // MARK: - Logout

    func logout() async throws {
        // Clear the session token
        await APIClient.shared.clearSession()
    }
}

// MARK: - Helper

private struct EmptyBody: Codable {}
