import Foundation

struct NotificationModel: Codable, Identifiable {
    let id: String
    let type: String
    let content: String
    let readAt: String?
    let createdAt: String
    let communityUrl: String?
    let communityName: String?
    let sender: NotificationSender?
    let relatedPost: NotificationRelatedPost?
}

struct NotificationSender: Codable {
    let id: String
    let name: String
    let username: String
    let profilePictureUrl: String?
}

struct NotificationRelatedPost: Codable {
    let id: String
    let content: String
    let author: NotificationAuthor
}

struct NotificationAuthor: Codable {
    let id: String
    let name: String
    let username: String
    let profilePictureUrl: String?
}

struct NotificationResponse: Codable {
    let data: [NotificationModel]
    let pagination: ApiPagination
}

struct UnreadCountResponse: Codable {
    let count: Int
}
