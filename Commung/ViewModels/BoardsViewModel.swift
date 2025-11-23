import Foundation
import Combine

class BoardsViewModel: ObservableObject {
    @Published var boards: [Board] = []
    @Published var isLoadingBoards = false
    @Published var boardsError: String?
    @Published var boardsListLoaded = false  // Track if full boards list has been loaded

    @Published var selectedBoard: Board?
    @Published var posts: [Post] = []
    @Published var isLoadingPosts = false
    @Published var postsError: String?
    @Published var nextCursor: String?
    @Published var hasMorePosts = false

    @Published var selectedPost: Post?

    @Published var selectedHashtags: [String] = []

    @Published var boardHashtags: [String] = []
    @Published var isLoadingHashtags = false
    @Published var hashtagsError: String?

    // Consolidated loading state for initial board content (board + hashtags + posts)
    @Published var isLoadingBoardContent = false

    @Published var replies: [BoardPostReply] = []
    @Published var isLoadingReplies = false
    @Published var repliesError: String?
    @Published var repliesNextCursor: String?
    @Published var hasMoreReplies = false
    @Published var replyingTo: BoardPostReply?
    @Published var isCreatingReply = false

    func clearReplies() {
        replies = []
        repliesNextCursor = nil
        hasMoreReplies = false
        replyingTo = nil
    }

    func setReplyingTo(_ reply: BoardPostReply?) {
        replyingTo = reply
    }

    func loadBoards(force: Bool = false) async {
        // Prevent concurrent loads and avoid reloading if already loaded (unless forced)
        guard !isLoadingBoards && (force || !boardsListLoaded) else { return }

        isLoadingBoards = true
        boardsError = nil

        do {
            boards = try await BoardService.shared.getBoards()
            boardsListLoaded = true
        } catch {
            if !Task.isCancelled {
                boardsError = error.localizedDescription
            }
        }

        isLoadingBoards = false
    }

    func loadBoard(boardSlug: String) async {
        isLoadingBoardContent = true
        isLoadingBoards = true
        boardsError = nil

        // Clear posts and hashtags immediately to prevent showing old board's data
        posts = []
        nextCursor = nil
        hasMorePosts = false
        boardHashtags = []
        selectedHashtags = []

        do {
            let board = try await BoardService.shared.getBoard(boardSlug: boardSlug)
            boards = [board]
            // Force update selectedBoard even if id matches (in case we have placeholder data)
            selectedBoard = board

            // Load hashtags and posts in parallel for better performance
            async let hashtagsTask: Void = loadBoardHashtags(boardSlug: board.slug)
            async let postsTask: Void = loadPosts(boardSlug: board.slug, refresh: true)

            _ = await hashtagsTask
            _ = await postsTask
        } catch {
            if !Task.isCancelled {
                boardsError = error.localizedDescription
            }
        }

        isLoadingBoards = false
        isLoadingBoardContent = false
    }

    func selectBoard(_ board: Board) {
        // Avoid re-selecting the same board
        if selectedBoard?.id == board.id {
            return
        }

        selectedBoard = board
        // Clear posts and hashtags immediately to prevent showing old board's data
        posts = []
        nextCursor = nil
        hasMorePosts = false
        boardHashtags = []
        selectedHashtags = []
        Task {
            await loadBoardHashtags(boardSlug: board.slug)
            await loadPosts(boardSlug: board.slug, refresh: true)
        }
    }

    func loadBoardHashtags(boardSlug: String) async {
        // Prevent concurrent loads
        guard !isLoadingHashtags else { return }

        isLoadingHashtags = true
        hashtagsError = nil

        do {
            boardHashtags = try await BoardService.shared.getBoardHashtags(boardSlug: boardSlug)
        } catch {
            if !Task.isCancelled {
                hashtagsError = error.localizedDescription
            }
        }

        isLoadingHashtags = false
    }

	func loadPosts(boardSlug: String, refresh: Bool = false) async {
		// Prevent concurrent loads
		guard !isLoadingPosts else { return }

		isLoadingPosts = true
		postsError = nil

		do {
			let hashtags = selectedHashtags.isEmpty ? nil : selectedHashtags
			let response = try await BoardService.shared.getPosts(
				boardSlug: boardSlug,
				hashtags: hashtags,
				cursor: refresh ? nil : nextCursor
			)

			if refresh {
				posts = response.posts
				nextCursor = response.nextCursor
				hasMorePosts = response.nextCursor != nil
			} else {
				posts.append(contentsOf: response.posts)
				nextCursor = response.nextCursor
				hasMorePosts = response.nextCursor != nil
			}
		} catch {
			if !Task.isCancelled {
				postsError = error.localizedDescription
			}
		}

		isLoadingPosts = false
	}

    func loadMorePosts() async {
        guard let board = selectedBoard, hasMorePosts, !isLoadingPosts else { return }
        await loadPosts(boardSlug: board.slug, refresh: false)
    }

    func setHashtags(_ hashtags: [String]) {
        selectedHashtags = hashtags
        guard let board = selectedBoard else { return }
        Task {
            await loadPosts(boardSlug: board.slug, refresh: true)
        }
    }

    func loadReplies(boardSlug: String, postId: String, refresh: Bool = false) async {
        if replies.isEmpty || !refresh {
            isLoadingReplies = true
        }
        repliesError = nil

        do {
            let response = try await BoardService.shared.getReplies(
                boardSlug: boardSlug,
                postId: postId,
                cursor: refresh ? nil : repliesNextCursor
            )

            if refresh {
                replies = response.replies
                repliesNextCursor = response.nextCursor
                hasMoreReplies = response.hasMore
            } else {
                replies.append(contentsOf: response.replies)
                repliesNextCursor = response.nextCursor
                hasMoreReplies = response.hasMore
            }
        } catch {
            if !Task.isCancelled {
                repliesError = error.localizedDescription
            }
        }

        isLoadingReplies = false
    }

    func loadMoreReplies() async {
        guard let post = selectedPost,
              let board = selectedBoard,
              hasMoreReplies,
              !isLoadingReplies else { return }
        await loadReplies(boardSlug: board.slug, postId: post.id, refresh: false)
    }

    func createReply(boardSlug: String, postId: String, content: String, inReplyToId: String? = nil) async {
        isCreatingReply = true
        repliesError = nil

        do {
            _ = try await BoardService.shared.createReply(
                boardSlug: boardSlug,
                postId: postId,
                content: content,
                inReplyToId: inReplyToId
            )
            // Refresh replies to show the new reply in the correct position
            await loadReplies(boardSlug: boardSlug, postId: postId, refresh: true)
        } catch {
            if !Task.isCancelled {
                repliesError = error.localizedDescription
            }
        }

        isCreatingReply = false
    }

    func updateReply(boardSlug: String, postId: String, replyId: String, content: String) async {
        do {
            _ = try await BoardService.shared.updateReply(
                boardSlug: boardSlug,
                postId: postId,
                replyId: replyId,
                content: content
            )
            // Refresh replies to show the updated reply
            await loadReplies(boardSlug: boardSlug, postId: postId, refresh: true)
        } catch {
            if !Task.isCancelled {
                repliesError = error.localizedDescription
            }
        }
    }

    func deleteReply(boardSlug: String, postId: String, replyId: String) async {
        do {
            try await BoardService.shared.deleteReply(
                boardSlug: boardSlug,
                postId: postId,
                replyId: replyId
            )
            // Refresh replies to remove the deleted reply
            await loadReplies(boardSlug: boardSlug, postId: postId, refresh: true)
        } catch {
            if !Task.isCancelled {
                repliesError = error.localizedDescription
            }
        }
    }

    func uploadImage(imageData: Data, fileName: String) async throws -> ImageUploadResponse {
        return try await BoardService.shared.uploadImage(imageData: imageData, fileName: fileName)
    }

    func createPost(
        boardSlug: String,
        title: String,
        content: String,
        imageId: String? = nil,
        hashtags: [String]? = nil
    ) async {
        isLoadingPosts = true
        postsError = nil

        do {
            _ = try await BoardService.shared.createPost(
                boardSlug: boardSlug,
                title: title,
                content: content,
                imageId: imageId,
                hashtags: hashtags
            )
            // Refresh posts to show the new post
            await loadPosts(boardSlug: boardSlug, refresh: true)
        } catch {
            if !Task.isCancelled {
                postsError = error.localizedDescription
            }
        }

        isLoadingPosts = false
    }
}
