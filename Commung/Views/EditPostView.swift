import SwiftUI
import PhotosUI
import Combine

struct EditPostView: View {
    let post: CommunityPost
    let onPostUpdated: () -> Void

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = EditPostViewModel()

    @State private var content: String
    @State private var contentWarning: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingImagePicker = false

    init(post: CommunityPost, onPostUpdated: @escaping () -> Void) {
        self.post = post
        self.onPostUpdated = onPostUpdated
        _content = State(initialValue: post.content)
        _contentWarning = State(initialValue: post.contentWarning ?? "")
    }

    private var hasChanges: Bool {
        content != post.content ||
        contentWarning != (post.contentWarning ?? "") ||
        viewModel.hasImageChanges
    }

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.count <= 500 &&
        !viewModel.isSaving &&
        hasChanges
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("composer.content", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $content)
                            .frame(minHeight: 120)
                        HStack {
                            Spacer()
                            Text("\(content.count)/500")
                                .font(.caption)
                                .foregroundColor(content.count > 500 ? .red : .secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("composer.content_warning", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(NSLocalizedString("composer.cw_placeholder", comment: ""), text: $contentWarning)
                            .textFieldStyle(.plain)
                    }
                }

                Section(header: Text(NSLocalizedString("markdown.images", comment: ""))) {
                    if !viewModel.images.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.images) { image in
                                    ZStack(alignment: .topTrailing) {
                                        if let uiImage = image.image {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else if let url = image.url {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 100, height: 100)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                case .failure:
                                                    Color.gray.opacity(0.2)
                                                        .frame(width: 100, height: 100)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .overlay(
                                                            Image(systemName: "exclamationmark.triangle")
                                                                .foregroundColor(.red)
                                                        )
                                                case .empty:
                                                    ProgressView()
                                                        .frame(width: 100, height: 100)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                        }

                                        Button {
                                            viewModel.removeImage(image)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if viewModel.images.count < 4 {
                        Button {
                            showingImagePicker = true
                        } label: {
                            Label(NSLocalizedString("image.select", comment: ""), systemImage: "photo")
                        }
                    }

                    if viewModel.isUploadingImage {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(NSLocalizedString("image.uploading", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("profile.edit", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await savePost()
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text(NSLocalizedString("action.save", comment: ""))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotos, maxSelectionCount: 4 - viewModel.images.count, matching: .images)
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
                    await viewModel.loadImages(from: newValue)
                    selectedPhotos = []
                }
            }
        }
        .task {
            await viewModel.loadPost(post: post)
        }
    }

    private func savePost() async {
        guard let profileId = profileContext.currentProfileId else { return }

        let success = await viewModel.updatePost(
            postId: post.id,
            profileId: profileId,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            contentWarning: contentWarning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contentWarning
        )

        if success {
            onPostUpdated()
            dismiss()
        }
    }
}

@MainActor
class EditPostViewModel: ObservableObject {
    struct EditImage: Identifiable {
        let id: String
        let url: URL?
        let image: UIImage?
        let isNew: Bool

        init(id: String, url: URL?) {
            self.id = id
            self.url = url
            self.image = nil
            self.isNew = false
        }

        init(id: String, image: UIImage) {
            self.id = id
            self.url = nil
            self.image = image
            self.isNew = true
        }
    }

    @Published var images: [EditImage] = []
    @Published var isUploadingImage = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var hasImageChanges = false

    private var originalImageIds: Set<String> = []
    private var uploadedImageIds: [String] = []

    func loadPost(post: CommunityPost) async {
        // Load existing images
        images = post.images.map { EditImage(id: $0.id, url: URL(string: $0.url)) }
        originalImageIds = Set(post.images.map { $0.id })
    }

    func loadImages(from items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                continue
            }

            // Add to UI immediately
            let tempId = UUID().uuidString
            images.append(EditImage(id: tempId, image: image))
            hasImageChanges = true

            // Upload in background
            await uploadImage(image: image, tempId: tempId)
        }
    }

    private func uploadImage(image: UIImage, tempId: String) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        isUploadingImage = true
        errorMessage = nil

        do {
            let result = try await PostService.shared.uploadImage(imageData: imageData, filename: "image.jpg")

            // Replace temp image with uploaded one
            if let index = images.firstIndex(where: { $0.id == tempId }) {
                images[index] = EditImage(id: result.id, url: URL(string: result.url))
                uploadedImageIds.append(result.id)
            }
        } catch {
            errorMessage = "Failed to upload image: \(error.localizedDescription)"
            // Remove failed upload
            images.removeAll { $0.id == tempId }
            hasImageChanges = images.map { $0.id } != Array(originalImageIds)
        }

        isUploadingImage = false
    }

    func removeImage(_ image: EditImage) {
        images.removeAll { $0.id == image.id }
        uploadedImageIds.removeAll { $0 == image.id }
        hasImageChanges = Set(images.map { $0.id }) != originalImageIds
    }

    func updatePost(postId: String, profileId: String, content: String, contentWarning: String?) async -> Bool {
        isSaving = true
        errorMessage = nil

        do {
            let imageIds = images.map { $0.id }

            let request = PostUpdateRequest(
                content: content,
                imageIds: imageIds.isEmpty ? nil : imageIds,
                contentWarning: contentWarning
            )

            _ = try await PostService.shared.updatePost(postId: postId, profileId: profileId, request: request)
            isSaving = false
            return true
        } catch {
            errorMessage = "Failed to update post: \(error.localizedDescription)"
            print("Failed to update post: \(error)")
            isSaving = false
            return false
        }
    }
}
