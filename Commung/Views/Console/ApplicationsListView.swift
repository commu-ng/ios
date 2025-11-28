import SwiftUI

struct ApplicationsListView: View {
    let community: Community
    @Environment(\.dismiss) private var dismiss
    @State private var applications: [CommunityApplicationDetail] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedApplication: CommunityApplicationDetail?

    var pendingApplications: [CommunityApplicationDetail] {
        applications.filter { $0.status == "pending" }
    }

    var reviewedApplications: [CommunityApplicationDetail] {
        applications.filter { $0.status != "pending" }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button(NSLocalizedString("action.retry", comment: "")) {
                            Task {
                                await loadApplications()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if applications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("applications.empty", comment: "No applications"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("applications.empty_description", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        // Pending Applications Section
                        if !pendingApplications.isEmpty {
                            Section {
                                ForEach(pendingApplications) { application in
                                    ApplicationRow(application: application)
                                        .onTapGesture {
                                            selectedApplication = application
                                        }
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.orange)
                                    Text(NSLocalizedString("applications.pending", comment: "Pending"))
                                        .font(.headline)
                                    Text("(\(pendingApplications.count))")
                                        .foregroundColor(.secondary)
                                }
                                .textCase(nil)
                            }
                        }

                        // Reviewed Applications Section
                        if !reviewedApplications.isEmpty {
                            Section {
                                ForEach(reviewedApplications) { application in
                                    ApplicationRow(application: application)
                                        .onTapGesture {
                                            selectedApplication = application
                                        }
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.blue)
                                    Text(NSLocalizedString("applications.reviewed", comment: "Reviewed"))
                                        .font(.headline)
                                    Text("(\(reviewedApplications.count))")
                                        .foregroundColor(.secondary)
                                }
                                .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await loadApplications()
                    }
                }
            }
            .navigationTitle(NSLocalizedString("applications.title", comment: "Applications"))
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
            await loadApplications()
        }
        .sheet(item: $selectedApplication) { application in
            ApplicationDetailView(
                community: community,
                application: application,
                onReviewed: {
                    Task {
                        await loadApplications()
                    }
                }
            )
        }
    }

    private func loadApplications() async {
        isLoading = true
        errorMessage = nil

        do {
            applications = try await CommunityService.shared.getCommunityApplications(slug: community.slug)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct ApplicationRow: View {
    let application: CommunityApplicationDetail

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)

                Text(String(application.profileName.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(application.profileName)
                        .font(.headline)

                    statusBadge
                }

                Text("@\(application.profileUsername)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(formatDate(application.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
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
}

struct ApplicationDetailView: View {
    let community: Community
    let application: CommunityApplicationDetail
    var onReviewed: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var isApproving = false
    @State private var isRejecting = false
    @State private var showRejectDialog = false
    @State private var rejectionReason = ""
    @State private var errorMessage: String?

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

                        // Reviewed Date (if reviewed)
                        if let reviewedAt = application.reviewedAt {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.secondary)
                                Text(NSLocalizedString("applications.reviewed_on", comment: "Reviewed on"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatDate(reviewedAt))
                            }
                            .font(.subheadline)
                        }
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

                    // Action Buttons (only for pending)
                    if application.status == "pending" {
                        VStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    await approveApplication()
                                }
                            }) {
                                HStack {
                                    if isApproving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    }
                                    Text(isApproving ? NSLocalizedString("applications.approving", comment: "") : NSLocalizedString("applications.approve", comment: "Approve"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isApproving || isRejecting)

                            Button(action: {
                                showRejectDialog = true
                            }) {
                                Text(NSLocalizedString("applications.reject", comment: "Reject"))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(12)
                            }
                            .disabled(isApproving || isRejecting)
                        }
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
        .alert(NSLocalizedString("applications.reject_title", comment: "Reject Application"), isPresented: $showRejectDialog) {
            TextField(NSLocalizedString("applications.rejection_reason_placeholder", comment: ""), text: $rejectionReason)
            Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("applications.reject", comment: ""), role: .destructive) {
                Task {
                    await rejectApplication()
                }
            }
        } message: {
            Text(NSLocalizedString("applications.reject_message", comment: ""))
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

    private func approveApplication() async {
        isApproving = true
        errorMessage = nil

        do {
            _ = try await CommunityService.shared.approveApplication(
                slug: community.slug,
                applicationId: application.id
            )
            onReviewed?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isApproving = false
    }

    private func rejectApplication() async {
        isRejecting = true
        errorMessage = nil

        do {
            _ = try await CommunityService.shared.rejectApplication(
                slug: community.slug,
                applicationId: application.id,
                reason: rejectionReason.isEmpty ? nil : rejectionReason
            )
            onReviewed?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isRejecting = false
    }
}

#Preview {
    ApplicationsListView(community: Community(
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
        role: "owner",
        customDomain: nil,
        domainVerified: nil,
        bannerImageUrl: nil,
        bannerImageWidth: nil,
        bannerImageHeight: nil,
        hashtags: [],
        ownerProfileId: nil,
        pendingApplicationCount: 5
    ))
}
