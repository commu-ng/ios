import SwiftUI
import Combine
import Kingfisher

struct ProfileDetailView: View {
    let username: String
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = ProfileDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.profile == nil {
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
                                await viewModel.loadProfile(username: username, profileId: profileContext.currentProfileId)
                            }
                        }
                    }
                    .padding()
                } else if let profile = viewModel.profile {
                    // Profile Header
                    VStack(spacing: 16) {
                        CachedCircularImage(url: profile.avatarURL, size: 100)

                        VStack(spacing: 8) {
                            Text(profile.name)
                                .font(.title)
                                .fontWeight(.bold)

                            Text("@\(profile.username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if let bio = profile.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            // Role badge
                            if profile.role != "member" {
                                Text(profile.role.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(profile.role == "admin" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                    .foregroundColor(profile.role == "admin" ? .red : .blue)
                                    .cornerRadius(8)
                            }

                            // Join date
                            if let createdDate = profile.createdDate {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                    Text(createdDate, format: .dateTime.month().day().year())
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }

                            // Send Message button (only show if not current user's profile)
                            if profile.id != profileContext.currentProfileId {
                                NavigationLink(destination: ChatView(otherProfileId: profile.id).environmentObject(profileContext)) {
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                        Text(NSLocalizedString("profile.send_message", comment: ""))
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .cornerRadius(20)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))

                    Divider()

                    // Posts section
                    if viewModel.posts.isEmpty && !viewModel.isLoadingPosts {
                        VStack(spacing: 12) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("profile.no_posts", comment: "No posts yet"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                                NavigationLink(destination: AppPostDetailView(postId: post.id).environmentObject(profileContext)) {
                                    ProfilePostCard(post: post)
                                }
                                .buttonStyle(PlainButtonStyle())

                                if index < viewModel.posts.count - 1 {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }

                            if viewModel.hasMorePosts {
                                ProgressView()
                                    .padding()
                                    .onAppear {
                                        Task {
                                            await viewModel.loadMorePosts(username: username, profileId: profileContext.currentProfileId)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.profile?.name ?? username)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh(username: username, profileId: profileContext.currentProfileId)
        }
        .task {
            await viewModel.loadProfile(username: username, profileId: profileContext.currentProfileId)
        }
    }
}

struct ProfilePostCard: View {
    let post: CommunityPost
    @EnvironmentObject var profileContext: ProfileContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Timestamp
            HStack {
                if let createdDate = post.createdDate {
                    Text(createdDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            }

            // Content
            if let attributedContent = try? AttributedString(markdown: post.content, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                Text(attributedContent)
                    .font(.body)
                    .lineLimit(4)
            } else {
                Text(post.content)
                    .font(.body)
                    .lineLimit(4)
            }

            // Images
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
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }

            // Stats
            HStack(spacing: 20) {
                Label("\(post.replyCount)", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !post.reactions.isEmpty {
                    let reactionCount = post.reactions.count
                    Label("\(reactionCount)", systemImage: "face.smiling")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

@MainActor
class ProfileDetailViewModel: ObservableObject {
    @Published var profile: AppProfile?
    @Published var posts: [CommunityPost] = []
    @Published var isLoading = false
    @Published var isLoadingPosts = false
    @Published var errorMessage: String?
    @Published var hasMorePosts = false

    private var nextCursor: String?

    func loadProfile(username: String, profileId: String?) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            profile = try await ProfileService.shared.getProfile(username: username, profileId: profileId)

            // Load posts
            isLoadingPosts = true
            let response = try await ProfileService.shared.getProfilePosts(username: username, profileId: profileId, limit: 20, cursor: nil)
            posts = response.data
            nextCursor = response.pagination.nextCursor
            hasMorePosts = response.pagination.hasMore
            isLoadingPosts = false
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load profile: \(error)")
        }

        isLoading = false
    }

    func loadMorePosts(username: String, profileId: String?) async {
        guard !isLoadingPosts, hasMorePosts, let cursor = nextCursor else { return }

        isLoadingPosts = true

        do {
            let response = try await ProfileService.shared.getProfilePosts(username: username, profileId: profileId, limit: 20, cursor: cursor)
            posts.append(contentsOf: response.data)
            nextCursor = response.pagination.nextCursor
            hasMorePosts = response.pagination.hasMore
        } catch {
            print("Failed to load more posts: \(error)")
        }

        isLoadingPosts = false
    }

    func refresh(username: String, profileId: String?) async {
        errorMessage = nil

        do {
            profile = try await ProfileService.shared.getProfile(username: username, profileId: profileId)
            let response = try await ProfileService.shared.getProfilePosts(username: username, profileId: profileId, limit: 20, cursor: nil)
            posts = response.data
            nextCursor = response.pagination.nextCursor
            hasMorePosts = response.pagination.hasMore
        } catch is CancellationError {
            // Ignore cancellation errors
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to refresh profile: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        ProfileDetailView(username: "testuser")
            .environmentObject(ProfileContext())
    }
}
