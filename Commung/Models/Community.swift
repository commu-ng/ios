import Foundation

struct Community: Codable, Identifiable {
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
    let role: String
    let customDomain: String?
    let domainVerified: String?
    let bannerImageUrl: String?
    let bannerImageWidth: Int?
    let bannerImageHeight: Int?
    let hashtags: [CommunityHashtag]
    let ownerProfileId: String?
    let pendingApplicationCount: Int

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
