import SwiftUI

// List of replies - no ScrollView, meant to be embedded in parent ScrollView
struct RepliesListView: View {
    let boardSlug: String
    let postId: String
    @ObservedObject var viewModel: BoardsViewModel

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoadingReplies && viewModel.replies.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if let error = viewModel.repliesError {
                Text(String(format: NSLocalizedString("error.generic", comment: ""), error))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            } else if viewModel.replies.isEmpty {
                Text(NSLocalizedString("empty.no_comments", comment: ""))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(viewModel.replies) { reply in
                    ReplyRowView(
                        reply: reply,
                        depth: 0,
                        boardSlug: boardSlug,
                        postId: postId,
                        viewModel: viewModel
                    )
                }

                if viewModel.hasMoreReplies {
                    Button(NSLocalizedString("comment.load_more", comment: "")) {
                        Task {
                            await viewModel.loadMoreReplies()
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.horizontal)
        .onAppear {
            // Clear old replies immediately to prevent showing stale data
            viewModel.clearReplies()
            Task {
                await viewModel.loadReplies(boardSlug: boardSlug, postId: postId, refresh: true)
            }
        }
    }
}

// Reply composition bar - fixed at bottom of screen
struct ReplyCompositionBar: View {
    let boardSlug: String
    let postId: String
    @ObservedObject var viewModel: BoardsViewModel

    @State private var replyText: String = ""
    @State private var replyingTo: BoardPostReply?

    var body: some View {
        VStack(spacing: 0) {
            // Show replying indicator if replying to someone
            if let replyingTo = replyingTo {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: NSLocalizedString("comment.replying_to", comment: ""), replyingTo.author.loginName))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(replyingTo.content)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: {
                        self.replyingTo = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
            }

            Divider()

            HStack(spacing: 12) {
                TextField(NSLocalizedString("comment.placeholder", comment: ""), text: $replyText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(viewModel.isCreatingReply)

                if viewModel.isCreatingReply {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else {
                    Button(NSLocalizedString("comment.post_button", comment: "")) {
                        Task {
                            await viewModel.createReply(
                                boardSlug: boardSlug,
                                postId: postId,
                                content: replyText,
                                inReplyToId: replyingTo?.id
                            )
                            if viewModel.repliesError == nil {
                                replyText = ""
                                self.replyingTo = nil
                            }
                        }
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .onReceive(viewModel.$replyingTo) { newReplyingTo in
            self.replyingTo = newReplyingTo
        }
    }
}

struct ReplyRowView: View {
    let reply: BoardPostReply
    let depth: Int
    let boardSlug: String
    let postId: String
    @ObservedObject var viewModel: BoardsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showDeleteConfirmation = false

    // Visual depth is capped at 5
    private var visualDepth: Int {
        min(depth, 5)
    }

    private var indentationPadding: CGFloat {
        CGFloat(visualDepth) * 20
    }

    private var isAuthor: Bool {
        authViewModel.currentUser?.id == reply.author.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                // Indentation spacer
                if visualDepth > 0 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .padding(.leading, indentationPadding - 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Author and metadata
                    HStack {
                        Text("@\(reply.author.loginName)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(formatDate(reply.createdAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    // Content
                    Text(reply.content)
                        .font(.body)

                    // Action buttons
                    HStack(spacing: 12) {
                        // Reply button
                        Button(action: {
                            viewModel.setReplyingTo(reply)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.caption2)
                                Text(NSLocalizedString("comment.reply_button", comment: ""))
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }

                        // Delete button (only for author)
                        if isAuthor {
                            Button(role: .destructive, action: {
                                showDeleteConfirmation = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.caption2)
                                    Text(NSLocalizedString("post.delete", comment: ""))
                                        .font(.caption)
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(.leading, visualDepth > 0 ? 8 : 0)
            }

            // Nested replies
            if let nestedReplies = reply.replies, !nestedReplies.isEmpty {
                ForEach(nestedReplies) { nestedReply in
                    ReplyRowView(
                        reply: nestedReply,
                        depth: depth + 1,
                        boardSlug: boardSlug,
                        postId: postId,
                        viewModel: viewModel
                    )
                }
            }
        }
        .padding(.vertical, 4)
        .alert(NSLocalizedString("comment.delete_confirm_title", comment: ""), isPresented: $showDeleteConfirmation) {
            Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("post.delete", comment: ""), role: .destructive) {
                deleteReply()
            }
        } message: {
            Text(NSLocalizedString("comment.delete_confirm_message", comment: ""))
        }
    }

    private func deleteReply() {
        Task {
            await viewModel.deleteReply(
                boardSlug: boardSlug,
                postId: postId,
                replyId: reply.id
            )
        }
    }

    private func formatDate(_ dateString: String) -> String {
        // Simple date formatting - can be improved
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .short
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return dateString
    }
}
