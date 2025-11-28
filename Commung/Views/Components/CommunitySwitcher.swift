import SwiftUI
import Kingfisher

struct CommunitySwitcher: View {
    @EnvironmentObject var communityContext: CommunityContext

    @State private var showingPicker = false

    var body: some View {
        Button(action: {
            showingPicker = true
        }) {
            HStack(spacing: 6) {
                if let community = communityContext.currentCommunity {
                    Text(community.name)
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    Text(NSLocalizedString("Select Community", comment: ""))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            CommunityPickerView()
        }
    }
}

struct CommunityPickerView: View {
    @EnvironmentObject var communityContext: CommunityContext
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var filteredCommunities: [Community] {
        if searchText.isEmpty {
            return communityContext.availableCommunities
        }
        return communityContext.availableCommunities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.slug.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if communityContext.isLoading {
                    ProgressView()
                        .padding()
                } else if communityContext.availableCommunities.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("No Communities", comment: ""),
                        systemImage: "person.3",
                        description: Text(NSLocalizedString("You haven't joined any communities yet.", comment: ""))
                    )
                } else {
                    List {
                        ForEach(filteredCommunities) { community in
                            CommunityRow(community: community)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task {
                                        await communityContext.switchCommunity(to: community)
                                        dismiss()
                                    }
                                }
                        }
                    }
                    .searchable(text: $searchText, prompt: NSLocalizedString("Search communities", comment: ""))
                }
            }
            .navigationTitle(NSLocalizedString("communities.title", comment: ""))
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

struct CommunityRow: View {
    @EnvironmentObject var communityContext: CommunityContext
    let community: Community

    var isSelected: Bool {
        communityContext.currentCommunityId == community.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // Community banner or placeholder
            Group {
                if let bannerURL = community.bannerURL {
                    KFImage(bannerURL)
                        .placeholder {
                            Color.gray.opacity(0.2)
                        }
                        .fade(duration: 0.2)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Text(community.name.prefix(1).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(community.name)
                    .font(.headline)

                Text("@\(community.slug)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let pendingCount = community.pendingApplicationCount, pendingCount > 0 {
                    Text(String(format: NSLocalizedString("communities.pending", comment: ""), pendingCount))
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

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
    CommunitySwitcher()
        .environmentObject(CommunityContext())
}
