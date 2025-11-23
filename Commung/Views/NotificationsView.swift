import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var viewModel: NotificationViewModel
    @EnvironmentObject var profileContext: ProfileContext

    var body: some View {
        NavigationView {
            Group {
                if profileContext.currentProfileId == nil {
                    ContentUnavailableView(
                        NSLocalizedString("No Profile Selected", comment: ""),
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text(NSLocalizedString("Please select a profile.", comment: ""))
                    )
                } else if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView()
                } else if let error = viewModel.error, viewModel.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Text(error)
                            .foregroundColor(.secondary)
                        Button(NSLocalizedString("action.retry", comment: "")) {
                            Task {
                                if let profileId = profileContext.currentProfileId {
                                    await viewModel.loadNotifications(profileId: profileId, refresh: true)
                                }
                            }
                        }
                    }
                } else if viewModel.notifications.isEmpty {
                    VStack {
                        Text(NSLocalizedString("notifications.empty", comment: ""))
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                } else {
                    List {
                        ForEach(viewModel.notifications) { notification in
                            if let relatedPost = notification.relatedPost {
                                NavigationLink(destination: AppPostDetailView(postId: relatedPost.id)
                                    .environmentObject(profileContext)
                                    .onAppear {
                                        print("🔗 Navigated to post \(relatedPost.id) from notification \(notification.id)")
                                        Task {
                                            if let profileId = profileContext.currentProfileId {
                                                await viewModel.markAsRead(notificationId: notification.id, profileId: profileId)
                                            }
                                        }
                                    }
                                ) {
                                    NotificationRow(notification: notification)
                                }
                                .onAppear {
                                    // Trigger infinite scroll when user reaches the last item
                                    if notification.id == viewModel.notifications.last?.id {
                                        Task {
                                            if let profileId = profileContext.currentProfileId {
                                                await viewModel.loadNotifications(profileId: profileId, refresh: false)
                                            }
                                        }
                                    }
                                }
                            } else {
                                NotificationRow(notification: notification)
                                    .onTapGesture {
                                        print("⚠️ Tapped notification \(notification.id) [\(notification.type)] -> NO relatedPost, just marking as read")
                                        Task {
                                            if let profileId = profileContext.currentProfileId {
                                                await viewModel.markAsRead(notificationId: notification.id, profileId: profileId)
                                            }
                                        }
                                    }
                                    .onAppear {
                                        // Trigger infinite scroll when user reaches the last item
                                        if notification.id == viewModel.notifications.last?.id {
                                            Task {
                                                if let profileId = profileContext.currentProfileId {
                                                    await viewModel.loadNotifications(profileId: profileId, refresh: false)
                                                }
                                            }
                                        }
                                    }
                            }
                        }

                        if viewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                    .refreshable {
                        if let profileId = profileContext.currentProfileId {
                            await viewModel.loadNotifications(profileId: profileId, refresh: true)
                            await viewModel.loadUnreadCount(profileId: profileId)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav.notifications", comment: ""))
            .toolbar {
                if !viewModel.notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                if let profileId = profileContext.currentProfileId {
                                    await viewModel.markAllAsRead(profileId: profileId)
                                }
                            }
                        }) {
                            Image(systemName: "checkmark.circle")
                        }
                    }
                }
            }
            .task {
                // Load notifications when tab is entered
                if let profileId = profileContext.currentProfileId {
                    await viewModel.loadNotifications(profileId: profileId, refresh: true)
                }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: NotificationModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Notification type icon
            Image(systemName: notificationIcon)
                .foregroundColor(notificationColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.content)
                    .font(.body)
                    .fontWeight(notification.readAt == nil ? .bold : .regular)

                HStack(spacing: 4) {
                    if let communityName = notification.communityName {
                        Text(communityName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(formatTimestamp(notification.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if notification.readAt == nil {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .background(notification.readAt == nil ? Color.blue.opacity(0.05) : Color.clear)
    }

    private var notificationIcon: String {
        switch notification.type {
        case "reply":
            return "arrowshape.turn.up.left.fill"
        case "mention":
            return "at"
        case "reaction":
            return "heart.fill"
        default:
            return "bell.fill"
        }
    }

    private var notificationColor: Color {
        switch notification.type {
        case "reply":
            return .blue
        case "mention":
            return .purple
        case "reaction":
            return .pink
        default:
            return .gray
        }
    }

    private func formatTimestamp(_ timestamp: String) -> String {
        // Parse PostgreSQL timestamp format: "2025-11-17 20:43:27.110565+09"
        var date: Date?

        // Try ISO 8601 format first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        date = iso8601Formatter.date(from: timestamp)

        // If that fails, try PostgreSQL timestamp format
        if date == nil {
            let pgFormatter = DateFormatter()
            pgFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZZZZZ"
            pgFormatter.locale = Locale(identifier: "en_US_POSIX")
            date = pgFormatter.date(from: timestamp)
        }

        guard let date = date else {
            return timestamp
        }

        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 {
            return NSLocalizedString("time.just_now", comment: "")
        } else if diff < 3600 {
            let minutes = Int(diff / 60)
            return String(format: NSLocalizedString("time.minutes_ago", comment: ""), minutes)
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return String(format: NSLocalizedString("time.hours_ago", comment: ""), hours)
        } else if diff < 604800 {
            let days = Int(diff / 86400)
            return String(format: NSLocalizedString("time.days_ago", comment: ""), days)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            return dateFormatter.string(from: date)
        }
    }
}
