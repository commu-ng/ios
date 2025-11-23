import Foundation

class MessageService {
    static let shared = MessageService()

    private init() {}

    // MARK: - Direct Messages

    func sendMessage(request: MessageCreateRequest) async throws -> Message {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/messages")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: request.profileId)]

        struct MessageBody: Codable {
            let content: String
            let receiverId: String
            let imageIds: [String]?
        }

        let body = MessageBody(
            content: request.content,
            receiverId: request.receiverId,
            imageIds: request.imageIds
        )

        struct MessageResponse: Codable {
            let data: Message
        }

        let response: MessageResponse = try await APIClient.shared.post(url: components.url!, body: body)
        return response.data
    }

    func deleteMessage(messageId: String, profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/messages/\(messageId)")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        try await APIClient.shared.delete(url: components.url!)
    }

    func getUnreadMessageCount(profileId: String) async throws -> Int {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/messages/unread-count")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct WrappedResponse: Codable {
            let data: MessageUnreadCountResponse
        }

        let response: WrappedResponse = try await APIClient.shared.get(url: components.url!)
        return response.data.count
    }

    func addReactionToMessage(messageId: String, emoji: String, profileId: String) async throws -> MessageReaction {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/messages/\(messageId)/reactions")!
        let request = MessageReactionCreateRequest(emoji: emoji, profileId: profileId)

        struct ReactionResponse: Codable {
            let data: MessageReaction
        }

        let response: ReactionResponse = try await APIClient.shared.post(url: url, body: request)
        return response.data
    }

    func removeReactionFromMessage(messageId: String, emoji: String, profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/messages/\(messageId)/reactions")!
        components.queryItems = [
            URLQueryItem(name: "emoji", value: emoji),
            URLQueryItem(name: "profile_id", value: profileId)
        ]

        try await APIClient.shared.delete(url: components.url!)
    }

    // MARK: - Conversations

    func getConversations(profileId: String, limit: Int = 20, cursor: String? = nil) async throws -> ConversationsResponse {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/conversations")!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "profile_id", value: profileId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems

        // ConversationsResponse already has data field
        return try await APIClient.shared.get(url: components.url!)
    }

    func getConversationThread(otherProfileId: String, profileId: String, limit: Int = 50, cursor: String? = nil) async throws -> ConversationThread {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/conversations/\(otherProfileId)")!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "profile_id", value: profileId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems

        // ConversationThread already has data field
        return try await APIClient.shared.get(url: components.url!)
    }

    func markConversationAsRead(otherProfileId: String, profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/conversations/\(otherProfileId)/mark-read")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct EmptyBody: Codable {}
        let _: EmptyResponse = try await APIClient.shared.post(url: components.url!, body: EmptyBody())
    }

    func markAllConversationsAsRead(profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/conversations/mark-all-read")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct EmptyBody: Codable {}
        let _: EmptyResponse = try await APIClient.shared.post(url: components.url!, body: EmptyBody())
    }

    // MARK: - Group Chats

    func getGroupChats(profileId: String, limit: Int = 20, cursor: String? = nil) async throws -> GroupChatsResponse {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/group-chats")!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "profile_id", value: profileId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems

        // GroupChatsResponse already has data field
        return try await APIClient.shared.get(url: components.url!)
    }

    func createGroupChat(request: GroupChatCreateRequest) async throws -> GroupChat {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/group-chats")!

        struct GroupChatResponse: Codable {
            let data: GroupChat
        }

        let response: GroupChatResponse = try await APIClient.shared.post(url: url, body: request)
        return response.data
    }

    func getGroupChat(groupChatId: String, profileId: String) async throws -> GroupChat {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/group-chats/\(groupChatId)")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct GroupChatResponse: Codable {
            let data: GroupChat
        }

        let response: GroupChatResponse = try await APIClient.shared.get(url: components.url!)
        return response.data
    }

    func getGroupChatMessages(groupChatId: String, profileId: String, limit: Int = 50, cursor: String? = nil) async throws -> GroupChatMessagesResponse {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/group-chats/\(groupChatId)/messages")!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "profile_id", value: profileId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems

        // GroupChatMessagesResponse already has data field
        return try await APIClient.shared.get(url: components.url!)
    }

    func sendGroupChatMessage(groupChatId: String, request: GroupChatMessageCreateRequest) async throws -> Message {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/group-chats/\(groupChatId)/messages")!

        struct MessageResponse: Codable {
            let data: Message
        }

        let response: MessageResponse = try await APIClient.shared.post(url: url, body: request)
        return response.data
    }

    func addReactionToGroupChatMessage(groupChatId: String, messageId: String, emoji: String, profileId: String) async throws -> MessageReaction {
        let url = URL(string: "\(APIClient.apiBaseURL)/app/group-chats/\(groupChatId)/messages/\(messageId)/reactions")!
        let request = MessageReactionCreateRequest(emoji: emoji, profileId: profileId)

        struct ReactionResponse: Codable {
            let data: MessageReaction
        }

        let response: ReactionResponse = try await APIClient.shared.post(url: url, body: request)
        return response.data
    }

    func removeReactionFromGroupChatMessage(groupChatId: String, messageId: String, emoji: String, profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/group-chats/\(groupChatId)/messages/\(messageId)/reactions")!
        components.queryItems = [
            URLQueryItem(name: "emoji", value: emoji),
            URLQueryItem(name: "profile_id", value: profileId)
        ]

        try await APIClient.shared.delete(url: components.url!)
    }

    func markGroupChatAsRead(groupChatId: String, profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/group-chats/\(groupChatId)/mark-read")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct EmptyBody: Codable {}
        let _: EmptyResponse = try await APIClient.shared.post(url: components.url!, body: EmptyBody())
    }
}
