import PhotosUI
import SwiftUI

struct CommunityCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var communityContext: CommunityContext

    // Form fields
    @State private var name = ""
    @State private var slug = ""
    @State private var profileName = ""
    @State private var profileUsername = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var isRecruiting = false
    @State private var recruitingStartDate: Date?
    @State private var recruitingEndDate: Date?
    @State private var minimumBirthYear: String = ""
    @State private var muteNewMembers = false

    // Image upload state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var uploadedImageId: String?
    @State private var isUploadingImage = false

    // UI State
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var createdCommunity: CommunityCreateResponse?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
            !slug.trimmingCharacters(in: .whitespaces).isEmpty &&
            !profileName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !profileUsername.trimmingCharacters(in: .whitespaces).isEmpty &&
            isValidSlug(slug) &&
            startDate < endDate &&
            !isUploadingImage
    }

    private func isValidSlug(_ slug: String) -> Bool {
        let pattern = "^[a-z0-9]+(-[a-z0-9]+)*$"
        return slug.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationView {
            Group {
                if showSuccess {
                    successView
                } else {
                    formView
                }
            }
            .navigationTitle(NSLocalizedString("community.create.title", comment: "Create Community"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var formView: some View {
        Form {
            // Basic Info Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("community.create.name", comment: "Community Name"))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField(NSLocalizedString("community.create.name.placeholder", comment: ""), text: $name)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isSubmitting)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("community.create.slug", comment: "Community ID"))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField(NSLocalizedString("community.create.slug.placeholder", comment: ""), text: $slug)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(isSubmitting)
                        .onChange(of: slug) { _, newValue in
                            slug = formatSlug(newValue)
                        }

                    Text("\(slug.isEmpty ? "example" : slug).commu.ng")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !slug.isEmpty && !isValidSlug(slug) {
                        Text(NSLocalizedString("community.create.slug.invalid", comment: ""))
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            } header: {
                Text(NSLocalizedString("community.create.section.basic", comment: "Basic Info"))
            }

            // Banner Image Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if let image = selectedImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(8)

                            if isUploadingImage {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(20)
                                    .padding(8)
                            } else {
                                Button(action: {
                                    selectedImage = nil
                                    selectedPhotoItem = nil
                                    uploadedImageId = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .padding(8)
                            }
                        }

                        if isUploadingImage {
                            Text(NSLocalizedString("community.create.image.uploading", comment: "Uploading..."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: selectedImage == nil ? "photo.badge.plus" : "arrow.triangle.2.circlepath")
                            Text(
                                selectedImage == nil
                                    ? NSLocalizedString("community.create.image.select", comment: "Select Image")
                                    : NSLocalizedString("community.create.image.change", comment: "Change Image")
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .disabled(isSubmitting || isUploadingImage)
                }
            } header: {
                Text(NSLocalizedString("community.create.section.image", comment: "Banner Image"))
            }

            // Owner Profile Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("community.create.profile.name", comment: "Profile Name"))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField(NSLocalizedString("community.create.profile.name.placeholder", comment: ""), text: $profileName)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isSubmitting)

                    Text(NSLocalizedString("community.create.profile.name.hint", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("community.create.profile.username", comment: "Profile ID"))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField(NSLocalizedString("community.create.profile.username.placeholder", comment: ""), text: $profileUsername)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(isSubmitting)
                        .onChange(of: profileUsername) { _, newValue in
                            profileUsername = newValue
                                .replacingOccurrences(of: " ", with: "_")
                                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                        }

                    Text("@\(profileUsername.isEmpty ? "username" : profileUsername)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(NSLocalizedString("community.create.section.profile", comment: "Owner Profile"))
            } footer: {
                Text(NSLocalizedString("community.create.section.profile.footer", comment: ""))
            }

            // Schedule Section
            Section {
                DatePicker(
                    NSLocalizedString("community.create.start_date", comment: "Start Date"),
                    selection: $startDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(isSubmitting)

                DatePicker(
                    NSLocalizedString("community.create.end_date", comment: "End Date"),
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(isSubmitting)

                if startDate >= endDate {
                    Text(NSLocalizedString("community.create.date.invalid", comment: ""))
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } header: {
                Text(NSLocalizedString("community.create.section.schedule", comment: "Schedule"))
            }

            // Recruitment Section
            Section {
                Toggle(
                    NSLocalizedString("community.create.recruiting", comment: "Public Recruiting"),
                    isOn: $isRecruiting
                )
                .disabled(isSubmitting)
                .onChange(of: isRecruiting) { _, newValue in
                    if newValue {
                        // Initialize recruiting dates when enabling recruiting
                        recruitingStartDate = Date()
                        recruitingEndDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
                    } else {
                        recruitingStartDate = nil
                        recruitingEndDate = nil
                    }
                }

                if isRecruiting {
                    DatePicker(
                        NSLocalizedString("community.create.recruiting.start", comment: "Recruiting Start"),
                        selection: Binding(
                            get: { recruitingStartDate ?? Date() },
                            set: { recruitingStartDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .disabled(isSubmitting)

                    DatePicker(
                        NSLocalizedString("community.create.recruiting.end", comment: "Recruiting End"),
                        selection: Binding(
                            get: { recruitingEndDate ?? Date() },
                            set: { recruitingEndDate = $0 }
                        ),
                        in: (recruitingStartDate ?? Date())...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .disabled(isSubmitting)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("community.create.min_birth_year", comment: "Minimum Birth Year"))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField(
                            NSLocalizedString("community.create.min_birth_year.placeholder", comment: "e.g., 2005"),
                            text: $minimumBirthYear
                        )
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .disabled(isSubmitting)

                        Text(NSLocalizedString("community.create.min_birth_year.hint", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("community.create.section.recruiting", comment: "Recruitment"))
            }

            // Settings Section
            Section {
                Toggle(
                    NSLocalizedString("community.create.mute_new_members", comment: "Mute New Members"),
                    isOn: $muteNewMembers
                )
                .disabled(isSubmitting)
            } header: {
                Text(NSLocalizedString("community.create.section.settings", comment: "Settings"))
            } footer: {
                Text(NSLocalizedString("community.create.mute_new_members.hint", comment: ""))
            }

            // Error Message
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
            }

            // Submit Button
            Section {
                Button(action: {
                    Task {
                        await createCommunity()
                    }
                }) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(
                            isSubmitting
                                ? NSLocalizedString("community.create.creating", comment: "Creating...")
                                : NSLocalizedString("community.create.submit", comment: "Create Community")
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid && !isSubmitting ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isFormValid || isSubmitting)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            print("[CommunityCreation] onChange triggered, newValue: \(String(describing: newValue))")
            Task {
                if let item = newValue {
                    print("[CommunityCreation] Starting image upload...")
                    await loadAndUploadImage(from: item)
                }
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text(NSLocalizedString("community.create.success.title", comment: "Community Created"))
                .font(.title2)
                .fontWeight(.bold)

            if let community = createdCommunity {
                VStack(spacing: 8) {
                    Text(community.name)
                        .font(.headline)
                    Text("\(community.domain).commu.ng")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Text(NSLocalizedString("community.create.success.message", comment: ""))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                Task {
                    await communityContext.loadCommunities()
                }
                dismiss()
            }) {
                Text(NSLocalizedString("action.done", comment: "Done"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 20)
        }
        .padding()
    }

    private func formatSlug(_ input: String) -> String {
        var result = input
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        // Remove consecutive hyphens
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }

        // Remove leading/trailing hyphens
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return result
    }

    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func loadAndUploadImage(from item: PhotosPickerItem?) async {
        guard let item = item else {
            print("[CommunityCreation] loadAndUploadImage: item is nil")
            return
        }

        print("[CommunityCreation] loadAndUploadImage: starting...")
        isUploadingImage = true
        errorMessage = nil

        do {
            print("[CommunityCreation] Loading transferable data...")
            guard let data = try await item.loadTransferable(type: Data.self) else {
                print("[CommunityCreation] Failed to load data from PhotosPickerItem")
                isUploadingImage = false
                return
            }
            print("[CommunityCreation] Data loaded, size: \(data.count) bytes")

            // Create UIImage for preview
            if let image = UIImage(data: data) {
                print("[CommunityCreation] UIImage created: \(image.size)")
                selectedImage = image
            }

            print("[CommunityCreation] Uploading to server...")
            let response = try await CommunityService.shared.uploadImage(imageData: data, fileName: "banner.jpg")
            print("[CommunityCreation] Upload successful, id: \(response.id)")
            uploadedImageId = response.id
        } catch {
            print("[CommunityCreation] Error: \(error)")
            errorMessage = error.localizedDescription
            selectedImage = nil
            selectedPhotoItem = nil
        }

        isUploadingImage = false
    }

    private func createCommunity() async {
        isSubmitting = true
        errorMessage = nil

        let request = CommunityCreateRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            slug: slug.trimmingCharacters(in: .whitespaces),
            startsAt: formatDateForAPI(startDate),
            endsAt: formatDateForAPI(endDate),
            isRecruiting: isRecruiting,
            recruitingStartsAt: recruitingStartDate.map { formatDateForAPI($0) },
            recruitingEndsAt: recruitingEndDate.map { formatDateForAPI($0) },
            minimumBirthYear: Int(minimumBirthYear),
            imageId: uploadedImageId,
            hashtags: nil,
            profileUsername: profileUsername.trimmingCharacters(in: .whitespaces),
            profileName: profileName.trimmingCharacters(in: .whitespaces),
            description: nil,
            muteNewMembers: muteNewMembers
        )

        do {
            let response = try await CommunityService.shared.createCommunity(request: request)
            createdCommunity = response
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}

#Preview {
    CommunityCreationView()
        .environmentObject(CommunityContext())
}
