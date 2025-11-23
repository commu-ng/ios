import SwiftUI

struct ProfileSwitcher: View {
    @EnvironmentObject var profileContext: ProfileContext

    @State private var showingPicker = false

    var body: some View {
        Button(action: {
            showingPicker = true
        }) {
            HStack(spacing: 6) {
                if let profile = profileContext.currentProfile {
                    CachedCircularImage(url: profile.avatarURL, size: 24)

                    Text(profile.name)
                        .font(.subheadline)
                        .lineLimit(1)
                } else {
                    Text(NSLocalizedString("Select Profile", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            ProfilePickerView()
        }
    }
}

struct ProfilePickerView: View {
    @EnvironmentObject var profileContext: ProfileContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if profileContext.isLoading {
                    ProgressView()
                        .padding()
                } else if profileContext.availableProfiles.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("No Profiles", comment: ""),
                        systemImage: "person.crop.circle",
                        description: Text(NSLocalizedString("You haven't created any profiles in this community yet.", comment: ""))
                    )
                } else {
                    List {
                        ForEach(profileContext.availableProfiles) { profile in
                            ProfilePickerRow(profile: profile)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task {
                                        await profileContext.switchProfile(to: profile)
                                        dismiss()
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("profile.switch_profile", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("Done", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProfilePickerRow: View {
    @EnvironmentObject var profileContext: ProfileContext
    let profile: AppProfile

    var isSelected: Bool {
        profileContext.currentProfileId == profile.id
    }

    var body: some View {
        HStack(spacing: 12) {
            CachedCircularImage(url: profile.avatarURL, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)

                Text("@\(profile.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if profile.isPrimary {
                Text(NSLocalizedString("profile.primary", comment: ""))
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProfileSwitcher()
        .environmentObject(ProfileContext())
}
