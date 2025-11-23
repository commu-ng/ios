import SwiftUI
import Combine

struct SearchView: View {
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if profileContext.currentProfile == nil {
                    ContentUnavailableView(
                        NSLocalizedString("No Profile Selected", comment: ""),
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text(NSLocalizedString("Please select a profile.", comment: ""))
                    )
                } else {
                    SearchResultsView(viewModel: viewModel, searchText: $searchText)
                }
            }
            .navigationTitle(NSLocalizedString("search.title", comment: ""))
        }
        .searchable(text: $searchText, prompt: NSLocalizedString("search.prompt", comment: ""))
        .onChange(of: searchText) { oldValue, newValue in
            Task {
                await viewModel.search(query: newValue, profileId: profileContext.currentProfileId)
            }
        }
    }
}

struct SearchResultsView: View {
    @EnvironmentObject var profileContext: ProfileContext
    @ObservedObject var viewModel: SearchViewModel
    @Binding var searchText: String

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 16) {
                    if searchText.isEmpty {
                        ContentUnavailableView(
                            NSLocalizedString("search.posts", comment: ""),
                            systemImage: "magnifyingglass",
                            description: Text(NSLocalizedString("search.min_chars", comment: ""))
                        )
                    } else if searchText.count < 2 {
                        Text(NSLocalizedString("search.min_chars_short", comment: ""))
                            .foregroundColor(.secondary)
                            .padding()
                    } else if viewModel.isLoading && viewModel.posts.isEmpty {
                        ProgressView()
                            .padding()
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                        .padding()
                    } else if viewModel.posts.isEmpty {
                        ContentUnavailableView(
                            NSLocalizedString("search.no_results", comment: ""),
                            systemImage: "magnifyingglass",
                            description: Text(String(format: NSLocalizedString("search.no_posts_matching", comment: ""), searchText))
                        )
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.posts) { post in
                                NavigationLink(destination: AppPostDetailView(postId: post.id).environmentObject(profileContext)) {
                                    PostCardPlaceholder(post: post)
                                        .environmentObject(profileContext)
                                }
                                .buttonStyle(PlainButtonStyle())
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
                        .padding()
                    }
                }
            }
        }
    }
}

@MainActor
class SearchViewModel: ObservableObject {
    @Published var posts: [CommunityPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = false

    private var nextCursor: String?
    private var currentQuery: String?
    private var profileId: String?
    private var searchTask: Task<Void, Never>?

    func search(query: String, profileId: String?) async {
        // Cancel previous search
        searchTask?.cancel()

        guard query.count >= 2, let profileId = profileId else {
            posts = []
            hasMore = false
            return
        }

        // Debounce: wait 500ms
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else { return }

            await performSearch(query: query, profileId: profileId)
        }
    }

    private func performSearch(query: String, profileId: String) async {
        guard !isLoading else { return }

        self.currentQuery = query
        self.profileId = profileId
        isLoading = true
        errorMessage = nil

        do {
            let response = try await PostService.shared.searchPosts(
                query: query,
                profileId: profileId,
                limit: 20,
                cursor: nil
            )
            posts = response.data
            nextCursor = response.pagination.nextCursor
            hasMore = response.pagination.hasMore
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to search posts: \(error)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore, let cursor = nextCursor,
              let query = currentQuery, let profileId = profileId else { return }

        isLoading = true

        do {
            let response = try await PostService.shared.searchPosts(
                query: query,
                profileId: profileId,
                limit: 20,
                cursor: cursor
            )
            posts.append(contentsOf: response.data)
            nextCursor = response.pagination.nextCursor
            hasMore = response.pagination.hasMore
        } catch {
            print("Failed to load more search results: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    SearchView()
        .environmentObject(ProfileContext())
}
