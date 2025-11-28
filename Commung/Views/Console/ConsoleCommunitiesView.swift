import SwiftUI

struct ConsoleCommunitiesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var communityContext: CommunityContext
    @EnvironmentObject var profileContext: ProfileContext
    @EnvironmentObject var appModeContext: AppModeContext

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Communities Section
                    VStack(alignment: .leading, spacing: 12) {

                        if communityContext.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if let error = communityContext.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.subheadline)
                                .padding()
                        } else if communityContext.availableCommunities.isEmpty {
                            ContentUnavailableView(
                                NSLocalizedString("communities.no_communities", comment: "No communities"),
                                systemImage: "person.3",
                                description: Text(NSLocalizedString("communities.join_message", comment: ""))
                            )
                            .padding()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(communityContext.availableCommunities) { community in
                                    ConsoleCommunityCard(community: community)
                                    .onTapGesture {
                                        Task {
                                            await communityContext.switchCommunity(to: community)
                                            // Switch to App mode after selecting a community
                                            appModeContext.switchTo(.app)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle(NSLocalizedString("nav.communities", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await communityContext.loadCommunities()
            }
        }
    }
}

struct ConsoleCommunityCard: View {
    let community: Community

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Use first letter as placeholder since communities don't have icons
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

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // Pending applications badge
            if let pendingCount = community.pendingApplicationCount, pendingCount > 0 {
                Label(String(format: NSLocalizedString("communities.pending", comment: ""), pendingCount), systemImage: "person.badge.clock")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ConsoleCommunitiesView()
        .environmentObject(AuthViewModel())
        .environmentObject(CommunityContext())
        .environmentObject(ProfileContext())
        .environmentObject(AppModeContext())
}
