import SwiftUI
import PhotosUI
import Combine

struct ProfileSettingsView: View {
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = ProfileSettingsViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var displayName = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingImagePicker = false

    var hasChanges: Bool {
        guard let profile = viewModel.currentProfile else { return false }
        return displayName != profile.name ||
               username != profile.username ||
               bio != (profile.bio ?? "") ||
               viewModel.hasNewProfilePicture
    }

    var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        viewModel.usernameError.isEmpty &&
        !viewModel.isSaving &&
        hasChanges
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    // Profile Picture
                    VStack(spacing: 16) {
                        ZStack(alignment: .bottomTrailing) {
                            if let image = viewModel.profilePicturePreview {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let url = viewModel.currentProfile?.avatarURL {
                                CachedCircularImage(url: url, size: 100)
                            } else {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.white)
                                    )
                            }

                            Button {
                                showingImagePicker = true
                            } label: {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    )
                            }
                        }

                        if viewModel.isUploadingProfilePicture {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(NSLocalizedString("profile.uploading", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section(header: Text(NSLocalizedString("account.information", comment: ""))) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("profile.display_name", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(NSLocalizedString("profile.display_name", comment: ""), text: $displayName)
                            .textFieldStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("profile.username", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(NSLocalizedString("profile.username", comment: ""), text: $username)
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onChange(of: username) { _, newValue in
                                viewModel.validateUsername(newValue)
                            }

                        if !viewModel.usernameError.isEmpty {
                            Text(viewModel.usernameError)
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if !username.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(NSLocalizedString("profile.username_valid", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(NSLocalizedString("profile.bio", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(bio.count)/500")
                                .font(.caption)
                                .foregroundColor(bio.count > 500 ? .red : .secondary)
                        }
                        TextField(NSLocalizedString("profile.bio_placeholder", comment: ""), text: $bio, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(5...10)
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
                            await saveProfile()
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
            .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await viewModel.uploadProfilePicture(image: image)
                    }
                }
            }
            .task {
                if let profile = profileContext.currentProfile {
                    await viewModel.loadProfile(profile: profile)
                    displayName = profile.name
                    username = profile.username
                    bio = profile.bio ?? ""
                }
            }
        }
    }

    private func saveProfile() async {
        guard let profileId = profileContext.currentProfileId else { return }

        viewModel.isSaving = true
        viewModel.errorMessage = nil

        do {
            try await profileContext.updateProfile(
                profileId: profileId,
                name: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
                profilePictureId: nil
            )
            viewModel.isSaving = false
            dismiss()
        } catch {
            viewModel.errorMessage = "Failed to update profile: \(error.localizedDescription)"
            viewModel.isSaving = false
        }
    }
}

@MainActor
class ProfileSettingsViewModel: ObservableObject {
    @Published var currentProfile: AppProfile?
    @Published var profilePicturePreview: UIImage?
    @Published var hasNewProfilePicture = false
    @Published var isUploadingProfilePicture = false
    @Published var isSaving = false
    @Published var usernameError = ""
    @Published var errorMessage: String?

    func loadProfile(profile: AppProfile) async {
        self.currentProfile = profile
    }

    func validateUsername(_ username: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            usernameError = "Username is required"
            return
        }

        if trimmed.count > 50 {
            usernameError = "Username must be 50 characters or less"
            return
        }

        // Check for valid characters (alphanumeric and underscore only)
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if trimmed.unicodeScalars.contains(where: { !validCharacters.contains($0) }) {
            usernameError = "Username can only contain letters, numbers, and underscores"
            return
        }

        usernameError = ""
    }

    func uploadProfilePicture(image: UIImage) async {
        guard currentProfile != nil else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        // Check file size (10MB limit)
        if imageData.count > 10 * 1024 * 1024 {
            errorMessage = "Image size must be under 10MB"
            return
        }

        isUploadingProfilePicture = true
        errorMessage = nil

        do {
            let result = try await ProfileService.shared.uploadProfilePicture(
                imageData: imageData,
                filename: "profile.jpg"
            )

            // Show preview
            profilePicturePreview = image
            hasNewProfilePicture = true

            print("Profile picture uploaded: \(result.url)")
        } catch {
            errorMessage = "Failed to upload profile picture: \(error.localizedDescription)"
            print("Failed to upload profile picture: \(error)")
        }

        isUploadingProfilePicture = false
    }

    func updateProfile(profileId: String, name: String, username: String, bio: String) async -> Bool {
        isSaving = true
        errorMessage = nil

        do {
            let request = ProfileUpdateRequest(
                name: name,
                username: username,
                bio: bio.isEmpty ? nil : bio,
                profilePictureId: nil
            )

            let updatedProfile = try await ProfileService.shared.updateProfile(profileId: profileId, request: request)
            self.currentProfile = updatedProfile
            isSaving = false
            return true
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            print("Failed to update profile: \(error)")
            isSaving = false
            return false
        }
    }
}

#Preview {
    ProfileSettingsView()
        .environmentObject(ProfileContext())
}
