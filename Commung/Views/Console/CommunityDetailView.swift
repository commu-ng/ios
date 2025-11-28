import SwiftUI
import Kingfisher

struct CommunityDetailView: View {
    let community: Community
    var onSwitchToApp: ((Community) -> Void)?
    @EnvironmentObject var communityContext: CommunityContext
    @State private var details: CommunityDetails?
    @State private var links: [CommunityLink] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showApplicationView = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var isMember: Bool {
        communityContext.availableCommunities.contains { $0.id == community.id }
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
                                await loadDetails()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if let details = details {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Banner Image
                            if let bannerURL = details.bannerURL {
                                GeometryReader { geo in
                                    KFImage(bannerURL)
                                        .placeholder {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .overlay(ProgressView())
                                        }
                                        .fade(duration: 0.2)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geo.size.width, height: 200)
                                        .clipped()
                                }
                                .frame(height: 200)
                            }

                            VStack(alignment: .leading, spacing: 16) {
                                // Title and Status
                                HStack {
                                    Text(details.name)
                                        .font(.title)
                                        .fontWeight(.bold)

                                    Spacer()

                                    if details.isRecruiting {
                                        Label(NSLocalizedString("status.recruiting", comment: ""), systemImage: "person.badge.plus")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.green)
                                            .cornerRadius(6)
                                    }
                                }

                                // Hashtags
                                if !details.hashtags.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(details.hashtags) { hashtag in
                                            Text("#\(hashtag.tag)")
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(6)
                                        }
                                    }
                                }

                                // Description
                                if let description = details.description, !description.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(NSLocalizedString("community.description", comment: "Description"))
                                            .font(.headline)

                                        Text(description)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }

                                // Apply Button (if recruiting and not a member)
                                if details.isRecruiting && details.membershipStatus != "member" {
                                    Button(action: {
                                        showApplicationView = true
                                    }) {
                                        Label(NSLocalizedString("community.apply", comment: "Apply to join"), systemImage: "person.badge.plus")
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                    }
                                }

                                // Links Section
                                if !links.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(NSLocalizedString("community.links", comment: "Links"))
                                            .font(.headline)

                                        ForEach(links) { link in
                                            Button(action: {
                                                if let url = URL(string: link.url) {
                                                    openURL(url)
                                                }
                                            }) {
                                                HStack {
                                                    Image(systemName: "link")
                                                        .foregroundColor(.blue)

                                                    VStack(alignment: .leading) {
                                                        Text(link.title)
                                                            .font(.subheadline)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.primary)

                                                        Text(link.url)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(1)
                                                    }

                                                    Spacer()

                                                    Image(systemName: "arrow.up.right.square")
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding()
                                                .background(Color(.systemGray6))
                                                .cornerRadius(10)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                // Visit Community Button (only for members)
                                if isMember {
                                    Button(action: {
                                        dismiss()
                                        onSwitchToApp?(community)
                                    }) {
                                        Label(NSLocalizedString("community.visit", comment: "Visit Community"), systemImage: "arrow.right.circle")
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle(community.name)
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
            await loadDetails()
        }
        .sheet(isPresented: $showApplicationView) {
            CommunityApplicationView(community: community)
        }
    }

    private func loadDetails() async {
        isLoading = true
        errorMessage = nil

        do {
            async let detailsTask = CommunityService.shared.getCommunityDetails(slug: community.slug)
            async let linksTask = CommunityService.shared.getCommunityLinks(slug: community.slug)

            let (detailsResult, linksResult) = try await (detailsTask, linksTask)
            details = detailsResult
            links = linksResult
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    CommunityDetailView(community: Community(
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
