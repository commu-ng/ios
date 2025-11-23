import SwiftUI
import Combine
import Kingfisher

struct HomeFeedView: View {
    @EnvironmentObject var communityContext: CommunityContext
    @EnvironmentObject var profileContext: ProfileContext
    @EnvironmentObject var appModeContext: AppModeContext
    @State private var showingComposer = false

    var body: some View {
        NavigationView {
            Group {
                if communityContext.currentCommunity == nil {
                    ContentUnavailableView(
                        NSLocalizedString("No Community Selected", comment: ""),
                        systemImage: "person.3",
                        description: Text(NSLocalizedString("Please select a community from the Profile tab.", comment: ""))
                    )
                } else if profileContext.currentProfile == nil {
                    ContentUnavailableView(
                        NSLocalizedString("No Profile Selected", comment: ""),
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text(NSLocalizedString("Loading your profile...", comment: ""))
                    )
                } else {
                    PostListView(showingComposer: $showingComposer)
                }
            }
            .navigationTitle(communityContext.currentCommunity?.name ?? NSLocalizedString("nav.home", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation {
                            appModeContext.currentMode = .console
                        }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if profileContext.currentProfile != nil {
                        Button {
                            showingComposer = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingComposer) {
                PostComposerView { newPost in
                    // Refresh feed after posting
                    showingComposer = false
                    NotificationCenter.default.post(name: .homeFeedShouldRefresh, object: nil)
                }
                .environmentObject(profileContext)
            }
        }
    }
}

struct PostListView: View {
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = PostListViewModel()
    @Binding var showingComposer: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        NSLocalizedString("Error", comment: ""),
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.posts.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("No Posts", comment: ""),
                        systemImage: "text.bubble",
                        description: Text(NSLocalizedString("Be the first to post!", comment: ""))
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            NavigationLink(destination: AppPostDetailView(postId: post.id).environmentObject(profileContext)) {
                                PostCardPlaceholder(post: post, onDeleted: {
                                    // Optimistically remove from view
                                    withAnimation {
                                        viewModel.removePost(id: post.id)
                                    }
                                }, onRestorePost: {
                                    // Restore on error
                                    viewModel.restorePost(post, at: index)
                                })
                            }
                            .buttonStyle(PlainButtonStyle())

                            if index < viewModel.posts.count - 1 {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }

                        if viewModel.hasMore {
                            ProgressView()
                                .padding()
                                .onAppear {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            // Only load posts if not already loaded (preserve state when navigating back)
            if viewModel.posts.isEmpty, let profileId = profileContext.currentProfileId {
                await viewModel.loadPosts(profileId: profileId)
            }
        }
        .onChange(of: profileContext.currentProfileId) { oldValue, newValue in
            // Reload when profile changes
            if let profileId = newValue, oldValue != newValue {
                Task {
                    await viewModel.loadPosts(profileId: profileId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeFeedShouldRefresh)) { _ in
            Task {
                await viewModel.refresh()
            }
        }
    }
}

extension Notification.Name {
    static let homeFeedShouldRefresh = Notification.Name("homeFeedShouldRefresh")
}

// Temporary placeholder for post card
struct PostCardPlaceholder: View {
    let post: CommunityPost
    var onDeleted: (() -> Void)? = nil
    var onRestorePost: (() -> Void)? = nil
    @EnvironmentObject var profileContext: ProfileContext
    @State private var showDeleteConfirmation = false
    @State private var showDeleteError = false
    @State private var isDeleting = false
    @State private var contentRevealed = false

    private var isOwnPost: Bool {
        post.author.id == profileContext.currentProfileId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink(destination: ProfileDetailView(username: post.author.username).environmentObject(profileContext)) {
                    CachedCircularImage(url: post.author.avatarURL, size: 40)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        NavigationLink(destination: ProfileDetailView(username: post.author.username).environmentObject(profileContext)) {
                            Text(post.author.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }

                        if post.announcement {
                            Image(systemName: "megaphone.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    Text("@\(post.author.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let createdDate = post.createdDate {
                    Text(createdDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // More options menu for own posts
                if isOwnPost {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label(NSLocalizedString("action.delete", comment: ""), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .padding(4)
                    }
                }
            }

            // Content warning gate
            if let warning = post.contentWarning, !warning.isEmpty, !contentRevealed {
                Button {
                    withAnimation {
                        contentRevealed = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(warning)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(NSLocalizedString("post.show_content", comment: ""))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                TappableMentionText(post.content, font: .body)

                if !post.images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(post.images) { image in
                                if let url = image.imageURL {
                                    KFImage(url)
                                        .placeholder {
                                            Color.gray.opacity(0.2)
                                        }
                                        .fade(duration: 0.2)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 200, height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 20) {
                // Reply count
                Label("\(post.replyCount)", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Reactions
                if let profileId = profileContext.currentProfileId {
                    ReactionButton(
                        postId: post.id,
                        currentReactions: post.reactions,
                        currentProfileId: profileId
                    )
                }

                Spacer()

                // Bookmark
                if let profileId = profileContext.currentProfileId {
                    BookmarkButton(
                        postId: post.id,
                        isBookmarked: post.isBookmarked,
                        currentProfileId: profileId
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .alert(NSLocalizedString("post.delete_confirm_title", comment: ""), isPresented: $showDeleteConfirmation) {
            Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("action.delete", comment: ""), role: .destructive) {
                Task {
                    await deletePost()
                }
            }
        } message: {
            Text(NSLocalizedString("post.delete_confirm_message", comment: ""))
        }
        .alert(NSLocalizedString("error.delete_failed", comment: ""), isPresented: $showDeleteError) {
            Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("error.delete_failed_message", comment: ""))
        }
    }

    private func deletePost() async {
        guard let profileId = profileContext.currentProfileId else { return }

        isDeleting = true

        // Optimistically remove from view
        onDeleted?()

        do {
            try await PostService.shared.deletePost(postId: post.id, profileId: profileId)
        } catch {
            print("Failed to delete post: \(error)")
            // Restore the post on error
            withAnimation {
                onRestorePost?()
            }
            showDeleteError = true
        }

        isDeleting = false
    }
}

@MainActor
class PostListViewModel: ObservableObject {
    @Published var posts: [CommunityPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = false

    private var nextCursor: String?

    func removePost(id: String) {
        posts.removeAll { $0.id == id }
    }

    func restorePost(_ post: CommunityPost, at index: Int) {
        let safeIndex = min(index, posts.count)
        posts.insert(post, at: safeIndex)
    }
    private var currentProfileId: String?

    func loadPosts(profileId: String) async {
        guard !isLoading else { return }

        currentProfileId = profileId
        isLoading = true
        errorMessage = nil

        do {
            let response = try await PostService.shared.getPosts(profileId: profileId, limit: 20, cursor: nil)
            posts = response.data
            nextCursor = response.pagination.nextCursor
            hasMore = response.pagination.hasMore
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load posts: \(error)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore, let cursor = nextCursor else { return }

        isLoading = true

        do {
            let response = try await PostService.shared.getPosts(profileId: nil, limit: 20, cursor: cursor)
            posts.append(contentsOf: response.data)
            nextCursor = response.pagination.nextCursor
            hasMore = response.pagination.hasMore
        } catch {
            print("Failed to load more posts: \(error)")
        }

        isLoading = false
    }

    func refresh() async {
        guard let profileId = currentProfileId else { return }

        do {
            let response = try await PostService.shared.getPosts(profileId: profileId, limit: 20, cursor: nil)
            posts = response.data
            nextCursor = response.pagination.nextCursor
            hasMore = response.pagination.hasMore
            errorMessage = nil
        } catch is CancellationError {
            // Ignore cancellation errors (e.g., from pull-to-refresh being released early)
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to refresh posts: \(error)")
        }
    }
}

#Preview {
    HomeFeedView()
        .environmentObject(CommunityContext())
        .environmentObject(ProfileContext())
        .environmentObject(AppModeContext())
}
