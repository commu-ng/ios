import Foundation

class AuthService {
    static let shared = AuthService()

    private init() {}

    func login(loginName: String, password: String) async throws -> User {
        let loginRequest = LoginRequest(loginName: loginName, password: password)

        let response: LoginResponse = try await APIClient.shared.request(
            endpoint: "/console/login",
            method: "POST",
            body: loginRequest,
            requiresAuth: false
        )

        _ = KeychainService.shared.save(response.data.sessionToken, forKey: Constants.Keychain.sessionTokenKey)

        return User(
            id: response.data.id,
            loginName: response.data.loginName,
            email: response.data.email,
            emailVerifiedAt: response.data.emailVerifiedAt,
            createdAt: response.data.createdAt,
            isAdmin: response.data.isAdmin,
            avatarURL: response.data.avatarUrl
        )
    }

    func signup(loginName: String, password: String) async throws -> User {
        let signupRequest = LoginRequest(loginName: loginName, password: password)

        let response: LoginResponse = try await APIClient.shared.request(
            endpoint: "/console/signup",
            method: "POST",
            body: signupRequest,
            requiresAuth: false
        )

        _ = KeychainService.shared.save(response.data.sessionToken, forKey: Constants.Keychain.sessionTokenKey)

        return User(
            id: response.data.id,
            loginName: response.data.loginName,
            email: response.data.email,
            emailVerifiedAt: response.data.emailVerifiedAt,
            createdAt: response.data.createdAt,
            isAdmin: response.data.isAdmin,
            avatarURL: response.data.avatarUrl
        )
    }

    func getCurrentUser() async throws -> User {
        let response: ApiResponse<User> = try await APIClient.shared.request(
            endpoint: "/console/me",
            method: "GET",
            requiresAuth: true
        )
        return response.data
    }

    func logout() async throws {
        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                endpoint: "/auth/logout",
                method: "POST",
                requiresAuth: true
            )
        } catch {
            print("Logout API error (ignoring): \(error)")
        }

        _ = KeychainService.shared.delete(forKey: Constants.Keychain.sessionTokenKey)
    }

    func hasStoredSession() -> Bool {
        return KeychainService.shared.load(forKey: Constants.Keychain.sessionTokenKey) != nil
    }
}
