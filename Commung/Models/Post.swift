import Foundation

// MARK: - Community Post Models

// Note: Using a separate type for parent post to avoid recursive struct issue
struct CommunityPostParent: Codable, Identifiable {
    let id: String
    let content: String
    let author: CommunityPostAuthor
    let createdAt: String
    let images: [CommunityPostImage]

    var profileId: String {
        author.id
    }

    var createdDate: Date? {
        DateFormatters.iso8601Full.date(from: createdAt)
    }
}

struct CommunityPost: Codable, Identifiable {
    let id: String
    let content: String
    let author: CommunityPostAuthor
    let createdAt: String
    let updatedAt: String
    let inReplyToId: String?
    let parentPost: CommunityPostParent?
    let parentThread: [CommunityPostParent]?
    let replies: [CommunityPost]?
    let reactions: [CommunityPostReaction]
    let images: [CommunityPostImage]
    private let _announcement: Bool?
    let contentWarning: String?
    let scheduledAt: String?
    let pinned: Bool?
    let isPinned: Bool?
    private let _isBookmarked: Bool?
    let depth: Int?
    let rootPostId: String?

    var announcement: Bool {
        _announcement ?? false
    }

    var isBookmarked: Bool {
        _isBookmarked ?? false
    }

    /// Returns the immediate parent post from parentThread (last element is the direct parent)
    var immediateParent: CommunityPostParent? {
        parentThread?.last
    }

    var profileId: String {
        author.id
    }

    var replyCount: Int {
        countTotalReplies(replies ?? [])
    }

    var reactionCount: Int {
        reactions.count
    }

    var createdDate: Date? {
        DateFormatters.iso8601Full.date(from: createdAt)
    }

    var updatedDate: Date? {
        DateFormatters.iso8601Full.date(from: updatedAt)
    }

    var scheduledDate: Date? {
        guard let scheduledAt = scheduledAt else { return nil }
        return DateFormatters.iso8601Full.date(from: scheduledAt)
    }

    private func countTotalReplies(_ replies: [CommunityPost]) -> Int {
        var count = replies.count
        for reply in replies {
            count += countTotalReplies(reply.replies ?? [])
        }
        return count
    }

    private enum CodingKeys: String, CodingKey {
        case id, content, author, createdAt, updatedAt, inReplyToId, parentPost, parentThread
        case replies, reactions, images, contentWarning, scheduledAt
        case pinned, isPinned, depth, rootPostId
        case _announcement = "announcement"
        case _isBookmarked = "isBookmarked"
    }
}

struct CommunityPostAuthor: Codable, Identifiable {
    let id: String
    let name: String
    let username: String
    let bio: String?
    let profilePictureUrl: String?
    let isOnline: Bool?

    var avatarURL: URL? {
        guard let profilePictureUrl = profilePictureUrl else { return nil }
        return URL(string: profilePictureUrl)
    }
}

struct CommunityPostImage: Codable, Identifiable {
    let id: String
    let url: String
    let width: Int?
    let height: Int?

    var imageURL: URL? {
        URL(string: url)
    }
}

struct CommunityPostReaction: Codable, Identifiable {
    let emoji: String
    let user: CommunityPostReactionUser

    var id: String {
        "\(emoji)-\(user.id)"
    }

    var profileId: String {
        user.id
    }
}

struct CommunityPostReactionUser: Codable, Identifiable {
    let id: String
    let username: String
    let name: String
}

// MARK: - Post List Response

struct CommunityPostsResponse: Codable {
    let data: [CommunityPost]
    let pagination: ApiPagination
}

// MARK: - Post Create Request

struct PostCreateRequest: Codable {
    let content: String
    let profileId: String
    let inReplyToId: String?
    let imageIds: [String]?
    let announcement: Bool?
    let contentWarning: String?
    let scheduledAt: String?
}

// MARK: - Post Update Request

struct PostUpdateRequest: Codable {
    let content: String
    let imageIds: [String]?
    let contentWarning: String?
}

// MARK: - Scheduled Posts Response

struct ScheduledPostsResponse: Codable {
    let data: [CommunityPost]
    let pagination: ApiPagination
}

// MARK: - Post History

struct PostHistory: Codable, Identifiable {
    let id: String
    let postId: String
    let content: String
    let editedAt: String
    let editedBy: String

    var editedDate: Date? {
        DateFormatters.iso8601Full.date(from: editedAt)
    }
}

// MARK: - Bookmark

struct Bookmark: Codable, Identifiable {
    let id: String
    let postId: String
    let profileId: String
    let createdAt: String
}

struct BookmarkCreateResponse: Codable {
    let message: String
    let bookmarkId: String
}

// MARK: - Reaction Create Response

struct ReactionCreateResponse: Codable, Identifiable {
    let id: String
    let message: String
    let emoji: String
}

struct BookmarkDeleteResponse: Codable {
    let postId: String
    let bookmarked: Bool
}

// MARK: - Export Job

struct ExportJob: Codable, Identifiable {
    let id: String
    let status: String
    let createdAt: String
    let downloadUrl: String?

    var createdDate: Date? {
        DateFormatters.iso8601Full.date(from: createdAt)
    }
}
