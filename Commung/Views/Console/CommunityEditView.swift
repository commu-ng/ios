import PhotosUI
import SwiftUI

struct CommunityEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var communityContext: CommunityContext

    let community: Community

    // Form fields
    @State private var name: String
    @State private var slug: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isRecruiting: Bool
    @State private var recruitingStartDate: Date?
    @State private var recruitingEndDate: Date?
    @State private var minimumBirthYear: String
    @State private var muteNewMembers: Bool

    // Image upload state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var uploadedImageId: String?
    @State private var isUploadingImage = false

    // UI State
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var showDeleteConfirmation = false
    @State private var deleteConfirmSlug = ""
    @State private var isDeleting = false
    @State private var showDeleteSuccess = false

    init(community: Community) {
        self.community = community

        // Initialize state from community
        _name = State(initialValue: community.name)
        _slug = State(initialValue: community.slug)
        _startDate = State(initialValue: Self.parseDate(community.startsAt) ?? Date())
        _endDate = State(initialValue: Self.parseDate(community.endsAt) ?? Date())
        _isRecruiting = State(initialValue: community.isRecruiting)
        _recruitingStartDate = State(initialValue: community.recruitingStartsAt.flatMap { Self.parseDate($0) })
        _recruitingEndDate = State(initialValue: community.recruitingEndsAt.flatMap { Self.parseDate($0) })
        _minimumBirthYear = State(initialValue: community.minimumBirthYear.map { String($0) } ?? "")
        _muteNewMembers = State(initialValue: false) // Will be loaded separately if needed
    }

    private static func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
            !slug.trimmingCharacters(in: .whitespaces).isEmpty &&
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
                if showDeleteSuccess {
                    deleteSuccessView
                } else if showSuccess {
                    successView
                } else {
                    formView
                }
            }
            .navigationTitle(NSLocalizedString("community.edit.title", comment: "Edit Community"))
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
                    } else if let bannerURL = community.bannerURL {
                        // Show existing banner
                        AsyncImage(url: bannerURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(8)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 120)
                                .cornerRadius(8)
                                .overlay(ProgressView())
                        }
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: selectedImage == nil && community.bannerURL == nil ? "photo.badge.plus" : "arrow.triangle.2.circlepath")
                            Text(
                                selectedImage == nil && community.bannerURL == nil
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
                        await updateCommunity()
                    }
                }) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(
                            isSubmitting
                                ? NSLocalizedString("community.edit.saving", comment: "Saving...")
                                : NSLocalizedString("community.edit.save", comment: "Save Changes")
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

            // Danger Zone Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("community.delete.warning", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text(NSLocalizedString("community.delete.button", comment: "Delete Community"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSubmitting || isDeleting)
                }
                .padding(.horizontal)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text(NSLocalizedString("community.delete.section", comment: "Danger Zone"))
                    .foregroundColor(.red)
            }
        }
        .alert(NSLocalizedString("community.delete.confirm.title", comment: "Delete Community"), isPresented: $showDeleteConfirmation) {
            TextField(NSLocalizedString("community.delete.confirm.placeholder", comment: ""), text: $deleteConfirmSlug)
            Button(NSLocalizedString("action.cancel", comment: "Cancel"), role: .cancel) {
                deleteConfirmSlug = ""
            }
            Button(NSLocalizedString("community.delete.confirm.button", comment: "Delete"), role: .destructive) {
                Task {
                    await deleteCommunity()
                }
            }
            .disabled(deleteConfirmSlug != community.slug)
        } message: {
            Text(String(format: NSLocalizedString("community.delete.confirm.message", comment: ""), community.slug))
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                if let item = newValue {
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

            Text(NSLocalizedString("community.edit.success.title", comment: "Changes Saved"))
                .font(.title2)
                .fontWeight(.bold)

            Text(NSLocalizedString("community.edit.success.message", comment: ""))
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

    private var deleteSuccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text(NSLocalizedString("community.delete.success.title", comment: "Community Deleted"))
                .font(.title2)
                .fontWeight(.bold)

            Text(NSLocalizedString("community.delete.success.message", comment: ""))
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

        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }

        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return result
    }

    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func loadAndUploadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        isUploadingImage = true
        errorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                isUploadingImage = false
                return
            }

            if let image = UIImage(data: data) {
                selectedImage = image
            }

            let response = try await CommunityService.shared.uploadImage(imageData: data, fileName: "banner.jpg")
            uploadedImageId = response.id
        } catch {
            errorMessage = error.localizedDescription
            selectedImage = nil
            selectedPhotoItem = nil
        }

        isUploadingImage = false
    }

    private func updateCommunity() async {
        isSubmitting = true
        errorMessage = nil

        let request = CommunityUpdateRequest(
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
            description: nil,
            muteNewMembers: muteNewMembers
        )

        do {
            _ = try await CommunityService.shared.updateCommunity(communityId: community.id, request: request)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private func deleteCommunity() async {
        isDeleting = true
        errorMessage = nil

        do {
            try await CommunityService.shared.deleteCommunity(communityId: community.id)
            deleteConfirmSlug = ""
            showDeleteSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isDeleting = false
    }
}

#Preview {
    CommunityEditView(community: Community(
        id: "1",
        name: "Test Community",
        slug: "test",
        startsAt: "2024-01-01T00:00:00.000Z",
        endsAt: "2024-12-31T23:59:59.000Z",
        isRecruiting: true,
        recruitingStartsAt: nil,
        recruitingEndsAt: nil,
        minimumBirthYear: nil,
        createdAt: "2024-01-01T00:00:00.000Z",
        role: "owner",
        customDomain: nil,
        domainVerified: nil,
        bannerImageUrl: nil,
        bannerImageWidth: nil,
        bannerImageHeight: nil,
        hashtags: [],
        ownerProfileId: nil,
        pendingApplicationCount: nil
    ))
    .environmentObject(CommunityContext())
}
