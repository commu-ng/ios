import SwiftUI

struct PostDetailView: View {
    let post: Post
    let board: Board
    @EnvironmentObject var boardsViewModel: BoardsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showImageZoom = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showReportSheet = false
    @State private var reportReason = ""
    @State private var isReporting = false

    private var isAuthor: Bool {
        authViewModel.currentUser?.id == post.author.id
    }

    private var isLoggedIn: Bool {
        authViewModel.currentUser != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Post header
                    HStack(spacing: 8) {
                        CachedCircularImage(
                            url: post.author.avatarImageURL,
                            size: 32
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.author.loginName)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(formatFullDate(post.createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // Post image
                    if let image = post.image {
                        AsyncImage(url: URL(string: image.url)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(maxWidth: .infinity)
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .onTapGesture {
                            showImageZoom = true
                        }
                    }

                    // Post title
                    Text(post.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    // Post content (Markdown rendered)
                    if let content = post.content {
                        if let attributedString = try? AttributedString(
                            markdown: content,
                            options: AttributedString.MarkdownParsingOptions(
                                interpretedSyntax: .inlineOnlyPreservingWhitespace
                            )
                        ) {
                            Text(attributedString)
                                .font(.body)
                                .padding(.horizontal)
                        } else {
                            Text(content)
                                .font(.body)
                                .padding(.horizontal)
                        }
                    }

                    // Hashtags
                    if !post.hashtags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(post.hashtags) { hashtag in
                                Text("#\(hashtag.tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Show replies if board allows comments
                    if board.allowComments {
                        Divider()
                            .padding(.top)

                        RepliesListView(
                            boardSlug: board.slug,
                            postId: post.id,
                            viewModel: boardsViewModel
                        )
                    }
                }
            }

            // Reply composition bar - always visible at bottom
            if board.allowComments {
                ReplyCompositionBar(
                    boardSlug: board.slug,
                    postId: post.id,
                    viewModel: boardsViewModel
                )
            }
        }
    .navigationTitle(NSLocalizedString("nav.post", comment: ""))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        if isAuthor && !isDeleting {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        if !isAuthor && isLoggedIn {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showReportSheet = true
                } label: {
                    Image(systemName: "flag")
                }
            }
        }
    }
    .alert(NSLocalizedString("post.delete_confirm_title", comment: ""), isPresented: $showDeleteConfirmation) {
        Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) { }
        Button(NSLocalizedString("post.delete", comment: ""), role: .destructive) {
            deletePost()
        }
    } message: {
        Text(NSLocalizedString("post.delete_confirm_message", comment: ""))
    }
    .fullScreenCover(isPresented: $showImageZoom) {
        if let image = post.image {
            ImageZoomView(imageUrl: image.url, isPresented: $showImageZoom)
        }
    }
    .sheet(isPresented: $showReportSheet) {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("report.description", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $reportReason)
                    .frame(minHeight: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )

                Text("\(reportReason.count)/2000")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer()
            }
            .padding()
            .navigationTitle(NSLocalizedString("report.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        showReportSheet = false
                        reportReason = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("action.submit", comment: "")) {
                        Task {
                            await submitReport()
                        }
                    }
                    .disabled(reportReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isReporting)
                }
            }
        }
        .presentationDetents([.medium])
    }
    }

    private func submitReport() async {
        isReporting = true

        do {
            try await BoardService.shared.reportPost(
                boardSlug: board.slug,
                postId: post.id,
                reason: reportReason.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            showReportSheet = false
            reportReason = ""
        } catch {
            print("Failed to report post: \(error)")
        }

        isReporting = false
    }

    private func deletePost() {
        isDeleting = true
        Task {
            do {
                try await BoardService.shared.deletePost(
                    boardSlug: board.slug,
                    postId: post.id
                )
                // Refresh the posts list to remove the deleted post
                await boardsViewModel.loadPosts(boardSlug: board.slug, refresh: true)
                // Navigate back after successful deletion
                dismiss()
            } catch {
                // Handle error
                isDeleting = false
            }
        }
    }
}
