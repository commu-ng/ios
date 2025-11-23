import SwiftUI
import Combine

struct BookmarksView: View {
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = BookmarksViewModel()

    var body: some View {
        Group {
            if profileContext.currentProfile == nil {
                ContentUnavailableView(
                    NSLocalizedString("No Profile Selected", comment: ""),
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text(NSLocalizedString("Please select a profile.", comment: ""))
                )
            } else {
                BookmarksListView(viewModel: viewModel)
            }
        }
        .navigationTitle(NSLocalizedString("bookmarks.title", comment: ""))
        .task {
            if let profileId = profileContext.currentProfileId {
                await viewModel.loadBookmarks(profileId: profileId)
            }
        }
    }
}

struct BookmarksListView: View {
    @EnvironmentObject var profileContext: ProfileContext
    @ObservedObject var viewModel: BookmarksViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView()
                        .padding()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.posts.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("bookmarks.no_bookmarks", comment: ""),
                        systemImage: "bookmark",
                        description: Text(NSLocalizedString("bookmarks.empty_message", comment: ""))
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            NavigationLink(destination: AppPostDetailView(postId: post.id).environmentObject(profileContext)) {
                                PostCardPlaceholder(post: post)
                                    .environmentObject(profileContext)
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
    }
}

@MainActor
class BookmarksViewModel: ObservableObject {
    @Published var posts: [CommunityPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = false

    private var nextCursor: String?
    private var profileId: String?

    func loadBookmarks(profileId: String) async {
        guard !isLoading else { return }

        self.profileId = profileId
        isLoading = true
        errorMessage = nil

        do {
            let response = try await PostService.shared.getBookmarks(
                profileId: profileId,
                limit: 20,
                cursor: nil
            )
            posts = response.data
            nextCursor = response.pagination.nextCursor
            hasMore = response.pagination.hasMore
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load bookmarks: \(error)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore, let cursor = nextCursor, let profileId = profileId else { return }

        isLoading = true

        do {
            let response = try await PostService.shared.getBookmarks(
                profileId: profileId,
                limit: 20,
                cursor: cursor
            )
            posts.append(contentsOf: response.data)
            nextCursor = response.pagination.nextCursor
            hasMore = response.pagination.hasMore
        } catch {
            print("Failed to load more bookmarks: \(error)")
        }

        isLoading = false
    }

    func refresh() async {
        posts = []
        nextCursor = nil
        hasMore = false
        // Will be reloaded by task modifier
    }
}

#Preview {
    NavigationView {
        BookmarksView()
            .environmentObject(ProfileContext())
    }
}
