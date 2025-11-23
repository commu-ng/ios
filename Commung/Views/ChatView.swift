import SwiftUI
import Combine
import Kingfisher

struct ChatView: View {
    let otherProfileId: String
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @FocusState private var isMessageFieldFocused: Bool

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.hasMore {
                            Button(NSLocalizedString("messages.load_earlier", comment: "")) {
                                Task {
                                    await viewModel.loadMore()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }

                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isCurrentUser: message.senderId == profileContext.currentProfileId,
                                onAddReaction: { emoji in
                                    Task {
                                        await viewModel.addReaction(messageId: message.id, emoji: emoji)
                                    }
                                },
                                onRemoveReaction: { emoji in
                                    Task {
                                        await viewModel.removeReaction(messageId: message.id, emoji: emoji)
                                    }
                                },
                                currentProfileId: profileContext.currentProfileId
                            )
                            .id(message.id)
                        }

                        if viewModel.isLoading && viewModel.messages.isEmpty {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding()
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { oldValue, newValue in
                    // Scroll to bottom when new messages are added
                    if newValue > oldValue,
                       let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .top)
                            }
                        }
                    }
                }
            }

            Divider()

            // Message input
            HStack(spacing: 12) {
                TextField(NSLocalizedString("messages.type_message", comment: ""), text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .focused($isMessageFieldFocused)

                Button {
                    Task {
                        await sendMessage()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .blue : .gray)
                }
                .disabled(!canSend || viewModel.isSending)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle(viewModel.otherProfileName ?? NSLocalizedString("messages.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let profileId = profileContext.currentProfileId else { return }
            await viewModel.loadMessages(
                otherProfileId: otherProfileId,
                currentProfileId: profileId
            )
            // Mark as read
            await viewModel.markAsRead(otherProfileId: otherProfileId)
        }
        .onAppear {
            // Auto-focus message field
            isMessageFieldFocused = true
        }
    }

    private func sendMessage() async {
        guard let profileId = profileContext.currentProfileId, canSend else { return }

        let content = messageText
        messageText = "" // Clear immediately for better UX

        let request = MessageCreateRequest(
            content: content,
            receiverId: otherProfileId,
            profileId: profileId,
            imageIds: nil
        )

        do {
            _ = try await viewModel.sendMessage(request: request)
            // Message will be added to list by viewModel
        } catch {
            // Restore message on error
            messageText = content
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let onAddReaction: (String) -> Void
    let onRemoveReaction: (String) -> Void
    let currentProfileId: String?
    @EnvironmentObject var profileContext: ProfileContext

    @State private var showReactionPicker = false

    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 50)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    NavigationLink(destination: ProfileDetailView(username: message.sender.username).environmentObject(profileContext)) {
                        HStack(spacing: 8) {
                            CachedCircularImage(url: message.sender.avatarURL, size: 24)
                            Text(message.sender.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(isCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                        .contextMenu {
                            Button {
                                showReactionPicker = true
                            } label: {
                                Label(NSLocalizedString("messages.add_reaction", comment: ""), systemImage: "face.smiling")
                            }
                        }

                    // Images
                    if !message.images.isEmpty {
                        ForEach(message.images) { image in
                            if let url = image.imageURL {
                                KFImage(url)
                                    .placeholder {
                                        Color.gray.opacity(0.2)
                                    }
                                    .fade(duration: 0.2)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 250)
                                    .cornerRadius(12)
                            }
                        }
                    }

                    // Reactions
                    if !message.reactions.isEmpty {
                        let groupedReactions = Dictionary(grouping: message.reactions) { $0.emoji }

                        HStack(spacing: 4) {
                            ForEach(groupedReactions.keys.sorted(), id: \.self) { emoji in
                                let reactions = groupedReactions[emoji] ?? []
                                let hasReacted = reactions.contains { $0.user.id == currentProfileId }

                                Button {
                                    if hasReacted {
                                        onRemoveReaction(emoji)
                                    } else {
                                        onAddReaction(emoji)
                                    }
                                } label: {
                                    HStack(spacing: 2) {
                                        Text(emoji)
                                            .font(.caption)
                                        Text("\(reactions.count)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(hasReacted ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }

                if let createdDate = message.createdDate {
                    Text(createdDate, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if !isCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .sheet(isPresented: $showReactionPicker) {
            ReactionPickerSheet { emoji in
                onAddReaction(emoji)
                showReactionPicker = false
            }
        }
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var hasMore = false
    @Published var otherProfileName: String?

    private var nextCursor: String?
    private var currentProfileId: String?
    private var otherProfileId: String?

    func loadMessages(otherProfileId: String, currentProfileId: String) async {
        guard !isLoading else { return }

        self.currentProfileId = currentProfileId
        self.otherProfileId = otherProfileId
        isLoading = true
        errorMessage = nil

        do {
            let thread = try await MessageService.shared.getConversationThread(
                otherProfileId: otherProfileId,
                profileId: currentProfileId,
                limit: 50,
                cursor: nil
            )
            messages = thread.data // API returns chronological order
            nextCursor = thread.pagination?.nextCursor
            hasMore = thread.pagination?.hasMore ?? false

            // Get other profile name from first message
            if let firstMessage = thread.data.first {
                if firstMessage.senderId == otherProfileId {
                    otherProfileName = firstMessage.sender.name
                } else if let receiver = firstMessage.receiver {
                    otherProfileName = receiver.name
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load messages: \(error)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore, let cursor = nextCursor,
              let currentProfileId = currentProfileId,
              let otherProfileId = otherProfileId else { return }

        isLoading = true

        do {
            let thread = try await MessageService.shared.getConversationThread(
                otherProfileId: otherProfileId,
                profileId: currentProfileId,
                limit: 50,
                cursor: cursor
            )
            // Prepend older messages
            messages.insert(contentsOf: thread.data, at: 0)
            nextCursor = thread.pagination?.nextCursor
            hasMore = thread.pagination?.hasMore ?? false
        } catch {
            print("Failed to load more messages: \(error)")
        }

        isLoading = false
    }

    func sendMessage(request: MessageCreateRequest) async throws -> Message {
        isSending = true
        errorMessage = nil

        do {
            let message = try await MessageService.shared.sendMessage(request: request)
            // Add to end of list
            messages.append(message)
            isSending = false
            return message
        } catch {
            errorMessage = error.localizedDescription
            isSending = false
            throw error
        }
    }

    func markAsRead(otherProfileId: String) async {
        guard let profileId = currentProfileId else { return }
        do {
            try await MessageService.shared.markConversationAsRead(otherProfileId: otherProfileId, profileId: profileId)
        } catch {
            print("Failed to mark conversation as read: \(error)")
        }
    }

    func addReaction(messageId: String, emoji: String) async {
        guard let profileId = currentProfileId else { return }

        do {
            let reaction = try await MessageService.shared.addReactionToMessage(
                messageId: messageId,
                emoji: emoji,
                profileId: profileId
            )

            // Optimistically update UI
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].reactions.append(reaction)
            }
        } catch {
            print("Failed to add reaction: \(error)")
        }
    }

    func removeReaction(messageId: String, emoji: String) async {
        guard let profileId = currentProfileId else { return }

        do {
            try await MessageService.shared.removeReactionFromMessage(
                messageId: messageId,
                emoji: emoji,
                profileId: profileId
            )

            // Optimistically update UI
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].reactions.removeAll { $0.emoji == emoji && $0.user.id == profileId }
            }
        } catch {
            print("Failed to remove reaction: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        ChatView(otherProfileId: "test")
            .environmentObject(ProfileContext())
    }
}
