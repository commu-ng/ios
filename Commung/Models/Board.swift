import Foundation

struct Board: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let allowComments: Bool
    let createdAt: String?
    let updatedAt: String?
}

struct Post: Codable, Identifiable {
    let id: String
    let title: String
    let content: String?
    let image: PostImage?
    let hashtags: [PostHashtag]
    let author: PostAuthor
    let createdAt: String
    let updatedAt: String
}

struct PostImage: Codable {
    let id: String
    let url: String
    let width: Int
    let height: Int
    let filename: String
}

struct PostHashtag: Codable, Identifiable {
    let id: String
    let tag: String
}

struct PostAuthor: Codable {
    let id: String
    let loginName: String
    let avatarURL: String?

    var avatarImageURL: URL? {
        guard let avatarURL = avatarURL else { return nil }
        return URL(string: avatarURL)
    }
}


// API Response wrappers
struct DataResponse<T: Codable>: Codable {
	let data: T
}

struct MessageResponse: Codable {
	let success: Bool
	let code: String
	let message: String
}

struct PaginationInfo: Codable {
	let nextCursor: String?
	let hasMore: Bool
	let totalCount: Int
}

struct PostsListResponse: Codable {
	let data: [Post]
	let pagination: PaginationInfo

	var posts: [Post] {
		return data
	}

	var nextCursor: String? {
		return pagination.nextCursor
	}

	var hasMore: Bool {
		return pagination.hasMore
	}
}

struct PostDetailResponse: Codable {
	let post: Post
}

struct BoardPostReply: Codable, Identifiable {
    let id: String
    let content: String
    let depth: Int
    let author: PostAuthor
    let createdAt: String
    let updatedAt: String
    let replies: [BoardPostReply]?
}

struct RepliesListResponse: Codable {
    let data: [BoardPostReply]
    let pagination: PaginationInfo

    var replies: [BoardPostReply] {
        return data
    }

    var nextCursor: String? {
        return pagination.nextCursor
    }

    var hasMore: Bool {
        return pagination.hasMore
    }
}

struct ImageUploadResponse: Codable {
    let id: String
    let url: String
    let width: Int
    let height: Int
    let filename: String
}
