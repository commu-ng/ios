import SwiftUI
import Kingfisher

struct CommunityCardView: View {
    let community: Community
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: {
            if let url = URL(string: community.communityURL) {
                openURL(url)
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Banner image
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
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 120)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }

                // Community info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(community.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        // Role badge
                        Text(community.role.capitalized)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(roleBadgeColor(for: community.role))
                            .cornerRadius(4)
                    }

                    // Hashtags
                    if !community.hashtags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(community.hashtags) { hashtag in
                                    Text("#\(hashtag.tag)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
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
