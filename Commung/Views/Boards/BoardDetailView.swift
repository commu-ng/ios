import SwiftUI

struct BoardDetailView: View {
    let board: Board
    @EnvironmentObject var boardsViewModel: BoardsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingCreatePost = false

    var body: some View {
        Group {
            if boardsViewModel.posts.isEmpty && (boardsViewModel.isLoadingBoardContent || boardsViewModel.isLoadingHashtags || boardsViewModel.isLoadingPosts || boardsViewModel.selectedBoard == nil) {
                ProgressView(NSLocalizedString("loading.board", comment: ""))
            } else if let error = boardsViewModel.postsError {
                VStack {
                    Text(NSLocalizedString("error.loading_posts", comment: ""))
                        .font(.title2)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                    Button(NSLocalizedString("action.retry", comment: "")) {
                        Task {
                            await boardsViewModel.loadPosts(boardSlug: board.slug, refresh: true)
                        }
                    }
                }
            } else {
                List {
                        if !boardsViewModel.boardHashtags.isEmpty {
                            Section {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("hashtag.popular", comment: ""))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    FlowLayout(spacing: 6) {
                                        ForEach(boardsViewModel.boardHashtags, id: \.self) { hashtag in
                                            let isSelected = boardsViewModel.selectedHashtags.contains(hashtag)
                                            Text("#\(hashtag)")
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(isSelected ? Color.blue.opacity(0.2) : Color.blue.opacity(0.05))
                                                .foregroundColor(.blue)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                                )
                                                .cornerRadius(4)
                                                .onTapGesture {
                                                    var newHashtags = boardsViewModel.selectedHashtags
                                                    if isSelected {
                                                        newHashtags.removeAll { $0 == hashtag }
                                                    } else {
                                                        newHashtags.append(hashtag)
                                                    }
                                                    boardsViewModel.setHashtags(newHashtags)
                                                }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(Color.blue.opacity(0.03))
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }

                        if !boardsViewModel.selectedHashtags.isEmpty {
                            Section {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(NSLocalizedString("hashtag.filters", comment: ""))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)

                                        Spacer()

                                        Button(NSLocalizedString("action.clear_all", comment: "")) {
                                            boardsViewModel.setHashtags([])
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    }

                                    FlowLayout(spacing: 6) {
                                        ForEach(boardsViewModel.selectedHashtags, id: \.self) { hashtag in
                                            HStack(spacing: 4) {
                                                Text("#\(hashtag)")
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption)
                                            }
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.2))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                            .onTapGesture {
                                                var newHashtags = boardsViewModel.selectedHashtags
                                                newHashtags.removeAll { $0 == hashtag }
                                                boardsViewModel.setHashtags(newHashtags)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(Color.gray.opacity(0.1))
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }

                        Section {
                            if boardsViewModel.posts.isEmpty {
                                HStack {
                                    Spacer()
                                    Text(NSLocalizedString("empty.no_posts", comment: ""))
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 40)
                                    Spacer()
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                            } else {
                                ForEach(boardsViewModel.posts) { post in
                                    ZStack {
                                        NavigationLink(destination: PostDetailView(post: post, board: board).environmentObject(boardsViewModel)) {
                                            EmptyView()
                                        }
                                        .opacity(0)

                                        BoardPostCardView(post: post)
                                            .environmentObject(boardsViewModel)
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .onAppear {
                                        if post.id == boardsViewModel.posts.last?.id {
                                            Task {
                                                await boardsViewModel.loadMorePosts()
                                            }
                                        }
                                    }
                                }

                                if boardsViewModel.hasMorePosts {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
            }
        }
        .navigationTitle(boardsViewModel.selectedBoard?.name ?? board.name)
        .toolbar {
            if authViewModel.isAuthenticated {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreatePost = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView(boardSlug: board.slug)
                .environmentObject(boardsViewModel)
        }
        .task {
            boardsViewModel.selectBoard(board)
        }
        .refreshable {
            await boardsViewModel.loadPosts(boardSlug: board.slug, refresh: true)
        }
    }
}

struct BoardPostCardView: View {
    let post: Post
    @EnvironmentObject var boardsViewModel: BoardsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                CachedCircularImage(
                    url: post.author.avatarImageURL,
                    size: 24
                )
                .frame(width: 24, height: 24)

                Text(post.author.loginName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatRelativeTime(post.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(height: 24)

            if let image = post.image {
                GeometryReader { geometry in
                    AsyncImage(url: URL(string: image.url)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: geometry.size.width, height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: 200)
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: geometry.size.width, height: 200)
                        @unknown default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: geometry.size.width, height: 200)
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 200)
            }

            Text(post.title)
                .font(.headline)
                .lineLimit(1)
                .frame(height: 22, alignment: .topLeading)

            if !post.hashtags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(post.hashtags) { hashtag in
                        let isSelected = boardsViewModel.selectedHashtags.contains(hashtag.tag)
                        Text("#\(hashtag.tag)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSelected ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                            .onTapGesture {
                                var newHashtags = boardsViewModel.selectedHashtags
                                if isSelected {
                                    newHashtags.removeAll { $0 == hashtag.tag }
                                } else {
                                    newHashtags.append(hashtag.tag)
                                }
                                boardsViewModel.setHashtags(newHashtags)
                            }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
