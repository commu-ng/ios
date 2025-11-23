import SwiftUI
import Combine
import PhotosUI

struct PostComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profileContext: ProfileContext

    let inReplyToPost: CommunityPost?
    let onPostCreated: ((CommunityPost) -> Void)?

    @StateObject private var viewModel = PostComposerViewModel()

    @State private var content = ""
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var contentWarning = ""
    @State private var showContentWarningField = false
    @State private var isAnnouncement = false
    @State private var showMarkdownHelp = false

    // Scheduling state
    @State private var isScheduled = false
    @State private var scheduledDate = Date().addingTimeInterval(3600) // Default to 1 hour from now
    @State private var showDatePicker = false

    // Mention system state
    @State private var showMentionDropdown = false
    @State private var mentionQuery = ""
    @State private var mentionProfiles: [AppProfile] = []
    @State private var allProfiles: [AppProfile] = []
    @State private var mentionStartIndex: String.Index?
    @State private var selectedMentionIndex = 0

    init(inReplyToPost: CommunityPost? = nil, onPostCreated: ((CommunityPost) -> Void)? = nil) {
        self.inReplyToPost = inReplyToPost
        self.onPostCreated = onPostCreated
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Reply context
                    if let replyTo = inReplyToPost {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: NSLocalizedString("composer.replying_to", comment: ""), replyTo.author.username))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(replyTo.content)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }

                    // Content editor
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("composer.content", comment: ""))
                                .font(.headline)

                            Spacer()

                            Text("\(content.count)/500")
                                .font(.caption)
                                .foregroundColor(content.count > 500 ? .red : .secondary)

                            Button {
                                showMarkdownHelp = true
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.caption)
                            }
                        }

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $content)
                                .frame(minHeight: 150)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                                .onChange(of: content) { oldValue, newValue in
                                    checkForMention(in: newValue)
                                }

                            // Mention dropdown
                            if showMentionDropdown && !mentionProfiles.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(mentionProfiles.prefix(5).enumerated()), id: \.element.id) { index, profile in
                                        Button {
                                            selectMention(profile)
                                        } label: {
                                            HStack(spacing: 8) {
                                                CachedCircularImage(url: profile.avatarURL, size: 32)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(profile.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.primary)
                                                    Text("@\(profile.username)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }

                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(index == selectedMentionIndex ? Color.blue.opacity(0.1) : Color.clear)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                .padding(.top, 160)
                                .padding(.horizontal, 8)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Image picker
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("markdown.images", comment: ""))
                                .font(.headline)

                            Spacer()

                            PhotosPicker(
                                selection: $selectedImages,
                                maxSelectionCount: 4,
                                matching: .images
                            ) {
                                Label(NSLocalizedString("composer.add_images", comment: ""), systemImage: "photo.on.rectangle.angled")
                                    .font(.caption)
                            }
                        }

                        if !viewModel.uploadedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.uploadedImages) { image in
                                        ZStack(alignment: .topTrailing) {
                                            if let url = image.imageURL {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                    case .failure:
                                                        Color.gray.opacity(0.3)
                                                    case .empty:
                                                        ProgressView()
                                                    @unknown default:
                                                        Color.gray.opacity(0.3)
                                                    }
                                                }
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }

                                            Button {
                                                viewModel.removeImage(image)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                            }
                        }

                        if viewModel.isUploadingImages {
                            HStack {
                                ProgressView()
                                Text(NSLocalizedString("composer.uploading_images", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Content warning
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(NSLocalizedString("composer.content_warning", comment: ""), isOn: $showContentWarningField)
                            .font(.headline)

                        if showContentWarningField {
                            TextField(NSLocalizedString("composer.cw_hint", comment: ""), text: $contentWarning)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.horizontal)

                    // Announcement toggle (if user is owner/moderator)
                    // TODO: Check permissions
                    Toggle(NSLocalizedString("composer.announcement", comment: ""), isOn: $isAnnouncement)
                        .font(.headline)
                        .padding(.horizontal)

                    // Scheduling section (only for new posts, not replies)
                    if inReplyToPost == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(NSLocalizedString("composer.schedule_post", comment: ""), isOn: $isScheduled)
                                .font(.headline)

                            if isScheduled {
                                Button {
                                    showDatePicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "calendar")
                                        Text(scheduledDate, style: .date)
                                        Text(scheduledDate, style: .time)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                .foregroundColor(.primary)

                                if scheduledDate < Date() {
                                    Text(NSLocalizedString("composer.schedule_future", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(inReplyToPost != nil ? NSLocalizedString("composer.reply", comment: "") : NSLocalizedString("composer.new_post", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.post", comment: "")) {
                        Task {
                            await createPost()
                        }
                    }
                    .disabled(!canPost || viewModel.isPosting)
                }
            }
            .sheet(isPresented: $showMarkdownHelp) {
                MarkdownHelpSheet()
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    DatePicker(
                        "Schedule",
                        selection: $scheduledDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle(NSLocalizedString("composer.schedule_post", comment: ""))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(NSLocalizedString("action.done", comment: "")) {
                                showDatePicker = false
                            }
                        }
                    }
                }
            }
            .onChange(of: selectedImages) { oldValue, newValue in
                Task {
                    await viewModel.uploadImages(items: newValue)
                }
            }
            .task {
                await loadAllProfiles()
            }
        }
    }

    private var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.count <= 500 &&
        !viewModel.isUploadingImages &&
        (!isScheduled || scheduledDate > Date())
    }

    // MARK: - Mention System

    private func loadAllProfiles() async {
        guard let profileId = profileContext.currentProfileId else { return }

        do {
            allProfiles = try await ProfileService.shared.getAllProfiles(profileId: profileId)
        } catch {
            print("Failed to load profiles for mentions: \(error)")
        }
    }

    private func checkForMention(in text: String) {
        // Find the last @ symbol that might be a mention in progress
        guard let atIndex = text.lastIndex(of: "@") else {
            showMentionDropdown = false
            mentionQuery = ""
            return
        }

        let afterAt = text[text.index(after: atIndex)...]

        // Check if there's a space after the @ (completed mention or not a mention)
        if afterAt.contains(" ") || afterAt.contains("\n") {
            // Check if this is at the end of the text
            let endIndex = afterAt.firstIndex(of: " ") ?? afterAt.firstIndex(of: "\n") ?? afterAt.endIndex
            let textAfterSpace = afterAt[endIndex...]

            // If there's more text after the space, don't show dropdown
            if !textAfterSpace.isEmpty {
                showMentionDropdown = false
                mentionQuery = ""
                return
            }
        }

        // Extract the query (text after @)
        let query = String(afterAt).trimmingCharacters(in: .whitespacesAndNewlines)

        // Only show if it looks like a mention (alphanumeric or underscore)
        let validMentionPattern = "^[a-zA-Z0-9_]*$"
        guard query.range(of: validMentionPattern, options: .regularExpression) != nil else {
            showMentionDropdown = false
            mentionQuery = ""
            return
        }

        mentionStartIndex = atIndex
        mentionQuery = query
        showMentionDropdown = true
        selectedMentionIndex = 0

        // Filter profiles
        if query.isEmpty {
            mentionProfiles = Array(allProfiles.prefix(10))
        } else {
            mentionProfiles = allProfiles.filter { profile in
                profile.name.localizedCaseInsensitiveContains(query) ||
                profile.username.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private func selectMention(_ profile: AppProfile) {
        guard let startIndex = mentionStartIndex else { return }

        // Replace the @query with @username
        let beforeMention = String(content[..<startIndex])
        let afterMention = content[startIndex...].dropFirst(1 + mentionQuery.count) // Remove @ and query

        content = "\(beforeMention)@\(profile.username) \(afterMention)"

        showMentionDropdown = false
        mentionQuery = ""
        mentionProfiles = []
    }

    private func createPost() async {
        guard let profileId = profileContext.currentProfileId else { return }

        // Format scheduled date as ISO 8601 string if scheduling
        let scheduledAtString: String? = if isScheduled && scheduledDate > Date() {
            ISO8601DateFormatter().string(from: scheduledDate)
        } else {
            nil
        }

        let request = PostCreateRequest(
            content: content,
            profileId: profileId,
            inReplyToId: inReplyToPost?.id,
            imageIds: viewModel.uploadedImages.map { $0.id },
            announcement: isAnnouncement ? true : nil,
            contentWarning: showContentWarningField && !contentWarning.isEmpty ? contentWarning : nil,
            scheduledAt: scheduledAtString
        )

        do {
            let post = try await viewModel.createPost(request: request)
            onPostCreated?(post)
            dismiss()
        } catch {
            // Error is set in viewModel
        }
    }
}

struct MarkdownHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text(NSLocalizedString("composer.markdown_syntax", comment: ""))
                            .font(.title2)
                            .fontWeight(.bold)

                        MarkdownHelpRow(syntax: "**bold**", description: "Bold text")
                        MarkdownHelpRow(syntax: "*italic*", description: "Italic text")
                        MarkdownHelpRow(syntax: "[link](url)", description: "Hyperlink")
                        MarkdownHelpRow(syntax: "# Heading", description: "Heading")
                        MarkdownHelpRow(syntax: "- item", description: "Bullet list")
                        MarkdownHelpRow(syntax: "1. item", description: "Numbered list")
                        MarkdownHelpRow(syntax: "`code`", description: "Inline code")
                        MarkdownHelpRow(syntax: "```\ncode\n```", description: "Code block")
                        MarkdownHelpRow(syntax: "@username", description: "Mention user")
                    }
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("markdown.help_button", comment: ""))
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

struct MarkdownHelpRow: View {
    let syntax: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(syntax)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(4)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

@MainActor
class PostComposerViewModel: ObservableObject {
    @Published var uploadedImages: [CommunityPostImage] = []
    @Published var isUploadingImages = false
    @Published var isPosting = false
    @Published var errorMessage: String?

    func uploadImages(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        isUploadingImages = true
        errorMessage = nil
        uploadedImages = []

        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let filename = "image_\(UUID().uuidString).jpg"
                    let image = try await PostService.shared.uploadImage(imageData: data, filename: filename)
                    uploadedImages.append(image)
                }
            } catch {
                errorMessage = "Failed to upload image: \(error.localizedDescription)"
                print("Image upload error: \(error)")
            }
        }

        isUploadingImages = false
    }

    func removeImage(_ image: CommunityPostImage) {
        uploadedImages.removeAll { $0.id == image.id }
    }

    func createPost(request: PostCreateRequest) async throws -> CommunityPost {
        isPosting = true
        errorMessage = nil

        do {
            let post = try await PostService.shared.createPost(request: request)
            isPosting = false
            return post
        } catch {
            errorMessage = error.localizedDescription
            isPosting = false
            throw error
        }
    }
}

#Preview {
    PostComposerView()
        .environmentObject(ProfileContext())
}
