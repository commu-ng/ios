import Foundation

struct User: Codable, Identifiable {
    let id: String
    let loginName: String
    let email: String?
    let emailVerifiedAt: String?
    let createdAt: String
    let isAdmin: Bool
    let avatarURL: String?

    var avatarImageURL: URL? {
        guard let avatarURL = avatarURL else { return nil }
        return URL(string: avatarURL)
    }

    var emailVerified: Bool {
        emailVerifiedAt != nil
    }

    var signupDate: Date? {
        DateFormatters.iso8601Full.date(from: createdAt)
    }
}

struct LoginResponseData: Codable {
    let id: String
    let loginName: String
    let email: String?
    let emailVerifiedAt: String?
    let createdAt: String
    let isAdmin: Bool
    let sessionToken: String
    let avatarUrl: String?
}

struct LoginResponse: Codable {
    let data: LoginResponseData
}

struct LoginRequest: Codable {
    let loginName: String
    let password: String
}
