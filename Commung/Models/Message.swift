import Foundation

// MARK: - Message Models

struct Message: Codable, Identifiable {
    let id: String
    let content: String
    let sender: MessageProfile
    let receiver: MessageProfile?
    let groupChatId: String?
    let images: [MessageImage]
    var reactions: [MessageReaction]
    let createdAt: String
    let readAt: String?
    let isSender: Bool

    var createdDate: Date? {
        DateFormatters.iso8601Full.date(from: createdAt)
    }

    var isRead: Bool {
        readAt != nil
    }

    var senderId: String {
        sender.id
    }

    var receiverId: String? {
        receiver?.id
    }
}

struct MessageProfile: Codable, Identifiable {
    let id: String
    let name: String
    let username: String
    let profilePictureUrl: String?

    var avatarURL: URL? {
        guard let profilePictureUrl = profilePictureUrl else { return nil }
        return URL(string: profilePictureUrl)
    }
}

struct MessageImage: Codable, Identifiable {
    let id: String
    let url: String
    let width: Int?
    let height: Int?

    var imageURL: URL? {
        URL(string: url)
    }
}

struct MessageReaction: Codable, Identifiable {
    let emoji: String
    let user: MessageProfile

    var id: String {
        "\(emoji)-\(user.id)"
    }
}

// MARK: - Conversation Models

struct ConversationLastMessage: Codable, Identifiable {
    let id: String
    let content: String
    let createdAt: String
    let isSender: Bool

    var createdDate: Date? {
        DateFormatters.iso8601Full.date(from: createdAt)
    }
}

struct Conversation: Codable, Identifiable {
    let otherProfile: MessageProfile
    let lastMessage: ConversationLastMessage?
    let unreadCount: String

    var id: String {
        otherProfile.id
    }

    var unreadCountInt: Int {
        Int(unreadCount) ?? 0
    }
}

struct ConversationsResponse: Codable {
    let data: [Conversation]
    let pagination: ApiPagination?
}

struct ConversationThread: Codable {
    let data: [Message]
    let pagination: ApiPagination?
}

// MARK: - Group Chat Models

struct GroupChat: Codable, Identifiable {
    let id: String
    let name: String
    let members: [MessageProfile]
    let lastMessage: Message?
    let unreadCount: Int
    let createdAt: String
    let updatedAt: String

    var createdDate: Date? {
        DateFormatters.iso8601Full.date(from: createdAt)
    }

    var updatedDate: Date? {
        DateFormatters.iso8601Full.date(from: updatedAt)
    }
}

struct GroupChatsResponse: Codable {
    let data: [GroupChat]
    let pagination: ApiPagination?
}

struct GroupChatMessagesResponse: Codable {
    let data: [Message]
    let pagination: ApiPagination?
}

// MARK: - Request Models

struct MessageCreateRequest: Codable {
    let content: String
    let receiverId: String
    let profileId: String
    let imageIds: [String]?
}

struct GroupChatCreateRequest: Codable {
    let name: String
    let memberProfileIds: [String]
    let creatorProfileId: String
}

struct GroupChatMessageCreateRequest: Codable {
    let content: String
    let profileId: String
    let imageIds: [String]?
}

struct MessageReactionCreateRequest: Codable {
    let emoji: String
    let profileId: String
}

struct MessageReactionDeleteRequest: Codable {
    let emoji: String
    let profileId: String
}

// MARK: - Unread Count

struct MessageUnreadCountResponse: Codable {
    let count: Int
}
