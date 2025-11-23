import SwiftUI
import Combine
import Kingfisher

struct GroupChatView: View {
    let groupChatId: String
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = GroupChatViewModel()
    @State private var messageText = ""
    @State private var showMembersSheet = false
    @FocusState private var isMessageFieldFocused: Bool

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
                            GroupChatMessageBubble(
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
                .onChange(of: viewModel.messages.count) { oldValue, newValue in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
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
        .navigationTitle(viewModel.groupChatName ?? NSLocalizedString("group.chat", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showMembersSheet = true
                } label: {
                    Image(systemName: "person.2")
                }
            }
        }
        .sheet(isPresented: $showMembersSheet) {
            GroupChatMembersSheet(groupChat: viewModel.groupChat)
                .environmentObject(profileContext)
        }
        .task {
            guard let profileId = profileContext.currentProfileId else { return }
            await viewModel.loadGroupChat(groupChatId: groupChatId, profileId: profileId)
            await viewModel.loadMessages(groupChatId: groupChatId, profileId: profileId)
            await viewModel.markAsRead(groupChatId: groupChatId, profileId: profileId)
        }
        .onAppear {
            isMessageFieldFocused = true

            // Start polling for new messages
            viewModel.startPolling(groupChatId: groupChatId, profileId: profileContext.currentProfileId)
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendMessage() async {
        guard let profileId = profileContext.currentProfileId, canSend else { return }

        let content = messageText
        messageText = ""

        let request = GroupChatMessageCreateRequest(
            content: content,
            profileId: profileId,
            imageIds: nil
        )

        do {
            _ = try await viewModel.sendMessage(groupChatId: groupChatId, request: request)
        } catch {
            messageText = content
        }
    }
}

struct GroupChatMessageBubble: View {
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

struct GroupChatMembersSheet: View {
    let groupChat: GroupChat?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileContext: ProfileContext

    var body: some View {
        NavigationView {
            Group {
                if let groupChat = groupChat {
                    List {
                        Section {
                            ForEach(groupChat.members) { member in
                                NavigationLink(destination: ProfileDetailView(username: member.username).environmentObject(profileContext)) {
                                    HStack(spacing: 12) {
                                        CachedCircularImage(url: member.avatarURL, size: 40)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(member.name)
                                                .font(.headline)
                                            Text("@\(member.username)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        } header: {
                            Text(String(format: NSLocalizedString("messages.members", comment: ""), groupChat.members.count))
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(NSLocalizedString("group.members", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.done", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

@MainActor
class GroupChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var groupChat: GroupChat?
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var hasMore = false
    @Published var groupChatName: String?

    private var nextCursor: String?
    private var profileId: String?
    private var groupChatId: String?
    private var pollingTask: Task<Void, Never>?

    func loadGroupChat(groupChatId: String, profileId: String) async {
        do {
            let chat = try await MessageService.shared.getGroupChat(groupChatId: groupChatId, profileId: profileId)
            self.groupChat = chat
            self.groupChatName = chat.name
        } catch {
            print("Failed to load group chat: \(error)")
        }
    }

    func loadMessages(groupChatId: String, profileId: String) async {
        guard !isLoading else { return }

        self.profileId = profileId
        self.groupChatId = groupChatId
        isLoading = true
        errorMessage = nil

        do {
            let response = try await MessageService.shared.getGroupChatMessages(
                groupChatId: groupChatId,
                profileId: profileId,
                limit: 50,
                cursor: nil
            )
            messages = response.data // API returns chronological order
            nextCursor = response.pagination?.nextCursor
            hasMore = response.pagination?.hasMore ?? false
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load group chat messages: \(error)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore, let cursor = nextCursor,
              let profileId = profileId,
              let groupChatId = groupChatId else { return }

        isLoading = true

        do {
            let response = try await MessageService.shared.getGroupChatMessages(
                groupChatId: groupChatId,
                profileId: profileId,
                limit: 50,
                cursor: cursor
            )
            messages.insert(contentsOf: response.data, at: 0)
            nextCursor = response.pagination?.nextCursor
            hasMore = response.pagination?.hasMore ?? false
        } catch {
            print("Failed to load more messages: \(error)")
        }

        isLoading = false
    }

    func sendMessage(groupChatId: String, request: GroupChatMessageCreateRequest) async throws -> Message {
        isSending = true
        errorMessage = nil

        do {
            let message = try await MessageService.shared.sendGroupChatMessage(groupChatId: groupChatId, request: request)
            messages.append(message)
            isSending = false
            return message
        } catch {
            errorMessage = error.localizedDescription
            isSending = false
            throw error
        }
    }

    func addReaction(messageId: String, emoji: String) async {
        guard let profileId = profileId, let groupChatId = groupChatId else { return }

        do {
            let reaction = try await MessageService.shared.addReactionToGroupChatMessage(
                groupChatId: groupChatId,
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
        guard let profileId = profileId, let groupChatId = groupChatId else { return }

        do {
            try await MessageService.shared.removeReactionFromGroupChatMessage(
                groupChatId: groupChatId,
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

    func markAsRead(groupChatId: String, profileId: String) async {
        do {
            try await MessageService.shared.markGroupChatAsRead(groupChatId: groupChatId, profileId: profileId)
        } catch {
            print("Failed to mark group chat as read: \(error)")
        }
    }

    func startPolling(groupChatId: String, profileId: String?) {
        guard let profileId = profileId else { return }

        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

                guard !Task.isCancelled else { break }

                do {
                    let response = try await MessageService.shared.getGroupChatMessages(
                        groupChatId: groupChatId,
                        profileId: profileId,
                        limit: 50,
                        cursor: nil
                    )
                    await MainActor.run {
                        self.messages = response.data
                    }
                } catch {
                    print("Polling failed: \(error)")
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}

#Preview {
    NavigationView {
        GroupChatView(groupChatId: "test")
            .environmentObject(ProfileContext())
    }
}
