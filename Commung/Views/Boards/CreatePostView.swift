import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: BoardsViewModel
    let boardSlug: String

    @State private var title = ""
    @State private var content = ""
    @State private var hashtags = ""
    @State private var communityType: String?
    @State private var selectedImage: PhotosPickerItem?
    @State private var uploadedImage: ImageUploadResponse?
    @State private var imageData: Data?
    @State private var isUploading = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var selectedTab = 0 // 0 = Edit, 1 = Preview
    @State private var showingHelp = false

    private var isPromoBoard: Bool {
        boardSlug == "promo"
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section(header: Text(NSLocalizedString("post.info_section", comment: ""))) {
                    TextField(NSLocalizedString("post.title_placeholder", comment: ""), text: $title)
                        .disabled(isCreating || isUploading)
                }

                // Community Type picker (only for promo board)
                if isPromoBoard {
                    Section(header: Text(NSLocalizedString("post.community_type_section", comment: "")),
                            footer: Text(NSLocalizedString("post.community_type_description", comment: ""))) {
                        Picker(NSLocalizedString("post.community_type_placeholder", comment: ""), selection: $communityType) {
                            Text(NSLocalizedString("post.community_type_placeholder", comment: "")).tag(nil as String?)
                            ForEach(Array(Constants.COMMUNITY_TYPE_LABELS.values).sorted(), id: \.self) { label in
                                Text(label).tag(label as String?)
                            }
                        }
                        .disabled(isCreating || isUploading)
                    }
                }

                Section(header: HStack {
                    Text(NSLocalizedString("post.content_section", comment: ""))
                    Spacer()
                    Button {
                        showingHelp = true
                    } label: {
                        Label(NSLocalizedString("markdown.help_button", comment: ""), systemImage: "questionmark.circle")
                            .font(.caption)
                    }
                }) {
                    VStack(spacing: 0) {
                        Picker("", selection: $selectedTab) {
                            Text(NSLocalizedString("markdown.edit", comment: "")).tag(0)
                            Text(NSLocalizedString("markdown.preview", comment: "")).tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 8)

                        if selectedTab == 0 {
                            TextEditor(text: $content)
                                .frame(minHeight: 200)
                                .disabled(isCreating || isUploading)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            if content.isEmpty {
                                Text(NSLocalizedString("markdown.preview_empty", comment: ""))
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .frame(minHeight: 200, alignment: .topLeading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ScrollView {
                                    Text(try! AttributedString(markdown: content, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(minHeight: 200)
                            }
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("post.hashtags_section", comment: ""))) {
                    TextField(NSLocalizedString("post.hashtags_placeholder", comment: ""), text: $hashtags)
                        .disabled(isCreating || isUploading)
                }

                Section(header: Text(NSLocalizedString("post.image_section", comment: ""))) {
                    if isUploading {
                        HStack {
                            ProgressView()
                            Text(NSLocalizedString("image.uploading", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                        VStack(alignment: .leading) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(8)

                            Button(role: .destructive) {
                                self.imageData = nil
                                self.uploadedImage = nil
                                self.selectedImage = nil
                            } label: {
                                Label(NSLocalizedString("image.remove", comment: ""), systemImage: "trash")
                            }
                        }
                    } else {
                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            Label(NSLocalizedString("image.select", comment: ""), systemImage: "photo")
                        }
                        .disabled(isCreating || isUploading)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("post.create_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                    .disabled(isCreating || isUploading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button(NSLocalizedString("post.submit", comment: "")) {
                            createPost()
                        }
                        .disabled(!canCreate)
                    }
                }
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                Task {
                    if let item = newValue {
                        await uploadSelectedImage(item)
                    }
                }
            }
            .onChange(of: communityType) { oldValue, newValue in
                // Auto-sync community type with hashtags (only for promo board)
                guard isPromoBoard else { return }

                let communityTypeLabels = Set(Constants.COMMUNITY_TYPE_LABELS.values)
                let currentHashtags = hashtags
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                // Remove any existing community type hashtags
                let filtered = currentHashtags.filter { !communityTypeLabels.contains(String($0)) }

                // Add the selected community type if one is selected
                let updated: [String]
                if let selected = newValue {
                    updated = filtered + [selected]
                } else {
                    updated = filtered
                }

                hashtags = updated.joined(separator: ", ")
            }
            .sheet(isPresented: $showingHelp) {
                MarkdownHelpView()
            }
        }
    }

    private var canCreate: Bool {
        !title.isEmpty && !content.isEmpty && !isCreating && !isUploading
    }

    private func uploadSelectedImage(_ item: PhotosPickerItem) async {
        isUploading = true
        errorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = NSLocalizedString("image.load_error", comment: "")
                isUploading = false
                return
            }

            imageData = data

            let fileName = "image_\(UUID().uuidString).jpg"
            let response = try await viewModel.uploadImage(imageData: data, fileName: fileName)
            uploadedImage = response
        } catch {
            errorMessage = error.localizedDescription
            imageData = nil
            selectedImage = nil
        }

        isUploading = false
    }

    private func createPost() {
        isCreating = true
        errorMessage = nil

        let hashtagList = hashtags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        Task {
            await viewModel.createPost(
                boardSlug: boardSlug,
                title: title,
                content: content,
                imageId: uploadedImage?.id,
                hashtags: hashtagList.isEmpty ? nil : hashtagList
            )

            if viewModel.postsError == nil {
                await viewModel.loadPosts(boardSlug: boardSlug, refresh: true)
                dismiss()
            } else {
                errorMessage = viewModel.postsError
            }

            isCreating = false
        }
    }
}

#Preview {
    NavigationStack {
        CreatePostView(boardSlug: "announcements")
            .environmentObject(BoardsViewModel())
    }
}
