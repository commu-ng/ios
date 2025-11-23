import Foundation

// MARK: - App Profile Models
// Note: These are community-specific profiles, different from console User model

struct AppProfile: Codable, Identifiable {
    let id: String
    let name: String
    let username: String
    let bio: String?
    let profilePictureUrl: String?
    let isPrimary: Bool
    let createdAt: String
    let updatedAt: String
    let activatedAt: String?
    let role: String
    private let _isActive: Bool?

    var isActive: Bool {
        _isActive ?? (activatedAt != nil)
    }

    var avatarURL: URL? {
        guard let profilePictureUrl = profilePictureUrl else { return nil }
        return URL(string: profilePictureUrl)
    }

    var createdDate: Date? {
        DateFormatters.iso8601Full.date(from: createdAt)
    }

    var updatedDate: Date? {
        DateFormatters.iso8601Full.date(from: updatedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, username, bio, profilePictureUrl, isPrimary, createdAt, updatedAt, activatedAt
        case role, userRole
        case _isActive = "isActive"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        username = try container.decode(String.self, forKey: .username)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        profilePictureUrl = try container.decodeIfPresent(String.self, forKey: .profilePictureUrl)
        isPrimary = try container.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        activatedAt = try container.decodeIfPresent(String.self, forKey: .activatedAt)
        _isActive = try container.decodeIfPresent(Bool.self, forKey: ._isActive)

        // Handle both "role" and "user_role" field names
        if let roleValue = try container.decodeIfPresent(String.self, forKey: .role) {
            role = roleValue
        } else if let userRoleValue = try container.decodeIfPresent(String.self, forKey: .userRole) {
            role = userRoleValue
        } else {
            role = "member"
        }
    }

    init(id: String, name: String, username: String, bio: String?, profilePictureUrl: String?, isPrimary: Bool, createdAt: String, updatedAt: String, activatedAt: String?, role: String) {
        self.id = id
        self.name = name
        self.username = username
        self.bio = bio
        self.profilePictureUrl = profilePictureUrl
        self.isPrimary = isPrimary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.activatedAt = activatedAt
        self.role = role
        self._isActive = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(username, forKey: .username)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(profilePictureUrl, forKey: .profilePictureUrl)
        try container.encode(isPrimary, forKey: .isPrimary)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(activatedAt, forKey: .activatedAt)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(_isActive, forKey: ._isActive)
    }
}

struct ProfilesResponse: Codable {
    let data: [AppProfile]
}

// MARK: - Profile Create Request

struct ProfileCreateRequest: Codable {
    let name: String
    let username: String
    let bio: String?
    let isPrimary: Bool?
    let profilePictureId: String?
}

// MARK: - Profile Update Request

struct ProfileUpdateRequest: Codable {
    let name: String
    let username: String
    let bio: String?
    let profilePictureId: String?
}

// MARK: - Profile Picture

struct ProfilePicture: Codable, Identifiable {
    let id: String
    let url: String
    let width: Int?
    let height: Int?

    var imageURL: URL? {
        URL(string: url)
    }
}

// MARK: - Username Availability

struct UsernameAvailability: Codable {
    let available: Bool
}

// MARK: - Post Count

struct PostCountResponse: Codable {
    let postCount: Int
}

// MARK: - Online Status

struct OnlineStatusResponse: Codable {
    let status: [String: Bool] // profile_id -> is_online
}

struct OnlineStatusVisibilityRequest: Codable {
    let visibility: String // "visible" or "hidden"
    let profileId: String
}

// MARK: - Profile Sharing (for multi-profile management)

struct SharedUser: Codable, Identifiable {
    let id: String
    let loginName: String
    let email: String?
}

struct ProfileShareRequest: Codable {
    let username: String
    let role: String
}
