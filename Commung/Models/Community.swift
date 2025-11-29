import Foundation

struct Community: Codable, Identifiable, Hashable {
    static func == (lhs: Community, rhs: Community) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: String
    let name: String
    let slug: String
    let startsAt: String
    let endsAt: String
    let isRecruiting: Bool
    let recruitingStartsAt: String?
    let recruitingEndsAt: String?
    let minimumBirthYear: Int?
    let createdAt: String
    let role: String?
    let customDomain: String?
    let domainVerified: String?
    let bannerImageUrl: String?
    let bannerImageWidth: Int?
    let bannerImageHeight: Int?
    let hashtags: [CommunityHashtag]
    let ownerProfileId: String?
    let pendingApplicationCount: Int?

    var communityURL: String {
        if let customDomain = customDomain, domainVerified != nil {
            return "https://\(customDomain)"
        }
        return "https://\(slug).commu.ng"
    }

    var bannerURL: URL? {
        guard let bannerImageUrl = bannerImageUrl else { return nil }
        return URL(string: bannerImageUrl)
    }
}

struct CommunityHashtag: Codable, Identifiable {
    let id: String
    let tag: String
}

struct CommunitiesListResponse: Codable {
    let data: [Community]

    var communities: [Community] {
        return data
    }
}

struct CommunityDetails: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let startsAt: String
    let endsAt: String
    let isRecruiting: Bool
    let recruitingStartsAt: String?
    let recruitingEndsAt: String?
    let minimumBirthYear: Int?
    let createdAt: String
    let customDomain: String?
    let domainVerified: String?
    let bannerImageUrl: String?
    let bannerImageWidth: Int?
    let bannerImageHeight: Int?
    let hashtags: [CommunityHashtag]
    let description: String?
    let membershipStatus: String?
    let userRole: String?

    var communityURL: String {
        if let customDomain = customDomain, domainVerified != nil {
            return "https://\(customDomain)"
        }
        return "https://\(slug).commu.ng"
    }

    var bannerURL: URL? {
        guard let bannerImageUrl = bannerImageUrl else { return nil }
        return URL(string: bannerImageUrl)
    }
}

struct CommunityLink: Codable, Identifiable {
    let id: String
    let title: String
    let url: String
    let createdAt: String
    let updatedAt: String
}

struct CommunityApplication: Codable, Identifiable {
    let id: String
    let status: String
    let profileName: String
    let profileUsername: String
    let message: String?
    let rejectionReason: String?
    let createdAt: String
}

struct CommunityApplicationDetail: Codable, Identifiable {
    let id: String
    let status: String
    let profileName: String
    let profileUsername: String
    let message: String?
    let rejectionReason: String?
    let createdAt: String
    let reviewedAt: String?
    let applicant: ApplicationApplicant?
    let reviewedBy: ApplicationReviewer?
}

struct ApplicationApplicant: Codable {
    let profileId: String?
}

struct ApplicationReviewer: Codable {
    let profileId: String?
}

struct ApplicationReviewResponse: Codable {
    let id: String
    let status: String
    let reviewedAt: String?
    let membershipId: String?
    let profileId: String?
}

struct CommunityCreateRequest: Encodable {
    let name: String
    let slug: String
    let startsAt: String
    let endsAt: String
    let isRecruiting: Bool
    let recruitingStartsAt: String?
    let recruitingEndsAt: String?
    let minimumBirthYear: Int?
    let imageId: String?
    let hashtags: [String]?
    let profileUsername: String
    let profileName: String
    let description: String?
    let muteNewMembers: Bool?

    enum CodingKeys: String, CodingKey {
        case name, slug, hashtags, description
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case isRecruiting = "is_recruiting"
        case recruitingStartsAt = "recruiting_starts_at"
        case recruitingEndsAt = "recruiting_ends_at"
        case minimumBirthYear = "minimum_birth_year"
        case imageId = "image_id"
        case profileUsername = "profile_username"
        case profileName = "profile_name"
        case muteNewMembers = "mute_new_members"
    }
}

struct CommunityCreateResponse: Codable {
    let id: String
    let name: String
    let domain: String
    let startsAt: String
    let endsAt: String
    let isRecruiting: Bool
    let ownerProfileId: String
    let createdAt: String
}

struct CommunityUpdateRequest: Encodable {
    let name: String
    let slug: String
    let startsAt: String
    let endsAt: String
    let isRecruiting: Bool
    let recruitingStartsAt: String?
    let recruitingEndsAt: String?
    let minimumBirthYear: Int?
    let imageId: String?
    let hashtags: [String]?
    let description: String?
    let muteNewMembers: Bool?

    enum CodingKeys: String, CodingKey {
        case name, slug, hashtags, description
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case isRecruiting = "is_recruiting"
        case recruitingStartsAt = "recruiting_starts_at"
        case recruitingEndsAt = "recruiting_ends_at"
        case minimumBirthYear = "minimum_birth_year"
        case imageId = "image_id"
        case muteNewMembers = "mute_new_members"
    }
}

struct CommunityUpdateResponse: Codable {
    let id: String
    let name: String
    let slug: String
    let startsAt: String
    let endsAt: String
    let isRecruiting: Bool
    let recruitingStartsAt: String?
    let recruitingEndsAt: String?
}
