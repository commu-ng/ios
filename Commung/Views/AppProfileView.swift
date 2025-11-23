import SwiftUI

struct AppProfileView: View {
    @EnvironmentObject var communityContext: CommunityContext
    @EnvironmentObject var profileContext: ProfileContext

    var body: some View {
        NavigationView {
            Group {
                if communityContext.currentCommunity == nil {
                    ContentUnavailableView(
                        NSLocalizedString("profile.no_profile", comment: ""),
                        systemImage: "person.3",
                        description: Text(NSLocalizedString("profile.select_community", comment: ""))
                    )
                } else if profileContext.currentProfile == nil {
                    ContentUnavailableView(
                        NSLocalizedString("profile.no_profile", comment: ""),
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text(NSLocalizedString("loading.default", comment: ""))
                    )
                } else {
                    AppProfileContent()
                }
            }
            .navigationTitle(NSLocalizedString("profile.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileSwitcher()
                }
            }
        }
    }
}

struct AppProfileContent: View {
    @EnvironmentObject var communityContext: CommunityContext
    @EnvironmentObject var profileContext: ProfileContext
    @State private var showingProfileSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                if let profile = profileContext.currentProfile {
                    VStack(spacing: 12) {
                        CachedCircularImage(url: profile.avatarURL, size: 100)

                        Text(profile.name)
                            .font(.title)
                            .fontWeight(.bold)

                        Text("@\(profile.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let bio = profile.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        if profile.isPrimary {
                            Label(NSLocalizedString("profile.primary", comment: ""), systemImage: "star.fill")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }

                        Button {
                            showingProfileSettings = true
                        } label: {
                            Label(NSLocalizedString("profile.edit", comment: ""), systemImage: "pencil")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }

                // Community Info
                if let community = communityContext.currentCommunity {
                    HStack(spacing: 12) {
                        // Use first letter as placeholder since communities don't have icons
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 40, height: 40)

                            Text(String(community.name.prefix(1)).uppercased())
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(community.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(NSLocalizedString("profile.current_community", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Divider()

                // Quick Actions
                VStack(spacing: 0) {
                    NavigationLink(destination: BookmarksView().environmentObject(profileContext)) {
                        HStack {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(NSLocalizedString("profile.bookmarks", comment: ""))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }

                    Divider()
                        .padding(.leading, 44)

                    NavigationLink(destination: SearchView().environmentObject(profileContext)) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(NSLocalizedString("profile.search_posts", comment: ""))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }

                    Divider()
                        .padding(.leading, 44)

                    NavigationLink(destination: ScheduledPostsView().environmentObject(profileContext)) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(NSLocalizedString("profile.scheduled_posts", comment: ""))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }

                    Divider()
                        .padding(.leading, 44)

                    NavigationLink(destination: AnnouncementsView().environmentObject(profileContext)) {
                        HStack {
                            Image(systemName: "megaphone.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text(NSLocalizedString("announcements.title", comment: ""))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer(minLength: 20)
            }
        }
        .refreshable {
            if let communityId = communityContext.currentCommunityId {
                await profileContext.loadProfiles(for: communityId)
            }
        }
        .sheet(isPresented: $showingProfileSettings) {
            ProfileSettingsView()
                .environmentObject(profileContext)
        }
    }
}

#Preview {
    AppProfileView()
        .environmentObject(CommunityContext())
        .environmentObject(ProfileContext())
}
