import SwiftUI
import Combine

struct MessagesView: View {
    @EnvironmentObject var communityContext: CommunityContext
    @EnvironmentObject var profileContext: ProfileContext

    var body: some View {
        NavigationView {
            Group {
                if communityContext.currentCommunity == nil {
                    ContentUnavailableView(
                        NSLocalizedString("messages.no_community", comment: ""),
                        systemImage: "person.3",
                        description: Text(NSLocalizedString("messages.no_community_description", comment: ""))
                    )
                } else if profileContext.currentProfile == nil {
                    ContentUnavailableView(
                        NSLocalizedString("messages.no_profile", comment: ""),
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text(NSLocalizedString("messages.loading_profile", comment: ""))
                    )
                } else {
                    ConversationsListView()
                }
            }
            .navigationTitle(NSLocalizedString("messages.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ConversationsListView: View {
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = ConversationsViewModel()
    @State private var showCreateGroupSheet = false
    @State private var showNewMessageSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.conversations.isEmpty && viewModel.groupChats.isEmpty {
                    ProgressView()
                        .padding()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.conversations.isEmpty && viewModel.groupChats.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("messages.no_messages", comment: ""),
                        systemImage: "message",
                        description: Text(NSLocalizedString("messages.start_conversation", comment: ""))
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        // Group chats
                        ForEach(viewModel.groupChats) { groupChat in
                            NavigationLink(destination: GroupChatView(groupChatId: groupChat.id).environmentObject(profileContext)) {
                                GroupChatRow(groupChat: groupChat)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider()
                        }

                        // Direct conversations
                        ForEach(viewModel.conversations) { conversation in
                            NavigationLink(destination: ChatView(otherProfileId: conversation.otherProfile.id).environmentObject(profileContext)) {
                                ConversationRow(conversation: conversation)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider()
                        }

                        if viewModel.hasMore || viewModel.hasMoreGroupChats {
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
        .task {
            if let profileId = profileContext.currentProfileId {
                await viewModel.loadConversations(profileId: profileId)
                await viewModel.loadGroupChats(profileId: profileId)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showNewMessageSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }

                    Button {
                        showCreateGroupSheet = true
                    } label: {
                        Image(systemName: "person.2.badge.plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateGroupSheet) {
            CreateGroupChatSheet(onCreated: {
                Task {
                    if let profileId = profileContext.currentProfileId {
                        await viewModel.loadGroupChats(profileId: profileId)
                    }
                }
            })
            .environmentObject(profileContext)
        }
        .sheet(isPresented: $showNewMessageSheet) {
            NewMessageSheet()
                .environmentObject(profileContext)
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            CachedCircularImage(url: conversation.otherProfile.avatarURL, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherProfile.name)
                        .font(.headline)

                    Spacer()

                    if let createdDate = conversation.lastMessage?.createdDate {
                        Text(createdDate, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if conversation.unreadCountInt > 0 {
                    Text(String(format: NSLocalizedString("messages.unread", comment: ""), conversation.unreadCountInt))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .contentShape(Rectangle())
    }
}

struct GroupChatRow: View {
    let groupChat: GroupChat

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)

                Image(systemName: "person.2.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(groupChat.name)
                        .font(.headline)

                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let updatedDate = groupChat.updatedDate {
                        Text(updatedDate, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(String(format: NSLocalizedString("messages.members", comment: ""), groupChat.members.count))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let lastMessage = groupChat.lastMessage {
                    Text("\(lastMessage.sender.name): \(lastMessage.content)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if groupChat.unreadCount > 0 {
                    Text(String(format: NSLocalizedString("messages.unread", comment: ""), groupChat.unreadCount))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .contentShape(Rectangle())
    }
}

@MainActor
class ConversationsViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var groupChats: [GroupChat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = false
    @Published var hasMoreGroupChats = false

    private var nextCursor: String?
    private var nextGroupChatCursor: String?
    private var profileId: String?

    func loadConversations(profileId: String) async {
        guard !isLoading else { return }

        self.profileId = profileId
        isLoading = true
        errorMessage = nil

        do {
            let response = try await MessageService.shared.getConversations(profileId: profileId, limit: 20, cursor: nil)
            conversations = response.data
            nextCursor = response.pagination?.nextCursor
            hasMore = response.pagination?.hasMore ?? false
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load conversations: \(error)")
        }

        isLoading = false
    }

    func loadGroupChats(profileId: String) async {
        guard !isLoading else { return }

        self.profileId = profileId
        isLoading = true
        errorMessage = nil

        do {
            let response = try await MessageService.shared.getGroupChats(profileId: profileId, limit: 20, cursor: nil)
            groupChats = response.data
            nextGroupChatCursor = response.pagination?.nextCursor
            hasMoreGroupChats = response.pagination?.hasMore ?? false
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load group chats: \(error)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, let profileId = profileId else { return }

        isLoading = true

        // Load more conversations
        if hasMore, let cursor = nextCursor {
            do {
                let response = try await MessageService.shared.getConversations(profileId: profileId, limit: 20, cursor: cursor)
                conversations.append(contentsOf: response.data)
                nextCursor = response.pagination?.nextCursor
                hasMore = response.pagination?.hasMore ?? false
            } catch {
                print("Failed to load more conversations: \(error)")
            }
        }

        // Load more group chats
        if hasMoreGroupChats, let cursor = nextGroupChatCursor {
            do {
                let response = try await MessageService.shared.getGroupChats(profileId: profileId, limit: 20, cursor: cursor)
                groupChats.append(contentsOf: response.data)
                nextGroupChatCursor = response.pagination?.nextCursor
                hasMoreGroupChats = response.pagination?.hasMore ?? false
            } catch {
                print("Failed to load more group chats: \(error)")
            }
        }

        isLoading = false
    }

    func refresh() async {
        conversations = []
        groupChats = []
        nextCursor = nil
        nextGroupChatCursor = nil
        hasMore = false
        hasMoreGroupChats = false
        // Will be reloaded by task modifier
    }
}

struct CreateGroupChatSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = CreateGroupChatViewModel()

    let onCreated: () -> Void

    @State private var groupName = ""
    @State private var selectedProfiles: Set<String> = []

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("group.name", comment: ""))) {
                    TextField(NSLocalizedString("group.name_placeholder", comment: ""), text: $groupName)
                }

                Section(header: Text(NSLocalizedString("group.select_members", comment: ""))) {
                    if viewModel.isLoadingProfiles {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if viewModel.availableProfiles.isEmpty {
                        Text(NSLocalizedString("group.no_profiles", comment: ""))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.availableProfiles) { profile in
                            Button {
                                toggleSelection(profileId: profile.id)
                            } label: {
                                HStack {
                                    CachedCircularImage(url: profile.avatarURL, size: 40)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("@\(profile.username)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if selectedProfiles.contains(profile.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("group.new", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("group.create", comment: "")) {
                        Task {
                            await createGroup()
                        }
                    }
                    .disabled(!canCreate || viewModel.isCreating)
                }
            }
            .task {
                guard let currentProfileId = profileContext.currentProfileId else { return }
                await viewModel.loadProfiles(currentProfileId: currentProfileId)
            }
        }
    }

    private var canCreate: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func toggleSelection(profileId: String) {
        if selectedProfiles.contains(profileId) {
            selectedProfiles.remove(profileId)
        } else {
            selectedProfiles.insert(profileId)
        }
    }

    private func createGroup() async {
        guard let creatorProfileId = profileContext.currentProfileId else { return }

        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let success = await viewModel.createGroupChat(
            name: trimmedName,
            memberProfileIds: Array(selectedProfiles),
            creatorProfileId: creatorProfileId
        )

        if success {
            onCreated()
            dismiss()
        }
    }
}

@MainActor
class CreateGroupChatViewModel: ObservableObject {
    @Published var availableProfiles: [MessageProfile] = []
    @Published var isLoadingProfiles = false
    @Published var isCreating = false
    @Published var errorMessage: String?

    func loadProfiles(currentProfileId: String) async {
        isLoadingProfiles = true
        errorMessage = nil

        do {
            let profiles = try await ProfileService.shared.getAllProfiles(profileId: currentProfileId)
            // Filter out current profile
            let messageProfiles = profiles.map { profile in
                MessageProfile(
                    id: profile.id,
                    name: profile.name,
                    username: profile.username,
                    profilePictureUrl: profile.profilePictureUrl
                )
            }
            availableProfiles = messageProfiles.filter { $0.id != currentProfileId }
        } catch {
            errorMessage = "Failed to load profiles: \(error.localizedDescription)"
            print("Failed to load profiles: \(error)")
        }

        isLoadingProfiles = false
    }

    func createGroupChat(name: String, memberProfileIds: [String], creatorProfileId: String) async -> Bool {
        isCreating = true
        errorMessage = nil

        let request = GroupChatCreateRequest(
            name: name,
            memberProfileIds: memberProfileIds,
            creatorProfileId: creatorProfileId
        )

        do {
            _ = try await MessageService.shared.createGroupChat(request: request)
            isCreating = false
            return true
        } catch {
            errorMessage = "Failed to create group: \(error.localizedDescription)"
            print("Failed to create group chat: \(error)")
            isCreating = false
            return false
        }
    }
}

struct NewMessageSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = NewMessageViewModel()
    @State private var selectedProfile: MessageProfile?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if viewModel.profiles.isEmpty {
                    Text(NSLocalizedString("messages.no_profiles", comment: ""))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.profiles) { profile in
                        NavigationLink(destination: ChatView(otherProfileId: profile.id)
                            .environmentObject(profileContext)
                        ) {
                            HStack(spacing: 12) {
                                CachedCircularImage(url: profile.avatarURL, size: 44)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("@\(profile.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("messages.new_message", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }
            }
            .task {
                guard let currentProfileId = profileContext.currentProfileId else { return }
                await viewModel.loadProfiles(currentProfileId: currentProfileId)
            }
        }
    }
}

@MainActor
class NewMessageViewModel: ObservableObject {
    @Published var profiles: [MessageProfile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadProfiles(currentProfileId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let allProfiles = try await ProfileService.shared.getAllProfiles(profileId: currentProfileId)
            // Filter out current profile and map to MessageProfile
            profiles = allProfiles
                .filter { $0.id != currentProfileId }
                .map { profile in
                    MessageProfile(
                        id: profile.id,
                        name: profile.name,
                        username: profile.username,
                        profilePictureUrl: profile.profilePictureUrl
                    )
                }
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load profiles: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    MessagesView()
        .environmentObject(CommunityContext())
        .environmentObject(ProfileContext())
}
