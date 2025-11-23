import Foundation
import SwiftUI
import Combine

@MainActor
class NotificationViewModel: ObservableObject {
    @Published var notifications: [NotificationModel] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var unreadCount = 0

    private var currentCursor: String?
    private var hasMore = false
    private var lastLoadTime: Date?
    private var lastUnreadCountLoadTime: Date?

    func loadNotifications(profileId: String, refresh: Bool = false) async {
        // Prevent multiple simultaneous loads
        if isLoading || isLoadingMore {
            return
        }

        // Debounce: if we loaded within the last 2 seconds, skip
        if refresh, let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < 2 {
            return
        }

        if refresh {
            currentCursor = nil
            hasMore = false
            isLoading = true
            lastLoadTime = Date()
        } else {
            // If not refreshing and no more items, skip
            if !hasMore && currentCursor != nil {
                return
            }
            isLoadingMore = true
        }

        error = nil

        do {
            let response = try await NotificationService.shared.getNotifications(profileId: profileId, cursor: currentCursor)

            // Debug: Log notification details
            for notification in response.data {
                if let relatedPost = notification.relatedPost {
                    print("📬 Notification \(notification.id) [\(notification.type)]: has relatedPost \(relatedPost.id)")
                } else {
                    print("⚠️ Notification \(notification.id) [\(notification.type)]: NO relatedPost")
                }
            }

            if refresh {
                notifications = response.data
            } else {
                notifications.append(contentsOf: response.data)
            }

            currentCursor = response.pagination.nextCursor
            hasMore = response.pagination.hasMore
            isLoading = false
            isLoadingMore = false
        } catch is CancellationError {
            // Ignore cancellation errors (e.g., from pull-to-refresh being released early)
            isLoading = false
            isLoadingMore = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            isLoadingMore = false
        }
    }

    func loadUnreadCount(profileId: String) async {
        // Debounce: if we loaded within the last 2 seconds, skip
        if let lastLoad = lastUnreadCountLoadTime, Date().timeIntervalSince(lastLoad) < 2 {
            return
        }

        lastUnreadCountLoadTime = Date()

        do {
            unreadCount = try await NotificationService.shared.getUnreadCount(profileId: profileId)
        } catch is CancellationError {
            // Ignore cancellation errors (e.g., from pull-to-refresh being released early)
            return
        } catch {
            // Silently fail - unread count is not critical
            print("Failed to load unread count: \(error)")
        }
    }

    func markAsRead(notificationId: String, profileId: String) async {
        do {
            try await NotificationService.shared.markAsRead(notificationId: notificationId, profileId: profileId)

            // Update the notification in the list
            if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
                notifications[index] = NotificationModel(
                    id: notifications[index].id,
                    type: notifications[index].type,
                    content: notifications[index].content,
                    readAt: "read",
                    createdAt: notifications[index].createdAt,
                    communityUrl: notifications[index].communityUrl,
                    communityName: notifications[index].communityName,
                    sender: notifications[index].sender,
                    relatedPost: notifications[index].relatedPost
                )
            }

            // Update unread count
            if unreadCount > 0 {
                unreadCount -= 1
            }
        } catch {
            // Silently fail - marking as read is not critical
            print("Failed to mark notification as read: \(error)")
        }
    }

    func markAllAsRead(profileId: String) async {
        do {
            try await NotificationService.shared.markAllAsRead(profileId: profileId)

            // Update all notifications in the list
            notifications = notifications.map { notification in
                NotificationModel(
                    id: notification.id,
                    type: notification.type,
                    content: notification.content,
                    readAt: "read",
                    createdAt: notification.createdAt,
                    communityUrl: notification.communityUrl,
                    communityName: notification.communityName,
                    sender: notification.sender,
                    relatedPost: notification.relatedPost
                )
            }

            // Reset unread count
            unreadCount = 0
        } catch {
            // Silently fail
            print("Failed to mark all as read: \(error)")
        }
    }
}
