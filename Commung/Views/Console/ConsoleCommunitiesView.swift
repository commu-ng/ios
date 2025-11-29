import SwiftUI

struct ConsoleCommunitiesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var communityContext: CommunityContext
    @EnvironmentObject var profileContext: ProfileContext
    @EnvironmentObject var appModeContext: AppModeContext

    @State private var showCreateCommunity = false
    @State private var communityToEdit: Community?

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
                                    ConsoleCommunityCard(
                                        community: community,
                                        onEditTap: {
                                            communityToEdit = community
                                        }
                                    )
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateCommunity = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .refreshable {
                await communityContext.loadCommunities()
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
    }
}

struct ConsoleCommunityCard: View {
    let community: Community
    var onEditTap: (() -> Void)?

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

            // Actions row
            HStack(spacing: 8) {
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

                Spacer()

                // Edit button
                Button {
                    onEditTap?()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
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

