import Foundation

class PostService {
    static let shared = PostService()

    private init() {}

    // MARK: - Get Posts

    func getPosts(profileId: String?, limit: Int = 20, cursor: String? = nil) async throws -> CommunityPostsResponse {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/posts")!

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
        return try await APIClient.shared.get(url: components.url!)
    }

    // MARK: - Get Single Post

    func getPost(postId: String, profileId: String?) async throws -> CommunityPost {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/posts/\(postId)")!

        if let profileId = profileId {
            components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]
        }

        struct PostResponse: Codable {
            let data: CommunityPost
        }

        let response: PostResponse = try await APIClient.shared.get(url: components.url!)
        return response.data
    }

    // MARK: - Create Post

    func createPost(request: PostCreateRequest) async throws -> CommunityPost {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/posts")!

        struct PostResponse: Codable {
            let data: CommunityPost
        }

        let response: PostResponse = try await APIClient.shared.post(url: url, body: request)
        return response.data
    }

    // MARK: - Update Post

    func updatePost(postId: String, profileId: String, request: PostUpdateRequest) async throws -> CommunityPost {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/posts/\(postId)")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct PostResponse: Codable {
            let data: CommunityPost
        }

        let response: PostResponse = try await APIClient.shared.patch(url: components.url!, body: request)
        return response.data
    }

    // MARK: - Delete Post

    func deletePost(postId: String, profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/posts/\(postId)")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        try await APIClient.shared.delete(url: components.url!)
    }

    // MARK: - Search Posts

    func searchPosts(query: String, profileId: String, limit: Int = 20, cursor: String? = nil) async throws -> CommunityPostsResponse {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/posts/search")!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "profile_id", value: profileId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems

        // CommunityPostsResponse already has data field
        return try await APIClient.shared.get(url: components.url!)
    }

    // MARK: - Get Announcements

    func getAnnouncements(profileId: String?) async throws -> [CommunityPost] {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/announcements")!

        if let profileId = profileId {
            components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]
        }

        struct AnnouncementsResponse: Codable {
            let data: [CommunityPost]
        }

        let response: AnnouncementsResponse = try await APIClient.shared.get(url: components.url!)
        return response.data
    }

    // MARK: - Get Scheduled Posts

    func getScheduledPosts(profileId: String, limit: Int = 20, cursor: String? = nil) async throws -> ScheduledPostsResponse {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/scheduled-posts")!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "profile_id", value: profileId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems

        // ScheduledPostsResponse already has data field
        return try await APIClient.shared.get(url: components.url!)
    }

    // MARK: - Reactions

    func addReaction(postId: String, emoji: String, profileId: String) async throws -> ReactionCreateResponse {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/posts/\(postId)/reactions")!

        struct ReactionRequest: Codable {
            let emoji: String
            let profileId: String
        }

        struct ReactionResponse: Codable {
            let data: ReactionCreateResponse
        }

        let request = ReactionRequest(emoji: emoji, profileId: profileId)
        let response: ReactionResponse = try await APIClient.shared.post(url: url, body: request)
        return response.data
    }

    func removeReaction(postId: String, emoji: String, profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/posts/\(postId)/reactions")!
        components.queryItems = [
            URLQueryItem(name: "emoji", value: emoji),
            URLQueryItem(name: "profile_id", value: profileId)
        ]

        try await APIClient.shared.delete(url: components.url!)
    }

    // MARK: - Bookmarks

    func bookmarkPost(postId: String, profileId: String) async throws -> BookmarkCreateResponse {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/posts/\(postId)/bookmark")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct BookmarkResponse: Codable {
            let data: BookmarkCreateResponse
        }

        let response: BookmarkResponse = try await APIClient.shared.post(url: components.url!, body: EmptyBody())
        return response.data
    }

    func unbookmarkPost(postId: String, profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/posts/\(postId)/bookmark")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        try await APIClient.shared.delete(url: components.url!)
    }

    func getBookmarks(profileId: String, limit: Int = 20, cursor: String? = nil) async throws -> CommunityPostsResponse {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/bookmarks")!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "profile_id", value: profileId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems

        // CommunityPostsResponse already has data field
        return try await APIClient.shared.get(url: components.url!)
    }

    // MARK: - Pin/Unpin

    func pinPost(postId: String, profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/posts/\(postId)/pin")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        let _: EmptyResponse = try await APIClient.shared.post(url: components.url!, body: EmptyBody())
    }

    func unpinPost(postId: String, profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/posts/\(postId)/pin")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        try await APIClient.shared.delete(url: components.url!)
    }

    // MARK: - Post History

    func getPostHistory(postId: String) async throws -> [PostHistory] {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/posts/\(postId)/history")!

        struct HistoryResponse: Codable {
            let data: [PostHistory]
        }

        let response: HistoryResponse = try await APIClient.shared.get(url: url)
        return response.data
    }

    // MARK: - Report Post

    func reportPost(postId: String, profileId: String, reason: String) async throws {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/posts/\(postId)/report")!

        struct ReportRequest: Codable {
            let reason: String
            let profileId: String
        }

        let request = ReportRequest(reason: reason, profileId: profileId)
        let _: EmptyResponse = try await APIClient.shared.post(url: url, body: request)
    }

    // MARK: - Image Upload

    func uploadImage(imageData: Data, filename: String) async throws -> CommunityPostImage {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/upload/file")!
        let response: ApiResponse<CommunityPostImage> = try await APIClient.shared.uploadFile(url: url, fileData: imageData, filename: filename, fieldName: "file")
        return response.data
    }

    // MARK: - Export

    func createExport(profileId: String) async throws -> ExportJob {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/export")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct ExportResponse: Codable {
            let data: ExportJob
        }

        let response: ExportResponse = try await APIClient.shared.post(url: components.url!, body: EmptyBody())
        return response.data
    }

    func getExportStatus(jobId: String) async throws -> ExportJob {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/export/\(jobId)")!

        struct ExportResponse: Codable {
            let data: ExportJob
        }

        let response: ExportResponse = try await APIClient.shared.get(url: url)
        return response.data
    }

    func getExports(profileId: String) async throws -> [ExportJob] {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/exports")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct ExportsResponse: Codable {
            let data: [ExportJob]
        }

        let response: ExportsResponse = try await APIClient.shared.get(url: components.url!)
        return response.data
    }
}

// MARK: - Helper

private struct EmptyBody: Codable {}
