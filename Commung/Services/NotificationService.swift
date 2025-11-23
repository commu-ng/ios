import Foundation

class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func getNotifications(profileId: String, cursor: String? = nil, limit: Int = 20) async throws -> NotificationResponse {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/notifications")!
        var queryItems = [
            URLQueryItem(name: "profile_id", value: profileId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        let response: NotificationResponse = try await APIClient.shared.get(url: components.url!)
        return response
    }

    func getUnreadCount(profileId: String) async throws -> Int {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/notifications/unread-count")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct UnreadCountData: Codable {
            let count: Int
        }

        struct WrappedUnreadCountResponse: Codable {
            let data: UnreadCountData
        }

        let response: WrappedUnreadCountResponse = try await APIClient.shared.get(url: components.url!)
        return response.data.count
    }

    func markAllAsRead(profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/notifications/mark-all-read")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct MarkAllReadResponse: Decodable {
            let data: MarkAllReadData
        }

        struct MarkAllReadData: Decodable {
            let profileId: String
            let allRead: Bool
            let readAt: String
        }

        let _: MarkAllReadResponse = try await APIClient.shared.post(url: components.url!, body: Optional<String>.none)
    }

    func markAsRead(notificationId: String, profileId: String) async throws {
        var components = URLComponents(string: "\(APIClient.apiBaseURL)/app/notifications/\(notificationId)/read")!
        components.queryItems = [URLQueryItem(name: "profile_id", value: profileId)]

        struct MarkReadResponse: Decodable {
            let data: MarkReadData
        }

        struct MarkReadData: Decodable {
            let id: String
            let isRead: Bool
            let readAt: String
        }

        let _: MarkReadResponse = try await APIClient.shared.post(url: components.url!, body: Optional<String>.none)
    }
}
