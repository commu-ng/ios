import Foundation

class ProfileService {
    static let shared = ProfileService()

    private init() {}

    // MARK: - Get User & Instance

    func getCurrentUser() async throws -> User {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/me")!

        struct UserResponse: Codable {
            let data: User
        }

        let response: UserResponse = try await APIClient.shared.get(url: url)
        return response.data
    }

    func getUserInstance() async throws -> Community {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/me/instance")!

        struct InstanceResponse: Codable {
            let data: Community
        }

        let response: InstanceResponse = try await APIClient.shared.get(url: url)
        return response.data
    }

    func getPublicInstance() async throws -> Community {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/instance")!

        struct InstanceResponse: Codable {
            let data: Community
        }

        let response: InstanceResponse = try await APIClient.shared.get(url: url, requiresAuth: false)
        return response.data
    }

    // MARK: - Get Profiles

    func getUserProfiles() async throws -> [AppProfile] {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/me/profiles")!

        struct ProfilesResponse: Codable {
            let data: [AppProfile]
        }

        let response: ProfilesResponse = try await APIClient.shared.get(url: url)
        return response.data
    }

    func getAllProfiles(profileId: String? = nil) async throws -> [AppProfile] {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/profiles")!

        if let profileId = profileId {
            components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]
        }

        struct ProfilesResponse: Codable {
            let data: [AppProfile]
        }

        let response: ProfilesResponse = try await APIClient.shared.get(url: components.url!)
        return response.data
    }

    func getProfile(username: String, profileId: String?) async throws -> AppProfile {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/profiles/\(username)")!

        if let profileId = profileId {
            components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]
        }

        struct ProfileResponse: Codable {
            let data: AppProfile
        }

        let response: ProfileResponse = try await APIClient.shared.get(url: components.url!, requiresAuth: profileId != nil)
        return response.data
    }

    func getProfilePosts(username: String, profileId: String?, limit: Int = 20, cursor: String? = nil) async throws -> CommunityPostsResponse {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/profiles/\(username)/posts")!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let profileId = profileId {
            queryItems.append(URLQueryItem(name: "profile_id", value: profileId))
        }

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems

        // CommunityPostsResponse already has data field
        return try await APIClient.shared.get(url: components.url!, requiresAuth: profileId != nil)
    }

    // MARK: - Create Profile

    func createProfile(request: ProfileCreateRequest) async throws -> AppProfile {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/profiles")!

        struct ProfileResponse: Codable {
            let data: AppProfile
        }

        let response: ProfileResponse = try await APIClient.shared.post(url: url, body: request)
        return response.data
    }

    // MARK: - Update Profile

    func updateProfile(profileId: String, request: ProfileUpdateRequest) async throws -> AppProfile {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/profiles")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct ProfileResponse: Codable {
            let data: AppProfile
        }

        let response: ProfileResponse = try await APIClient.shared.put(url: components.url!, body: request)
        return response.data
    }

    func updateMyProfile(request: ProfileUpdateRequest) async throws -> AppProfile {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/me/profiles")!

        struct ProfileResponse: Codable {
            let data: AppProfile
        }

        let response: ProfileResponse = try await APIClient.shared.put(url: url, body: request)
        return response.data
    }

    // MARK: - Delete Profile

    func deleteProfile(profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/profiles")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        try await APIClient.shared.delete(url: components.url!)
    }

    // MARK: - Set Primary Profile

    func setPrimaryProfile(profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/profiles/set-primary")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        let _: EmptyResponse = try await APIClient.shared.post(url: components.url!, body: EmptyBody())
    }

    // MARK: - Profile Picture

    func uploadProfilePicture(imageData: Data, filename: String) async throws -> ProfilePicture {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/profile-picture")!
        return try await APIClient.shared.uploadFile(url: url, fileData: imageData, filename: filename, fieldName: "file")
    }

    // MARK: - Username Availability

    func checkUsernameAvailability(username: String) async throws -> Bool {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/username/\(username)")!

        struct UsernameResponse: Codable {
            let data: UsernameAvailability
        }

        let response: UsernameResponse = try await APIClient.shared.get(url: url)
        return response.data.available
    }

    // MARK: - Post Count

    func getProfilePostCount(profileId: String) async throws -> Int {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/profiles/post-count")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct PostCountWrapper: Codable {
            let data: PostCountResponse
        }

        let response: PostCountWrapper = try await APIClient.shared.get(url: components.url!)
        return response.data.postCount
    }

    // MARK: - Online Status

    func getOnlineStatus(profileIds: [String], requestingProfileId: String) async throws -> [String: Bool] {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/profiles/online-status")!

        components.queryItems = [
            URLQueryItem(name: "profile_id", value: requestingProfileId),
            URLQueryItem(name: "profile_ids", value: profileIds.joined(separator: ","))
        ]

        struct OnlineStatusWrapper: Codable {
            let data: [String: Bool]
        }

        let response: OnlineStatusWrapper = try await APIClient.shared.get(url: components.url!)
        return response.data
    }

    func updateOnlineStatusVisibility(visibility: String, profileId: String) async throws {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/profiles/online-status-settings")!
        let request = OnlineStatusVisibilityRequest(visibility: visibility, profileId: profileId)

        let _: EmptyResponse = try await APIClient.shared.put(url: url, body: request)
    }

    // MARK: - Profile Sharing (Multi-profile management)

    func getSharedUsers(profileId: String) async throws -> [SharedUser] {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/profiles/\(profileId)/users")!

        struct SharedUsersResponse: Codable {
            let data: [SharedUser]
        }

        let response: SharedUsersResponse = try await APIClient.shared.get(url: url)
        return response.data
    }

    func shareProfile(profileId: String, username: String) async throws {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/profiles/\(profileId)/users")!
        let request = ProfileShareRequest(username: username, role: "admin")

        let _: EmptyResponse = try await APIClient.shared.post(url: url, body: request)
    }

    func removeSharedUser(profileId: String, sharedProfileId: String) async throws {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/profiles/\(profileId)/shared-profiles/\(sharedProfileId)")!
        try await APIClient.shared.delete(url: url)
    }
}

// MARK: - Helper

private struct EmptyBody: Codable {}
