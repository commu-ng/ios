import SwiftUI
import Combine
import Kingfisher

struct AppPostDetailView: View {
    let postId: String
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = AppPostDetailViewModel()
    @State private var replyToPost: CommunityPost?
    @State private var showingEditSheet = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.post == nil {
                    ProgressView()
                        .padding()
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                        Button(NSLocalizedString("action.retry", comment: "")) {
                            Task {
                                await viewModel.loadPost(postId: postId, profileId: profileContext.currentProfileId)
                            }
                        }
                    }
                    .padding()
                } else if let post = viewModel.post {
                    VStack(spacing: 0) {
                        // Parent thread (if this is a reply)
                        if let parentPost = post.immediateParent {
                            NavigationLink(destination: AppPostDetailView(postId: parentPost.id).environmentObject(profileContext)) {
                                ParentPostCardView(post: parentPost)
                                    .padding()
                                    .background(Color(.systemGray6))
                            }
                            .buttonStyle(.plain)

                            Divider()
                        }

                        // Main post
                        PostCardView(
                            post: post,
                            isDetail: true,
                            depth: 0,
                            showEditButton: post.author.id == profileContext.currentProfileId && !post.announcement,
                            onEditTapped: {
                                showingEditSheet = true
                            },
                            onDeleted: {
                                dismiss()
                            }
                        )
                        .padding()

                        Divider()

                        // Reply button
                        Button {
                            replyToPost = post
                        } label: {
                            HStack {
                                Image(systemName: "arrowshape.turn.up.left")
                                Text(NSLocalizedString("composer.reply", comment: ""))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding()

                        // Replies section
                        if let replies = post.replies, !replies.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(String(format: NSLocalizedString("comment.replies_count", comment: ""), replies.count))
                                    .font(.headline)
                                    .padding(.horizontal)
                                    .padding(.top)

                                ForEach(replies) { reply in
                                    CollapsibleThreadView(
                                        reply: reply,
                                        depth: 0,
                                        currentProfileId: profileContext.currentProfileId,
                                        onReplyTapped: { replyPost in
                                            replyToPost = replyPost
                                        }
                                    )
                                }

                                if viewModel.hasMoreReplies {
                                    Button(NSLocalizedString("comment.load_more", comment: "")) {
                                        Task {
                                            await viewModel.loadMoreReplies(postId: postId, profileId: profileContext.currentProfileId)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("nav.post", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh(postId: postId, profileId: profileContext.currentProfileId)
        }
        .task {
            print("📄 AppPostDetailView loading post: \(postId)")
            await viewModel.loadPost(postId: postId, profileId: profileContext.currentProfileId)
        }
        .onAppear {
            print("📄 AppPostDetailView appeared for post: \(postId)")
        }
        .sheet(item: $replyToPost) { targetPost in
            PostComposerView(inReplyToPost: targetPost) { newReply in
                Task {
                    await viewModel.refresh(postId: postId, profileId: profileContext.currentProfileId)
                }
            }
            .environmentObject(profileContext)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let post = viewModel.post {
                EditPostView(post: post) {
                    Task {
                        await viewModel.refresh(postId: postId, profileId: profileContext.currentProfileId)
                    }
                }
                .environmentObject(profileContext)
            }
        }
    }
}

struct ParentPostCardView: View {
    let post: CommunityPostParent
    @EnvironmentObject var profileContext: ProfileContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink(destination: ProfileDetailView(username: post.author.username).environmentObject(profileContext)) {
                    CachedCircularImage(url: post.author.avatarURL, size: 40)
                }

                VStack(alignment: .leading, spacing: 4) {
                    NavigationLink(destination: ProfileDetailView(username: post.author.username).environmentObject(profileContext)) {
                        Text(post.author.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }

                    HStack(spacing: 4) {
                        Text("@\(post.author.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let createdDate = post.createdDate {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(createdDate, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }

            TappableMentionText(post.content, font: .body)
                .foregroundColor(.secondary)

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
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
    }
}

struct PostCardView: View {
    let post: CommunityPost
    let isDetail: Bool
    let depth: Int
    var showEditButton: Bool = false
    var onEditTapped: (() -> Void)? = nil
    var onDeleted: (() -> Void)? = nil
    var onReplyTapped: (() -> Void)? = nil
    @EnvironmentObject var profileContext: ProfileContext
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var contentRevealed = false

    private var isOwnPost: Bool {
        post.author.id == profileContext.currentProfileId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                NavigationLink(destination: ProfileDetailView(username: post.author.username).environmentObject(profileContext)) {
                    CachedCircularImage(url: post.author.avatarURL, size: isDetail ? 50 : 40)
                }

                VStack(alignment: .leading, spacing: 4) {
                    NavigationLink(destination: ProfileDetailView(username: post.author.username).environmentObject(profileContext)) {
                        Text(post.author.name)
                            .font(isDetail ? .headline : .subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }

                    HStack(spacing: 4) {
                        Text("@\(post.author.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let createdDate = post.createdDate {
                            Text("•")
                                .foregroundColor(.secondary)

                            if isDetail {
                                Text(createdDate, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                NavigationLink(destination: AppPostDetailView(postId: post.id).environmentObject(profileContext)) {
                                    Text(createdDate, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Show "edited" indicator if post was edited
                            if let updatedDate = post.updatedDate,
                               updatedDate.timeIntervalSince(createdDate) > 60 {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(NSLocalizedString("post.edited", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                if post.announcement {
                    Image(systemName: "megaphone.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }

                if post.isPinned == true {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }

                if showEditButton, let onEdit = onEditTapped {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                            .font(.caption)
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
                // Content
                if isDetail {
                    TappableMentionText(post.content, font: .body)
                } else {
                    NavigationLink(destination: AppPostDetailView(postId: post.id).environmentObject(profileContext)) {
                        TappableMentionText(post.content, font: .body)
                    }
                    .buttonStyle(.plain)
                }

                // Images
                if !post.images.isEmpty {
                    if post.images.count == 1, let image = post.images.first, let url = image.imageURL {
                        KFImage(url)
                            .placeholder {
                                Color.gray.opacity(0.2)
                            }
                            .fade(duration: 0.2)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                    } else {
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
            }

            // Reactions
            if !post.reactions.isEmpty {
                ReactionsSummaryView(postId: post.id, reactions: post.reactions, currentProfileId: profileContext.currentProfileId)
            }

            // Actions
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

                // Reply button (for threaded replies)
                if let onReply = onReplyTapped {
                    Button {
                        onReply()
                    } label: {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Bookmark
                if let profileId = profileContext.currentProfileId {
                    BookmarkButton(
                        postId: post.id,
                        isBookmarked: post.isBookmarked,
                        currentProfileId: profileId
                    )
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
                    }
                }
            }
        }
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
    }

    private func deletePost() async {
        guard let profileId = profileContext.currentProfileId else { return }

        isDeleting = true

        do {
            try await PostService.shared.deletePost(postId: post.id, profileId: profileId)
            onDeleted?()
        } catch {
            print("Failed to delete post: \(error)")
        }

        isDeleting = false
    }
}

struct CollapsibleThreadView: View {
    let reply: CommunityPost
    let depth: Int
    let currentProfileId: String?
    var onReplyTapped: ((CommunityPost) -> Void)?
    var onDeleted: (() -> Void)?

    @State private var isExpanded: Bool
    @State private var isDeleted = false

    init(reply: CommunityPost, depth: Int, currentProfileId: String?, onReplyTapped: ((CommunityPost) -> Void)? = nil, onDeleted: (() -> Void)? = nil) {
        self.reply = reply
        self.depth = depth
        self.currentProfileId = currentProfileId
        self.onReplyTapped = onReplyTapped
        self.onDeleted = onDeleted

        // Default expanded for all replies
        _isExpanded = State(initialValue: true)
    }

    private static func threadInvolvesUser(reply: CommunityPost, userId: String?) -> Bool {
        guard let userId = userId else { return false }

        // Check if current reply is from the user
        if reply.author.id == userId {
            return true
        }

        // Check nested replies
        if let children = reply.replies {
            for child in children {
                if threadInvolvesUser(reply: child, userId: userId) {
                    return true
                }
            }
        }

        return false
    }

    private var indentationWidth: CGFloat {
        CGFloat(min(depth, 5)) * 16
    }

    private var depthColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
        return colors[min(depth, colors.count - 1)].opacity(0.5)
    }

    private var hasChildren: Bool {
        guard let children = reply.replies else { return false }
        return !children.isEmpty
    }

    var body: some View {
        if !isDeleted {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    // Indentation bar
                    if depth > 0 {
                        Rectangle()
                            .fill(depthColor)
                            .frame(width: 3)
                            .padding(.leading, indentationWidth - 3)
                    }

                    // Reply content
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            PostCardView(
                                post: reply,
                                isDetail: false,
                                depth: depth,
                                onDeleted: {
                                    withAnimation {
                                        isDeleted = true
                                    }
                                    onDeleted?()
                                },
                                onReplyTapped: onReplyTapped != nil ? { onReplyTapped?(reply) } : nil
                            )
                            .padding()

                            Spacer()

                            // Collapse/expand button for threads with children
                            if hasChildren {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded.toggle()
                                    }
                                } label: {
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(8)
                                }
                            }
                        }

                        Divider()
                    }
                }

                // Nested replies (if expanded)
                if isExpanded, let children = reply.replies {
                    ForEach(children) { child in
                        CollapsibleThreadView(
                            reply: child,
                            depth: depth + 1,
                            currentProfileId: currentProfileId,
                            onReplyTapped: onReplyTapped
                        )
                    }
                } else if hasChildren && !isExpanded {
                    // Show collapsed indicator
                    HStack(spacing: 0) {
                        if depth > 0 {
                            Rectangle()
                                .fill(depthColor)
                                .frame(width: 3)
                                .padding(.leading, indentationWidth - 3)
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "ellipsis")
                                Text(String(format: NSLocalizedString("comment.collapsed_replies", comment: ""), reply.replies?.count ?? 0))
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }

                    Divider()
                        .padding(.leading, indentationWidth)
                }
            }
        }
    }
}

struct ThreadedReplyView: View {
    let reply: CommunityPost
    let depth: Int

    private var indentationWidth: CGFloat {
        CGFloat(min(depth, 5)) * 20
    }

    private var depthColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
        return colors[min(depth, colors.count - 1)].opacity(0.3)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Indentation bar
            if depth > 0 {
                Rectangle()
                    .fill(depthColor)
                    .frame(width: 3)
                    .padding(.leading, indentationWidth - 3)
            }

            // Reply content
            VStack(alignment: .leading, spacing: 0) {
                PostCardView(post: reply, isDetail: false, depth: depth)
                    .padding()

                Divider()
            }
        }
    }
}

struct ReactionsSummaryView: View {
    let postId: String
    let reactions: [CommunityPostReaction]
    let currentProfileId: String?
    @State private var isProcessing = false
    @State private var localReactions: [CommunityPostReaction]

    init(postId: String, reactions: [CommunityPostReaction], currentProfileId: String?) {
        self.postId = postId
        self.reactions = reactions
        self.currentProfileId = currentProfileId
        self._localReactions = State(initialValue: reactions)
    }

    private var groupedReactions: [(emoji: String, count: Int, hasUserReacted: Bool)] {
        let grouped = Dictionary(grouping: localReactions, by: { $0.emoji })
        return grouped.map { emoji, users in
            let hasUserReacted = currentProfileId != nil && users.contains { $0.profileId == currentProfileId }
            return (emoji: emoji, count: users.count, hasUserReacted: hasUserReacted)
        }
        .sorted { $0.count > $1.count }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(groupedReactions, id: \.emoji) { reaction in
                    Button {
                        guard let profileId = currentProfileId else { return }
                        Task {
                            await toggleReaction(emoji: reaction.emoji, hasUserReacted: reaction.hasUserReacted, profileId: profileId)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(reaction.emoji)
                            Text("\(reaction.count)")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(reaction.hasUserReacted ? Color.blue.opacity(0.2) : Color(.systemGray5))
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing || currentProfileId == nil)
                }
            }
        }
    }

    private func toggleReaction(emoji: String, hasUserReacted: Bool, profileId: String) async {
        isProcessing = true

        if hasUserReacted {
            // Store for potential restoration
            let removedReactions = localReactions.filter { $0.emoji == emoji && $0.profileId == profileId }

            // Optimistic update
            localReactions.removeAll { $0.emoji == emoji && $0.profileId == profileId }

            do {
                try await PostService.shared.removeReaction(
                    postId: postId,
                    emoji: emoji,
                    profileId: profileId
                )
            } catch {
                // Revert on error
                localReactions.append(contentsOf: removedReactions)
                print("Failed to remove reaction: \(error)")
            }
        } else {
            // Optimistic update
            let tempUser = CommunityPostReactionUser(id: profileId, username: "", name: "")
            let newReaction = CommunityPostReaction(emoji: emoji, user: tempUser)
            localReactions.append(newReaction)

            do {
                _ = try await PostService.shared.addReaction(
                    postId: postId,
                    emoji: emoji,
                    profileId: profileId
                )
            } catch {
                // Revert on error
                localReactions.removeAll { $0.emoji == emoji && $0.profileId == profileId }
                print("Failed to add reaction: \(error)")
            }
        }

        isProcessing = false
    }
}

@MainActor
class AppPostDetailViewModel: ObservableObject {
    @Published var post: CommunityPost?
    @Published var replies: [CommunityPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMoreReplies = false

    private var nextCursor: String?

    func loadPost(postId: String, profileId: String?) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            post = try await PostService.shared.getPost(postId: postId, profileId: profileId)
            // Note: Replies are part of nested structure in some APIs
            // For now, this is a simplified version
            // TODO: Load replies separately if needed
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load post: \(error)")
        }

        isLoading = false
    }

    func loadMoreReplies(postId: String, profileId: String?) async {
        // TODO: Implement reply pagination when API supports it
    }

    func refresh(postId: String, profileId: String?) async {
        // Don't set post = nil to avoid showing loading/error state immediately
        errorMessage = nil

        do {
            post = try await PostService.shared.getPost(postId: postId, profileId: profileId)
            replies = []
            nextCursor = nil
            hasMoreReplies = false
        } catch is CancellationError {
            // Ignore cancellation errors (e.g., from pull-to-refresh being released early)
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to refresh post: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        AppPostDetailView(postId: "test")
            .environmentObject(ProfileContext())
    }
}
