import SwiftUI
import Combine
import Kingfisher

struct AnnouncementsView: View {
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var viewModel = AnnouncementsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.announcements.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                        Button(NSLocalizedString("action.retry", comment: "")) {
                            Task {
                                await viewModel.loadAnnouncements(profileId: profileContext.currentProfileId)
                            }
                        }
                    }
                    .padding()
                } else if viewModel.announcements.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("announcements.empty", comment: ""))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("announcements.empty_description", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.announcements.enumerated()), id: \.element.id) { index, announcement in
                            NavigationLink(destination: AppPostDetailView(postId: announcement.id).environmentObject(profileContext)) {
                                AnnouncementCard(announcement: announcement)
                            }
                            .buttonStyle(PlainButtonStyle())

                            if index < viewModel.announcements.count - 1 {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("announcements.title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.refresh(profileId: profileContext.currentProfileId)
        }
        .task {
            await viewModel.loadAnnouncements(profileId: profileContext.currentProfileId)
        }
    }
}

struct AnnouncementCard: View {
    let announcement: CommunityPost
    @EnvironmentObject var profileContext: ProfileContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink(destination: ProfileDetailView(username: announcement.author.username).environmentObject(profileContext)) {
                    CachedCircularImage(url: announcement.author.avatarURL, size: 40)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        NavigationLink(destination: ProfileDetailView(username: announcement.author.username).environmentObject(profileContext)) {
                            Text(announcement.author.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }

                        Image(systemName: "megaphone.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    Text("@\(announcement.author.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let createdDate = announcement.createdDate {
                    Text(createdDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            TappableMentionText(announcement.content, font: .body)

            if !announcement.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(announcement.images) { image in
                            if let url = image.imageURL {
                                KFImage(url)
                                    .placeholder {
                                        Color.gray.opacity(0.2)
                                    }
                                    .fade(duration: 0.2)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }

            HStack(spacing: 20) {
                Label("\(announcement.replyCount)", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

@MainActor
class AnnouncementsViewModel: ObservableObject {
    @Published var announcements: [CommunityPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadAnnouncements(profileId: String?) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            announcements = try await PostService.shared.getAnnouncements(profileId: profileId)
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load announcements: \(error)")
        }

        isLoading = false
    }

    func refresh(profileId: String?) async {
        errorMessage = nil

        do {
            announcements = try await PostService.shared.getAnnouncements(profileId: profileId)
        } catch is CancellationError {
            // Ignore cancellation errors
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to refresh announcements: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        AnnouncementsView()
            .environmentObject(ProfileContext())
    }
}
