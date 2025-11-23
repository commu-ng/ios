import SwiftUI
import Combine

struct ScheduledPostsView: View {
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = ScheduledPostsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView()
            } else if viewModel.posts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("scheduled.no_posts", comment: ""))
                        .font(.title2)
                        .fontWeight(.medium)
                    Text(NSLocalizedString("scheduled.empty_message", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.posts) { post in
                        ScheduledPostRow(post: post, onDelete: {
                            Task {
                                await viewModel.deletePost(post)
                            }
                        })
                    }

                    if viewModel.hasMore {
                        Button(NSLocalizedString("scheduled.load_more", comment: "")) {
                            Task {
                                await viewModel.loadMore()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(NSLocalizedString("scheduled.title", comment: ""))
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            guard let profileId = profileContext.currentProfileId else { return }
            await viewModel.loadPosts(profileId: profileId)
        }
    }
}

struct ScheduledPostRow: View {
    let post: CommunityPost
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Scheduled time
            if let scheduledAt = post.scheduledAt, let date = DateFormatters.iso8601Full.date(from: scheduledAt) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                    Text(date, style: .date)
                    Text(date, style: .time)
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }

            // Content preview
            Text(post.content)
                .font(.body)
                .lineLimit(4)

            // Images indicator
            if !post.images.isEmpty {
                HStack {
                    Image(systemName: "photo")
                    Text(String(format: NSLocalizedString("scheduled.images", comment: ""), post.images.count))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            // Actions
            HStack {
                Spacer()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(NSLocalizedString("action.delete", comment: ""), systemImage: "trash")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 8)
        .confirmationDialog(
            NSLocalizedString("scheduled.delete_title", comment: ""),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("action.delete", comment: ""), role: .destructive) {
                onDelete()
            }
            Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("scheduled.delete_message", comment: ""))
        }
    }
}

@MainActor
class ScheduledPostsViewModel: ObservableObject {
    @Published var posts: [CommunityPost] = []
    @Published var isLoading = false
    @Published var hasMore = false
    @Published var errorMessage: String?

    private var nextCursor: String?
    private var profileId: String?

    func loadPosts(profileId: String) async {
        guard !isLoading else { return }

        self.profileId = profileId
        isLoading = true
        errorMessage = nil

        do {
            let response = try await PostService.shared.getScheduledPosts(
                profileId: profileId,
                limit: 20,
                cursor: nil
            )
            posts = response.data
            nextCursor = response.pagination.nextCursor
            hasMore = response.pagination.hasMore
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load scheduled posts: \(error)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore, let cursor = nextCursor, let profileId = profileId else { return }

        isLoading = true

        do {
            let response = try await PostService.shared.getScheduledPosts(
                profileId: profileId,
                limit: 20,
                cursor: cursor
            )
            posts.append(contentsOf: response.data)
            nextCursor = response.pagination.nextCursor
            hasMore = response.pagination.hasMore
        } catch {
            print("Failed to load more scheduled posts: \(error)")
        }

        isLoading = false
    }

    func refresh() async {
        guard let profileId = profileId else { return }
        nextCursor = nil
        await loadPosts(profileId: profileId)
    }

    func deletePost(_ post: CommunityPost) async {
        guard let profileId = profileId else { return }

        do {
            try await PostService.shared.deletePost(postId: post.id, profileId: profileId)
            posts.removeAll { $0.id == post.id }
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to delete scheduled post: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        ScheduledPostsView()
            .environmentObject(ProfileContext())
    }
}
