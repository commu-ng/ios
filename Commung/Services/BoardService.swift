import Foundation

struct CreateReplyRequest: Codable {
    let content: String
    let inReplyToId: String?
}

struct UpdateReplyRequest: Codable {
    let content: String
}

struct CreatePostRequest: Codable {
    let title: String
    let content: String
    let imageId: String?
    let hashtags: [String]?
}

class BoardService {
    static let shared = BoardService()

    private init() {}

	func getBoards() async throws -> [Board] {
		let response: DataResponse<[Board]> = try await APIClient.shared.request(
			endpoint: "/console/boards",
			method: "GET",
			requiresAuth: false
		)
		return response.data
	}

	func getBoard(boardSlug: String) async throws -> Board {
		let response: DataResponse<Board> = try await APIClient.shared.request(
			endpoint: "/console/board/\(boardSlug)",
			method: "GET",
			requiresAuth: false
		)
		return response.data
	}

	func getBoardHashtags(boardSlug: String) async throws -> [String] {
		let response: DataResponse<[String]> = try await APIClient.shared.request(
			endpoint: "/console/board/\(boardSlug)/hashtags",
			method: "GET",
			requiresAuth: false
		)
		return response.data
	}

    func getPosts(
        boardSlug: String,
        hashtags: [String]? = nil,
        cursor: String? = nil,
        limit: Int = 20
    ) async throws -> PostsListResponse {
        var endpoint = "/console/board/\(boardSlug)/posts?limit=\(limit)"

        if let hashtags = hashtags, !hashtags.isEmpty {
            let hashtagsQuery = hashtags.map { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }.joined(separator: ",")
            endpoint += "&hashtags=\(hashtagsQuery)"
        }

        if let cursor = cursor {
            let encodedCursor = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encodedCursor)"
        }

        return try await APIClient.shared.request(
            endpoint: endpoint,
            method: "GET",
            requiresAuth: false
        )
    }

	func getPost(postId: String) async throws -> Post {
		let response: DataResponse<Post> = try await APIClient.shared.request(
			endpoint: "/console/posts/\(postId)",
			method: "GET",
			requiresAuth: false
		)
		return response.data
	}

    func getReplies(
        boardSlug: String,
        postId: String,
        cursor: String? = nil,
        limit: Int = 20
    ) async throws -> RepliesListResponse {
        var endpoint = "/console/board/\(boardSlug)/posts/\(postId)/replies?limit=\(limit)"

        if let cursor = cursor {
            let encodedCursor = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encodedCursor)"
        }

        return try await APIClient.shared.request(
            endpoint: endpoint,
            method: "GET",
            requiresAuth: false
        )
    }

    func createReply(
        boardSlug: String,
        postId: String,
        content: String,
        inReplyToId: String? = nil
    ) async throws -> BoardPostReply {
        let body = CreateReplyRequest(content: content, inReplyToId: inReplyToId)

        let response: DataResponse<BoardPostReply> = try await APIClient.shared.request(
            endpoint: "/console/board/\(boardSlug)/posts/\(postId)/replies",
            method: "POST",
            body: body,
            requiresAuth: true
        )
        return response.data
    }

    func updateReply(
        boardSlug: String,
        postId: String,
        replyId: String,
        content: String
    ) async throws -> BoardPostReply {
        let body = UpdateReplyRequest(content: content)

        let response: DataResponse<BoardPostReply> = try await APIClient.shared.request(
            endpoint: "/console/board/\(boardSlug)/posts/\(postId)/replies/\(replyId)",
            method: "PATCH",
            body: body,
            requiresAuth: true
        )
        return response.data
    }

    func deletePost(
        boardSlug: String,
        postId: String
    ) async throws {
        let _: MessageResponse = try await APIClient.shared.request(
            endpoint: "/console/board/\(boardSlug)/posts/\(postId)",
            method: "DELETE",
            requiresAuth: true
        )
    }

    func deleteReply(
        boardSlug: String,
        postId: String,
        replyId: String
    ) async throws {
        let _: MessageResponse = try await APIClient.shared.request(
            endpoint: "/console/board/\(boardSlug)/posts/\(postId)/replies/\(replyId)",
            method: "DELETE",
            requiresAuth: true
        )
    }

    func uploadImage(imageData: Data, fileName: String) async throws -> ImageUploadResponse {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(Constants.apiBaseURL)/console/upload/file")!)
        request.httpMethod = "POST"

        // Set auth header if available
        if let sessionToken = KeychainService.shared.load(forKey: Constants.Keychain.sessionTokenKey) {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Detect content type from file extension
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        let contentType: String
        switch fileExtension {
        case "png":
            contentType = "image/png"
        case "gif":
            contentType = "image/gif"
        case "webp":
            contentType = "image/webp"
        case "heic", "heif":
            contentType = "image/heic"
        default:
            contentType = "image/jpeg"
        }

        var body = Data()

        // Add file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("Server error: \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let wrapper = try decoder.decode(ImageUploadResponseWrapper.self, from: data)
        return wrapper.data
    }

    func createPost(
        boardSlug: String,
        title: String,
        content: String,
        imageId: String? = nil,
        hashtags: [String]? = nil
    ) async throws -> Post {
        let body = CreatePostRequest(
            title: title,
            content: content,
            imageId: imageId,
            hashtags: hashtags
        )

        let response: DataResponse<Post> = try await APIClient.shared.request(
            endpoint: "/console/board/\(boardSlug)/posts",
            method: "POST",
            body: body,
            requiresAuth: true
        )
        return response.data
    }

    func reportPost(
        boardSlug: String,
        postId: String,
        reason: String
    ) async throws {
        struct ReportRequest: Codable {
            let reason: String
        }

        struct ReportResponse: Codable {
            let success: Bool
        }

        let body = ReportRequest(reason: reason)

        let _: ReportResponse = try await APIClient.shared.request(
            endpoint: "/console/board/\(boardSlug)/posts/\(postId)/report",
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
}
