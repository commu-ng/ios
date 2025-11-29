import SwiftUI
import Kingfisher

struct CommunitiesTabView: View {
    @EnvironmentObject var communityContext: CommunityContext
    @EnvironmentObject var appModeContext: AppModeContext

    @State private var recruitingCommunities: [Community] = []
    @State private var ongoingCommunities: [Community] = []
    @State private var isLoadingBrowse = true
    @State private var browseErrorMessage: String?
    @State private var selectedCommunity: Community?
    @State private var applicationsForCommunity: Community?
    @State private var communityToEdit: Community?
    @State private var showCreateCommunity = false

    var body: some View {
        NavigationView {
            List {
                // My Communities Section
                if !communityContext.availableCommunities.isEmpty {
                    Section {
                        ForEach(communityContext.availableCommunities) { community in
                            MyCommunityRow(
                                community: community,
                                onApplicationsTapped: {
                                    applicationsForCommunity = community
                                },
                                onEditTapped: {
                                    communityToEdit = community
                                }
                            )
                                .onTapGesture {
                                    Task {
                                        await communityContext.switchCommunity(to: community)
                                        appModeContext.switchTo(.app)
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .foregroundColor(.purple)
                                Text(NSLocalizedString("communities.my_communities", comment: "My Communities"))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("(\(communityContext.availableCommunities.count))")
                                    .foregroundColor(.secondary)
                            }
                            Text(NSLocalizedString("communities.my_communities_description", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .textCase(nil)
                        .padding(.bottom, 8)
                    }
                }

                // Recruiting Communities Section
                if !recruitingCommunities.isEmpty {
                    Section {
                        ForEach(recruitingCommunities) { community in
                            BrowseCommunityCard(community: community, isRecruiting: true)
                                .onTapGesture {
                                    selectedCommunity = community
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.green)
                                Text(NSLocalizedString("browse.recruiting", comment: "Recruiting"))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("(\(recruitingCommunities.count))")
                                    .foregroundColor(.secondary)
                            }
                            Text(NSLocalizedString("browse.recruiting_description", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .textCase(nil)
                        .padding(.bottom, 8)
                    }
                }

                // Ongoing Communities Section
                if !ongoingCommunities.isEmpty {
                    Section {
                        ForEach(ongoingCommunities) { community in
                            BrowseCommunityCard(community: community, isRecruiting: false)
                                .onTapGesture {
                                    selectedCommunity = community
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "play.circle")
                                    .foregroundColor(.blue)
                                Text(NSLocalizedString("browse.ongoing", comment: "Ongoing"))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("(\(ongoingCommunities.count))")
                                    .foregroundColor(.secondary)
                            }
                            Text(NSLocalizedString("browse.ongoing_description", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .textCase(nil)
                        .padding(.bottom, 8)
                    }
                }

                // Loading state for browse
                if isLoadingBrowse {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                        .listRowSeparator(.hidden)
                    }
                }

                // Error state
                if let error = browseErrorMessage {
                    Section {
                        VStack(spacing: 12) {
                            Text(error)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button(NSLocalizedString("action.retry", comment: "")) {
                                Task {
                                    await loadBrowseCommunities()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(NSLocalizedString("nav.communities", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateCommunity = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .refreshable {
                await communityContext.loadCommunities()
                await loadBrowseCommunities()
            }
        }
        .task {
            await loadBrowseCommunities()
        }
        .sheet(item: $selectedCommunity) { community in
            CommunityDetailView(community: community) { selectedCommunity in
                Task {
                    await communityContext.switchCommunity(to: selectedCommunity)
                    appModeContext.switchTo(.app)
                }
            }
        }
        .sheet(item: $applicationsForCommunity) { community in
            ApplicationsListView(community: community)
        }
        .sheet(isPresented: $showCreateCommunity) {
            CommunityCreationView()
                .environmentObject(communityContext)
        }
        .sheet(item: $communityToEdit) { community in
            CommunityEditView(community: community)
                .environmentObject(communityContext)
        }
    }

    private func loadBrowseCommunities() async {
        isLoadingBrowse = true
        browseErrorMessage = nil

        do {
            async let recruiting = CommunityService.shared.getRecruitingCommunities()
            async let ongoing = CommunityService.shared.getOngoingCommunities()

            let (recruitingResult, ongoingResult) = try await (recruiting, ongoing)
            recruitingCommunities = recruitingResult
            ongoingCommunities = ongoingResult
        } catch {
            browseErrorMessage = error.localizedDescription
        }

        isLoadingBrowse = false
    }
}

struct MyCommunityRow: View {
    let community: Community
    var onApplicationsTapped: (() -> Void)?
    var onEditTapped: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Community Icon (first letter)
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Text(String(community.name.prefix(1)).uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name)
                        .font(.headline)

                    Text(community.slug)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Role badge
                if let role = community.role {
                    Text(role.capitalized)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(roleBadgeColor(for: role))
                        .cornerRadius(4)
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // Actions row
            HStack(spacing: 8) {
                // Pending applications badge
                if let pendingCount = community.pendingApplicationCount, pendingCount > 0 {
                    Button(action: {
                        onApplicationsTapped?()
                    }) {
                        Label(String(format: NSLocalizedString("communities.pending", comment: ""), pendingCount), systemImage: "person.badge.clock")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Edit button (only for owner)
                if community.role == "owner" {
                    Button(action: {
                        onEditTapped?()
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func roleBadgeColor(for role: String) -> Color {
        switch role.lowercased() {
        case "owner":
            return Color.red
        case "moderator":
            return Color.blue
        default:
            return Color.gray
        }
    }
}

struct BrowseCommunityCard: View {
    let community: Community
    let isRecruiting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner Image
            if let bannerURL = community.bannerURL {
                KFImage(bannerURL)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 120)
                            .overlay(ProgressView())
                    }
                    .fade(duration: 0.2)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 120)

                    Text(String(community.name.prefix(1)).uppercased())
                        .font(.system(size: 48))
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }

            // Community Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(community.name)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    if isRecruiting {
                        Label(NSLocalizedString("status.recruiting", comment: ""), systemImage: "person.badge.plus")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                }

                // Hashtags
                if !community.hashtags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(community.hashtags.prefix(3)) { hashtag in
                            Text("#\(hashtag.tag)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if community.hashtags.count > 3 {
                            Text("+\(community.hashtags.count - 3)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    CommunitiesTabView()
        .environmentObject(CommunityContext())
        .environmentObject(AppModeContext())
}
