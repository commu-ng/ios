import SwiftUI

struct SharePostSheet: View {
    let post: CommunityPost
    let onSend: (String, String) -> Void // receiverId, message

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileContext: ProfileContext
    @EnvironmentObject var communityContext: CommunityContext

    @State private var message = ""
    @State private var isSending = false
    @State private var conversations: [Conversation] = []
    @State private var isLoadingConversations = true
    @State private var selectedReceiverId: String?
    @State private var searchText = ""

    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        }
        return conversations.filter { conversation in
            conversation.otherProfile.name.localizedCaseInsensitiveContains(searchText) ||
            conversation.otherProfile.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Post preview
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        CachedCircularImage(url: post.author.avatarURL, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.author.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("@\(post.author.username)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(post.content)
                        .font(.subheadline)
                        .lineLimit(3)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()

                Divider()

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(NSLocalizedString("share.search", comment: ""), text: $searchText)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)

                // Conversations list
                if isLoadingConversations {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if conversations.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("share.no_conversations", comment: ""))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredConversations, id: \.otherProfile.id) { conversation in
                            Button {
                                selectedReceiverId = conversation.otherProfile.id
                            } label: {
                                HStack(spacing: 12) {
                                    CachedCircularImage(url: conversation.otherProfile.avatarURL, size: 44)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(conversation.otherProfile.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("@\(conversation.otherProfile.username)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if selectedReceiverId == conversation.otherProfile.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                // Message input
                if selectedReceiverId != nil {
                    Divider()

                    VStack(spacing: 12) {
                        TextField(NSLocalizedString("share.add_message", comment: ""), text: $message, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)

                        Button {
                            sendMessage()
                        } label: {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text(NSLocalizedString("share.send", comment: ""))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSending)
                    }
                    .padding()
                }
            }
            .navigationTitle(NSLocalizedString("share.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadConversations()
        }
    }

    private func loadConversations() async {
        guard let profileId = profileContext.currentProfileId else { return }

        do {
            let response = try await MessageService.shared.getConversations(
                profileId: profileId,
                limit: 50
            )
            conversations = response.data
        } catch {
            print("Failed to load conversations: \(error)")
        }

        isLoadingConversations = false
    }

    private func sendMessage() {
        guard let receiverId = selectedReceiverId else { return }

        isSending = true

        // Build message with post link
        let communityURL = communityContext.currentCommunity?.communityURL ?? "https://commu.ng"
        let postLink = "\(communityURL)/@\(post.author.username)/\(post.id)"
        let fullMessage = message.isEmpty ? postLink : "\(postLink)\n\n\(message)"

        onSend(receiverId, fullMessage)
    }
}
