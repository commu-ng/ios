import SwiftUI

struct CommunityApplicationView: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss

    @State private var profileName = ""
    @State private var profileUsername = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var existingApplications: [CommunityApplication] = []
    @State private var isLoadingApplications = true
    @State private var selectedApplication: CommunityApplication?

    private var isFormValid: Bool {
        !profileName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !profileUsername.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasPendingApplication: Bool {
        existingApplications.contains { $0.status == "pending" }
    }

    var body: some View {
        NavigationView {
            Group {
                if showSuccess {
                    successView
                } else if isLoadingApplications {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Community Header
                            communityHeader

                            // Existing Applications
                            if !existingApplications.isEmpty {
                                existingApplicationsSection
                            }

                            // Application Form (only if no pending application)
                            if !hasPendingApplication {
                                applicationForm
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(NSLocalizedString("application.title", comment: "Apply to Join"))
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
        .task {
            await loadExistingApplications()
        }
        .sheet(item: $selectedApplication) { application in
            MyApplicationDetailView(application: application)
        }
    }

    private var communityHeader: some View {
        VStack(alignment: .center, spacing: 12) {
            Text(community.name)
                .font(.title2)
                .fontWeight(.bold)

            Text("@\(community.slug)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var existingApplicationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("application.my_applications", comment: "My Applications"))
                .font(.headline)

            ForEach(existingApplications) { application in
                Button(action: {
                    selectedApplication = application
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(application.profileName) (@\(application.profileUsername))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Spacer()

                                statusBadge(for: application.status)
                            }

                            if let rejectionReason = application.rejectionReason {
                                Text(NSLocalizedString("application.rejection_reason", comment: "Rejection reason") + ": \(rejectionReason)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .lineLimit(1)
                            }

                            Text(formatDate(application.createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var applicationForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !existingApplications.isEmpty {
                Text(NSLocalizedString("application.reapply", comment: "Apply Again"))
                    .font(.headline)
            } else {
                Text(NSLocalizedString("application.form_title", comment: "Application Form"))
                    .font(.headline)
            }

            Text(NSLocalizedString("application.form_description", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Profile Name
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("application.profile_name", comment: "Profile Name"))
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField(NSLocalizedString("application.profile_name_placeholder", comment: ""), text: $profileName)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isSubmitting)

                Text(NSLocalizedString("application.profile_name_hint", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Profile Username
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("application.profile_username", comment: "Profile ID"))
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField(NSLocalizedString("application.profile_username_placeholder", comment: ""), text: $profileUsername)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .disabled(isSubmitting)
                    .onChange(of: profileUsername) { _, newValue in
                        // Only allow alphanumeric and underscore
                        let filtered = newValue
                            .replacingOccurrences(of: " ", with: "_")
                            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                        if filtered != newValue {
                            profileUsername = filtered
                        }
                    }

                Text("@\(profileUsername.isEmpty ? "username" : profileUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Message (Optional)
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("application.message", comment: "Message (Optional)"))
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextEditor(text: $message)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .disabled(isSubmitting)

                Text(NSLocalizedString("application.message_hint", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            // Submit Button
            Button(action: {
                Task {
                    await submitApplication()
                }
            }) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isSubmitting ? NSLocalizedString("application.submitting", comment: "Submitting...") : NSLocalizedString("application.submit", comment: "Submit Application"))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid && !isSubmitting ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || isSubmitting)
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text(NSLocalizedString("application.success_title", comment: "Application Submitted"))
                .font(.title2)
                .fontWeight(.bold)

            Text(NSLocalizedString("application.success_message", comment: ""))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { dismiss() }) {
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

    @ViewBuilder
    private func statusBadge(for status: String) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case "pending":
                return (NSLocalizedString("application.status_pending", comment: "Pending"), .orange)
            case "approved":
                return (NSLocalizedString("application.status_approved", comment: "Approved"), .green)
            case "rejected":
                return (NSLocalizedString("application.status_rejected", comment: "Rejected"), .red)
            default:
                return (status, .gray)
            }
        }()

        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(4)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    private func loadExistingApplications() async {
        isLoadingApplications = true
        do {
            existingApplications = try await CommunityService.shared.getMyApplications(slug: community.slug)
        } catch {
            // Ignore error, just show empty
            existingApplications = []
        }
        isLoadingApplications = false
    }

    private func submitApplication() async {
        isSubmitting = true
        errorMessage = nil

        do {
            _ = try await CommunityService.shared.applyToCommunity(
                slug: community.slug,
                profileName: profileName.trimmingCharacters(in: .whitespaces),
                profileUsername: profileUsername.trimmingCharacters(in: .whitespaces),
                message: message.isEmpty ? nil : message
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}

struct MyApplicationDetailView: View {
    let application: CommunityApplication
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Applicant Info Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 60, height: 60)

                                Text(String(application.profileName.prefix(1)).uppercased())
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(application.profileName)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text("@\(application.profileUsername)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            statusBadge
                        }

                        Divider()

                        // Application Date
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("applications.applied_on", comment: "Applied on"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(application.createdAt))
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Message Section
                    if let message = application.message, !message.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("applications.message", comment: "Message"))
                                .font(.headline)

                            Text(message)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Rejection Reason (if rejected)
                    if application.status == "rejected", let reason = application.rejectionReason, !reason.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("applications.rejection_reason_label", comment: "Rejection Reason"))
                                .font(.headline)
                                .foregroundColor(.red)

                            Text(reason)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("applications.detail_title", comment: "Application"))
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

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch application.status {
            case "pending":
                return (NSLocalizedString("application.status_pending", comment: ""), .orange)
            case "approved":
                return (NSLocalizedString("application.status_approved", comment: ""), .green)
            case "rejected":
                return (NSLocalizedString("application.status_rejected", comment: ""), .red)
            default:
                return (application.status, .gray)
            }
        }()

        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(6)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

#Preview {
    CommunityApplicationView(community: Community(
        id: "1",
        name: "Test Community",
        slug: "test",
        startsAt: "2024-01-01",
        endsAt: "2024-12-31",
        isRecruiting: true,
        recruitingStartsAt: nil,
        recruitingEndsAt: nil,
        minimumBirthYear: nil,
        createdAt: "2024-01-01",
        role: nil,
        customDomain: nil,
        domainVerified: nil,
        bannerImageUrl: nil,
        bannerImageWidth: nil,
        bannerImageHeight: nil,
        hashtags: [],
        ownerProfileId: nil,
        pendingApplicationCount: nil
    ))
}
