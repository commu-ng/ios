import SwiftUI
import Combine

struct MemberDirectoryView: View {
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = MemberDirectoryViewModel()
    @State private var searchText = ""

    var filteredProfiles: [AppProfile] {
        if searchText.isEmpty {
            return viewModel.profiles
        }
        return viewModel.profiles.filter { profile in
            profile.name.localizedCaseInsensitiveContains(searchText) ||
            profile.username.localizedCaseInsensitiveContains(searchText) ||
            (profile.bio?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(NSLocalizedString("search.by_name", comment: ""), text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()

                // Content
                if viewModel.isLoading && viewModel.profiles.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.secondary)
                        Button(NSLocalizedString("action.retry", comment: "")) {
                            Task {
                                if let profileId = profileContext.currentProfileId {
                                    await viewModel.loadProfiles(profileId: profileId)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredProfiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: searchText.isEmpty ? "person.2" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? NSLocalizedString("members.no_members", comment: "") : NSLocalizedString("members.no_results", comment: ""))
                            .font(.headline)
                        if !searchText.isEmpty {
                            Text(String(format: NSLocalizedString("members.no_matches", comment: ""), searchText))
                                .foregroundColor(.secondary)
                            Button(NSLocalizedString("members.show_all", comment: "")) {
                                searchText = ""
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(filteredProfiles) { profile in
                                NavigationLink(destination: ProfileDetailView(username: profile.username).environmentObject(profileContext)) {
                                    ProfileCard(profile: profile)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()

                        // Results count
                        if !searchText.isEmpty {
                            Text(String(format: NSLocalizedString("search.results", comment: ""), filteredProfiles.count, searchText))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            Text(String(format: NSLocalizedString("members.total", comment: ""), viewModel.profiles.count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("members.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                if let profileId = profileContext.currentProfileId {
                    await viewModel.loadProfiles(profileId: profileId)
                }
            }
        }
        .task {
            if let profileId = profileContext.currentProfileId {
                await viewModel.loadProfiles(profileId: profileId)
            }
        }
    }
}

struct ProfileCard: View {
    let profile: AppProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Avatar
            HStack {
                Spacer()
                CachedCircularImage(url: profile.avatarURL, size: 60)
                Spacer()
            }

            // Name and username
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("@\(profile.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Bio
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)
            } else {
                Spacer()
                    .frame(height: 32)
            }

            // Join date
            HStack {
                Image(systemName: "calendar")
                    .font(.caption2)
                if let createdDate = profile.createdDate {
                    Text(createdDate, format: .dateTime.month().day().year())
                        .font(.caption2)
                } else {
                    Text(profile.createdAt)
                        .font(.caption2)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

@MainActor
class MemberDirectoryViewModel: ObservableObject {
    @Published var profiles: [AppProfile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadProfiles(profileId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedProfiles = try await ProfileService.shared.getAllProfiles(profileId: profileId)
            profiles = fetchedProfiles
        } catch {
            errorMessage = "Failed to load members: \(error.localizedDescription)"
            print("Failed to load profiles: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    MemberDirectoryView()
        .environmentObject(ProfileContext())
}
