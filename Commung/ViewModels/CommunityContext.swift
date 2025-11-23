import Foundation
import SwiftUI
import Combine

@MainActor
class CommunityContext: ObservableObject {
    @Published var currentCommunityId: String?
    @Published var currentCommunity: Community?
    @Published var availableCommunities: [Community] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userDefaultsKey = "currentCommunityId"

    init() {
        // Restore last selected community from UserDefaults
        if let savedId = UserDefaults.standard.string(forKey: userDefaultsKey) {
            currentCommunityId = savedId
        }
    }

    func loadCommunities() async {
        isLoading = true
        errorMessage = nil

        do {
            let communities = try await CommunityService.shared.getUserCommunities()
            availableCommunities = communities

            // If we have a saved community ID, find and set it
            if let savedId = currentCommunityId,
               let community = communities.first(where: { $0.id == savedId }) {
                currentCommunity = community
                APIClient.shared.currentCommunity = community
            } else if let firstCommunity = communities.first {
                // Otherwise, select the first community
                await switchCommunity(to: firstCommunity)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load communities: \(error)")
        }

        isLoading = false
    }

    func switchCommunity(to community: Community) async {
        currentCommunityId = community.id
        currentCommunity = community

        // Set community context in API client for mobile origin header
        APIClient.shared.currentCommunity = community

        // Persist selection
        UserDefaults.standard.set(community.id, forKey: userDefaultsKey)

        // Notify that community has changed - ViewModels should reset their state
        NotificationCenter.default.post(name: .communityDidChange, object: community.id)

        print("Switched to community: \(community.name) (ID: \(community.id))")
        print("  Slug: \(community.slug)")
        print("  Custom Domain: \(community.customDomain ?? "none")")
        print("  Domain Verified: \(community.domainVerified ?? "none")")
    }

    func clearCurrentCommunity() {
        currentCommunityId = nil
        currentCommunity = nil
        APIClient.shared.currentCommunity = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    func refreshCurrentCommunity() async {
        await loadCommunities()
    }
}

// Notification name for community changes
extension Notification.Name {
    static let communityDidChange = Notification.Name("communityDidChange")
}
