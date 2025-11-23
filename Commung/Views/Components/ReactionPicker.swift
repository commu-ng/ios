import SwiftUI

struct ReactionPicker: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let commonEmojis = [
        "❤️", "👍", "👎", "😂", "😮", "😢", "🎉", "🔥",
        "👏", "💯", "🙏", "✨", "💪", "👀", "🤔", "😍",
        "🚀", "⭐", "💡", "✅", "❌", "🤝", "🎯", "💬"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("reaction.add", comment: ""))
                .font(.headline)
                .padding(.top)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                ForEach(commonEmojis, id: \.self) { emoji in
                    Button {
                        onSelect(emoji)
                        dismiss()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 50, height: 50)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct ReactionButton: View {
    let postId: String
    let currentReactions: [CommunityPostReaction]
    let currentProfileId: String
    @State private var showingPicker = false
    @State private var isProcessing = false
    @State private var localReactions: [CommunityPostReaction]

    init(postId: String, currentReactions: [CommunityPostReaction], currentProfileId: String) {
        self.postId = postId
        self.currentReactions = currentReactions
        self.currentProfileId = currentProfileId
        self._localReactions = State(initialValue: currentReactions)
    }

    private var userReactions: [CommunityPostReaction] {
        localReactions.filter { $0.profileId == currentProfileId }
    }

    private var hasUserReacted: Bool {
        !userReactions.isEmpty
    }

    var body: some View {
        HStack(spacing: 4) {
            // Show user's reactions as tappable chips to remove
            ForEach(userReactions, id: \.id) { reaction in
                Button {
                    Task {
                        await removeReaction(emoji: reaction.emoji)
                    }
                } label: {
                    Text(reaction.emoji)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
            }

            // Always show + button to add more reactions
            Button {
                showingPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.caption)

                    if !localReactions.isEmpty && userReactions.isEmpty {
                        Text("\(localReactions.count)")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
            .disabled(isProcessing)
        }
        .sheet(isPresented: $showingPicker) {
            ReactionPicker { emoji in
                Task {
                    await addReaction(emoji: emoji)
                }
            }
        }
    }

    private func addReaction(emoji: String) async {
        isProcessing = true

        // Optimistic update
        let tempUser = CommunityPostReactionUser(id: currentProfileId, username: "", name: "")
        let newReaction = CommunityPostReaction(emoji: emoji, user: tempUser)
        localReactions.append(newReaction)

        do {
            _ = try await PostService.shared.addReaction(
                postId: postId,
                emoji: emoji,
                profileId: currentProfileId
            )
        } catch {
            // Revert on error
            localReactions.removeAll { $0.profileId == currentProfileId && $0.emoji == emoji }
            print("Failed to add reaction: \(error)")
        }

        isProcessing = false
    }

    private func removeReaction(emoji: String) async {
        guard let reaction = userReactions.first(where: { $0.emoji == emoji }) else { return }

        isProcessing = true

        // Store for potential restoration
        let removedReaction = reaction

        // Optimistic update
        localReactions.removeAll { $0.profileId == currentProfileId && $0.emoji == emoji }

        do {
            try await PostService.shared.removeReaction(
                postId: postId,
                emoji: emoji,
                profileId: currentProfileId
            )
        } catch {
            // Revert on error
            localReactions.append(removedReaction)
            print("Failed to remove reaction: \(error)")
        }

        isProcessing = false
    }
}

struct BookmarkButton: View {
    let postId: String
    let isBookmarked: Bool
    let currentProfileId: String
    @State private var isProcessing = false
    @State private var localIsBookmarked: Bool

    init(postId: String, isBookmarked: Bool, currentProfileId: String) {
        self.postId = postId
        self.isBookmarked = isBookmarked
        self.currentProfileId = currentProfileId
        self._localIsBookmarked = State(initialValue: isBookmarked)
    }

    var body: some View {
        Button {
            Task {
                await toggleBookmark()
            }
        } label: {
            Image(systemName: localIsBookmarked ? "bookmark.fill" : "bookmark")
                .font(.body)
                .foregroundColor(localIsBookmarked ? .blue : .secondary)
        }
        .disabled(isProcessing)
    }

    private func toggleBookmark() async {
        isProcessing = true

        // Optimistic update
        localIsBookmarked.toggle()

        do {
            if localIsBookmarked {
                _ = try await PostService.shared.bookmarkPost(
                    postId: postId,
                    profileId: currentProfileId
                )
            } else {
                try await PostService.shared.unbookmarkPost(
                    postId: postId,
                    profileId: currentProfileId
                )
            }
        } catch {
            // Revert on error
            localIsBookmarked.toggle()
            print("Failed to toggle bookmark: \(error)")
        }

        isProcessing = false
    }
}

#Preview {
    ReactionPicker { emoji in
        print("Selected: \(emoji)")
    }
}
